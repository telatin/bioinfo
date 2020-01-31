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
my ($opt_verbose, $opt_debug, $opt_fasta);
my $opt_search_in_name;
my $opt_search_in_comm;
my $opt_stranded;
my $opt_annotate;

my $_opt          = GetOptions(
	'a|annotate'    => \$opt_annotate,
	's|stranded'    => \$opt_stranded,
	'n|name'        => \$opt_search_in_name,
	'c|comment'     => \$opt_search_in_comm, 
	'f|fasta'       => \$opt_fasta,
	'v|verbose'     => \$opt_verbose,
	'd|debug'		=> \$opt_debug,
);

usage() unless (defined $ARGV[1]);

my $pattern = shift @ARGV;

check_pattern($pattern) if (not $opt_search_in_name and not $opt_search_in_comm);
my $regex = "($pattern)";
my $rc    = rc($pattern);
$regex = rc_pattern($pattern) if (not defined $opt_stranded);

for my $file (@ARGV) {
	my $seq_filename = $file;


	vprint(" - Processing \"$file\"");
	if ($file eq '-') {
		$seq_filename = '{{STDIN}}';
		$file = 'stream'
	}
	my $reader = FASTX::Reader->new({ filename => "$seq_filename"});

	# Prepare {b} or {B}
	my $basename = basename($file);
	$basename =~s/\.\w+\.?g?z?$//;
	
	my $annotation = '';
	while (my $seq = $reader->getRead() ) {
		my $print = 0;
		my $comments = '';
		$comments .= $seq->{comments} if defined $seq->{comments};

		if ($opt_search_in_comm) {
			next if not defined $seq->{comments};
			$print++ if ($seq->{comments} =~/$regex/i); 

		} elsif ($opt_search_in_name) {
			$print++ if ($seq->{name} =~/$regex/i); 
		} else {
			if ($seq->{seq} =~/$regex/i) {
				$print++;
				if ($opt_annotate) {
					my $matches = 0;
					my $for = 0;
					my $rev = 0;
					while ($seq->{seq} =~/$regex/gi) {
						$matches++;
						if ($1 eq $pattern) {
							$for++;
						} else {
							$rev++
						}
					}

					$annotation = "\t#matches=$matches;";
					$annotation .= "for=$pattern:$for;rev=$rc:$rev" if not defined $opt_stranded;
				} 
			}
		}

		next unless $print;

		if ($seq->{qual} and not $opt_fasta) {
			say '@', $seq->{name}, $comments, "$annotation\n", $seq->{seq}, "\n+\n", $seq->{qual};
		} else {
			say '>', $seq->{name}, $comments, "$annotation\n", $seq->{seq};
		}

	}
}

say STDERR "$warnings warnings emitted";


sub usage {
	say STDERR<<END;

  Usage:
  $BASENAME [options] Pattern InputFile.fa [...]

  -a, --annotate
     Add comments to the sequence when match is found

  -n, --name 
     Search pattern in sequence name (default: sequence)

  -c, --comments
     Search pattern in sequence comments (default: sequence)

  -s, --stranded
     Do not search reverse complemented oligo

  -f, --fasta
     Force output in FASTA format

  example:
  $BASENAME DNASTRING test.fa test2.fa > matched.fa
END
	exit 0;
}

sub check_pattern {
	my $pattern = shift @_;
	if ($pattern !~/^[ACGTNacgtn\.	]+$/) {
		die "ERROR: Pattern should be a DNA string <$pattern>\n";
	}
}
sub rc_pattern {
	my $string = shift @_;
	my $rc = rc($string);
	return '(' . $string .'|'. $rc . ')';
}

sub rc {
	my $string = shift @_;
	$string = reverse $string;
	$string =~tr/ACGTacgt/TGCAtgca/;
	return $string;
}
sub vprint {
	say $_[0] if ($opt_verbose or $opt_debug) ;
}

sub dprint {
	say "#$_[0]" if ($opt_debug);
}