#!/usr/bin/env perl 

use 5.012;
use warnings;
use Getopt::Long;
use FASTX::Reader;
use File::Basename;
use Data::Dumper;

my $BASENAME = basename($0);

my ($opt_list, $opt_pattern, $opt_maxlen, $opt_minlen, $opt_verbose, $opt_debug);
my $opt_separator = "\t";
my $opt_header_char = '#';
my $opt_column    = 1;
my %seq_names     = ();
my $_opt          = GetOptions(
	'l|list=s'      => \$opt_list,
	'p|pattern=s'   => \$opt_pattern,
	'x|maxlen=i'    => \$opt_maxlen,
	'm|minlen=i'    => \$opt_minlen,
	'c|column=i'    => \$opt_column,
	'h|header=s'    => \$opt_header_char,
	'v|verbose'     => \$opt_verbose,
	'd|debug'		=> \$opt_debug,
	's|separator=s' => \$opt_separator,
);

if (defined $opt_list) {
	open(my $I, '<', "$opt_list") || die " FATAL ERROR:\n Unable to read list file <$opt_list>.\n";
	while (my $line = readline($I) ) {
		chomp($line);
		next if ($line =~/^$opt_header_char/);
		my @fields = split /$opt_separator/, $line;
		$seq_names{ $fields[ $opt_column -1 ]} = 1;
	}
	say STDERR Dumper \%seq_names if $opt_debug;
}

usage() unless (defined $ARGV[0]);

for my $file (@ARGV) {
	next unless (-e "$file");
	vprint(" - Processing $file");
	my $Fasta = FASTX::Reader->new( { filename => "$file"});
	my $tot   = 0;
	my $pass  = 0;
	while (my $seq = $Fasta->getRead() ) {
		$tot++;
		my $l = length( $seq->{seq} );
		next if (defined $opt_maxlen and $l > $opt_maxlen);
		next if (defined $opt_minlen and $l < $opt_minlen);
		next if (defined $opt_pattern and $seq->{name} !~/$opt_pattern/);
		next if (defined $opt_list and not $seq_names{ $seq->{name} });
		my $comment = $seq->{comment} ? " $seq->{comment}" : '';

		say '>', $seq->{name}, $comment, "\n", $seq->{seq};
	}
}

sub usage {
	say STDERR<<END;

	Usage:
	$BASENAME [options] InputFile.fa [...]

	-p, --pattern   STRING
	-m, --minlen    INT
	-x, --maxlen    INT
	-l, --list      FILE
	-c, --column    INT (default: 1)
	-s, --separator CHAR (default: "\t")
	-h, --header    CHAR (defatul: "#")

	Note that "-p" and "-l" are exclusive

	example:
	$BASENAME -p 'BamHI' test.fa

	$BASENAME -l list.txt test.fa
END
	exit 0;
}

sub vprint {
	say $_[0] if ($opt_verbose);
}

