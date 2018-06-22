#!/usr/bin/env perl

# Subselect matrix according to metadata


use v5.16; 

use warnings;
use Getopt::Long;
use File::Basename;
use Term::ANSIColor  qw(:constants);
use Data::Dumper;
use Cwd 'abs_path';
local $Term::ANSIColor::AUTORESET = 1;

my ($opt_table_file, $opt_metadata_file, $opt_output, $opt_debug, $opt_debug_sub, $opt_condition, $opt_);
my $opt = GetOptions(
	't|table-file=s'	=> \$opt_table_file,
	'm|metadata-file=s' => \$opt_metadata_file,
	'o|output=s'        => \$opt_output,
	'c|condition=s'     => \$opt_condition,
	'',

	'v|verbose'         => \$opt_debug,
	'd|debug'           => \$opt_debug_sub,
);

our $usage = '
   -t, --table-file         Matrix table
   -m, --metadata           Metadata file (SampleID SampleName Condition1 Condition2..)
   -c, --condition          Condition name to keep and its value (eg: Time=T0))
';


die " FATAL ERROR:\n Missing metadata TSV file (-m, --metadata-files)\n" unless (defined $opt_metadata_file);
die " FATAL ERROR:\n Missing table of counts, matrix (-t, --table-files)\n" unless (defined $opt_table_file);

my ($opt_condition_name, $opt_condition_value) = split /=/, $opt_condition;
die " FATAL ERROR:\n condition format is COND_NAME=COND_VALUE ($opt_condition)\n" unless ($opt_condition_value);


my ($metadata_ref, $header_ref ) = parse_metadata($opt_metadata_file);

open my $fh, '<', "$opt_table_file" || die " FATAL ERROR:\n Unable to read matrix file $opt_table_file\n";

my $c = 0;
my %print_col = ();
my @headers_print;

my $outputName = "$opt_table_file.$opt_condition";
$outputName =~s/=/-/g;
$outputName =~s/\.(txt|tsv|csv)//g;
open my $output, '>', "$outputName.tsv" || die "FATAL ERROR:\nUnable to write to output file\n";

while (my $line = readline($fh) ) {
	chomp($line);
	$c++;

	if ( $c == 1  ) {
		my ($key, @samples) = split /\t/, $line;
		my $col = 0;
		foreach my $sample (@samples) {
			my $keep = 0;
			 
			 if ($metadata_ref->{$sample}->{$opt_condition_name} eq  $opt_condition_value) {
			 	$keep = 1;
			 	@print_col{$col} = 1;
			 	push (@headers_print, $sample);
			 }
			print STDERR  "$col\t$keep\t$sample\t";
			if (defined $metadata_ref->{$sample}->{$opt_condition_name}) {
				print STDERR $metadata_ref->{$sample}->{$opt_condition_name},"\n";
			} else {
				die " Unknown condition \"$opt_condition_name\" for sample $sample: check metadata\n";
			}
			#say  BOLD $col, "\t",$sample, RESET, "\t", Dumper $metadata_ref->{$sample};
			$col++;
		}
		say  STDERR "\nColumns to keep: ", join(",", keys %print_col);
		print {$output} $key, "\t";
		print {$output} join("\t", @headers_print),"\n";
		die "FATAL ERROR: Nothing to do: no conditions satisfied.\n" if ($#headers_print < 1);


	} else {
		my ($key, @samples) = split /\t/, $line;
		print {$output} $key, "\t";
		my @columns;
		for my $i (0..$#samples) {
			push @columns, $samples[$i] if $print_col{$i};
		}
		print {$output} join("\t", @columns), "\n";
	}
}

sub parse_metadata {

	my ($file) = @_;

	print STDERR CYAN "\tparse_metadata($file) at line " , __LINE__ ,"\n" if ($opt_debug_sub);
	if (! -e "$file") {
		die " FATAL ERROR:\n Unable to find metadata file <$file>\n";
	}
	my $fh;
	if  (! open $fh, '<', "$file" ) {
		 die " FATAL ERROR:\n Unable to read metadata: <$file>\n";
	}

	#	SampleID	SampleName	Genotype	Time
	#	LIB21427	Time0_WT1	WildType	T0
	#	LIB21428	Time0_WT2	WildType	T0
	#	LIB21429	Time0_WT3	WildType	T0

	my @header = ();
	my %metadata = ();
	my %categories = ();
	my @counted_fields = ();
	my $line_counter = 0;
	while (my $line = readline($fh) ) {
		$line_counter++;
		chomp($line);
		my @fields = split /\t/, $line;
		next if ($line=~/^#/);
		next if ($line=~/^\s*$/);

		# Check header
		if ($fields[0] eq 'SampleID') {

			@header = @fields;
			#print  "Metadata_Header: ",GREEN, join(", ",@header), RESET "\n" if ($opt_debug);
			shift @header;

		} else {

			die " FATAL ERROR: Data found at line $line_counter before header!\n$line\n" unless ( $header[0] );

			my $key = shift @fields;
			my %hash = ();
			@hash{@header} = @fields;
 			
			$metadata{"$key"} = \%hash;




			#print Dumper \%hash;
			#print RED "\n", $metadata{$key}->{Time},"\n";
		}
		die " FATAL ERROR:\n Expecting at least 3 fields: SampleID SampleName Condition1\n",
			"Got (line $line_counter):\n[$line]\n" if ($#fields < 2);

		push(@counted_fields, $#fields);

	}
	my $k = scalar keys %metadata;
	
	print STDERR "Metadata file parsed: ", GREEN, "$k samples\n", RESET, "Labels: ", GREEN join(", ",@header), "\n" if ($opt_debug);

	return (\%metadata, \@header);

}


