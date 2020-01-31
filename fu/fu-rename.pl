#!/usr/bin/env perl

use 5.012;
use warnings;
use Getopt::Long;
use FindBin qw($RealBin);
if (-d "$RealBin/lib/FASTX/Reader.pm") {
	use lib "$RealBin/lib";
}
use FASTX::Reader;
use File::Basename;
use Data::Dumper;
my $BASENAME = basename($0);
my $warnings = 0;
my ($opt_verbose, $opt_debug);
my $opt_separator   = ".";
my $opt_prefix      = "{b}";
my $opt_reset       = 0;
my $opt_fasta;
my $opt_nocomm;

my $_opt          = GetOptions(
	'p|prefix=s'    => \$opt_prefix,
	'r|reset'       => \$opt_reset,
	's|separator=s' => \$opt_separator,
	'f|fasta'       => \$opt_fasta,
	'v|verbose'     => \$opt_verbose,
	'd|debug'		=> \$opt_debug,
);

my $total_seqs = 0;
for my $file (@ARGV) {
	my $seq_filename = $file;

	my $seqs = 0;
	vprint(" - Processing \"$file\"");
	if ($file eq '-') {
		$seq_filename = '{{STDIN}}';
		$file = 'stream'
	}
	my $reader = FASTX::Reader->new({ filename => "$seq_filename"});

	# Prepare {b} or {B}
	my $basename = basename($file);
	$basename =~s/\.\w+\.?g?z?$// if ($opt_prefix =~/{b}/);
	
	while (my $seq = $reader->getRead() ) {
		$seqs++;
		$total_seqs++;

		# Prepare prefix
		my $seqname = $opt_prefix;
		$seqname =~s/\{[bB]\}/$basename/;
		
		if (index($seqname, $opt_separator) != -1) {
			$warnings++;
			say " [WARNING] The prefix <$seqname> contains the separator <$opt_separator>!";
		}

		$seqname .= $opt_separator;

		# Counter
		if ($opt_reset) {
			$seqname .= $seqs;
		} else {
			$seqname .= $total_seqs;
		}

		my $comments = '';
		$comments .= " ".$seq->{comment} if (defined $seq->{comment} and not $opt_nocomm);
		if ($seq->{qual} and not $opt_fasta) {
			

			say '@', $seqname, $comments, "\n", $seq->{seq}, "\n+\n", $seq->{qual};
		} else {
			say '>', $seqname, $comments, "\n", $seq->{seq};
		}

	}
}

say STDERR "$warnings warnings emitted";


sub usage {
	say STDERR<<END;

	Usage:
	$BASENAME [options] InputFile.fa [...]

	-p, --prefix STRING
		New sequence name (accept placehodlers),
		default is "{b}"

	-s, --separator STRING
		Separator between prefix and sequence
		number

	-r, --reset
		Reset counter at each file

	example:
	$BASENAME -p '{b}' test.fa test2.fa > renamed.fa

	Placeholders:
	{b} = File basename without extensions
	{B} = File basename with extension
END
	exit 0;
}

sub vprint {
	say $_[0] if ($opt_verbose or $opt_debug) ;
}

sub dprint {
	say "#$_[0]" if ($opt_debug);
}