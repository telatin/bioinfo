#!/usr/bin/env perl

# A script to perform basic abundance statistics on
# multiple files produced by
# samtools view FILE.bam | cut -f 3 | sort | uniq -c 
use v5.12;
use Getopt::Long;
use Carp qw(confess cluck);
use File::Basename;
use Data::Dumper;
my $opt_help;
my $opt_nobasename;
my $opt_nostripchars;
my $opt_verbose;

my $GetOptions = GetOptions(
	'no-strip-chars' => \$opt_nostripchars,
	'no-basename'    => \$opt_nobasename,
	'v|verbose'      => \$opt_verbose,
   	'help'           => \$opt_help,
);


our %ref_counts;

our %sample_total;
our %gene_total;
our @sample_names;
foreach my $file_name (@ARGV) {
	my $basename = get_file_basename($file_name);
	push(@sample_names, $basename);
	if ( ! -e "$file_name" ) {
		Warn("Skipping '$file_name': not found");
	}

	open my $fh, '<', "$file_name" || Die("Unable to reads '$file_name'");
	my $c = 0;
	my $sum = 0;
	print STDERR "Parsing $basename\n";
	while (my $line = readline($fh) ) {
		$c++;
		chomp($line);
		if ($line=~/^\s*(\d+)\s+(\S+)$/) {
			$ref_counts{$2}{$basename} = $1;
			$gene_total{$2} += $1;
			$sum+=$1;
		} else {
			Warn("$file_name:$c\tBad format expecting NUMBER  CHR_NAME, found:\n$line");
		}
	}

	$sample_total{$basename} = $sum;

	Die("Sample '$basename' has zero sum counts") unless $sum;
}

my $g = 0;

say "#\t", join("\t", @sample_names);
foreach my $chr_name (sort {$gene_total{$b} <=> $gene_total{$a} } keys %ref_counts) {
	$g++;
	print  "$chr_name";
	foreach my $file ( @sample_names ) {
	
		my $value = $ref_counts{$chr_name}{$file} ? $ref_counts{$chr_name}{$file} : 0;
		$value = sprintf("%.5f", 100*$value/$sample_total{$file});
		print "\t", $value;
	}
	say;
	last if ($g > 20);
}

sub get_file_basename {
	my $file_name = shift @_;
	my $file_name = basename($file_name) unless ($opt_nobasename);
	my @fragments = split /\./, $file_name;
	pop(@fragments);
	my $file_name = join('', @fragments);
	$file_name =~s/[^A-Za-z0-9_\-]//g unless ($opt_nostripchars);

	return $file_name;
}


sub Warn {
	my ($message) = @_;
	if ($opt_verbose) {
		cluck "WARNING:\n$message\n";
	} else {
		print STDERR "WARNING:\n$message\n";
	}
}

sub Die {
	my ($message) = @_;
	if ($opt_verbose) {
		confess "FATAL ERROR:\n$message.\n";
	} else {
		die  "FATAL ERROR:\n$message.\n";
	}
}
__END__
carp: not fatal, no backtrace
cluck: not fatal, with backtrace
croak: fatal, no backtrace
confess: fatal, with backtrace

