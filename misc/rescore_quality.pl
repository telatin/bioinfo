#!/usr/bin/env perl
#ABSTRACT - A program to restore R1 quality values in merged R1-R2 reads

use 5.012;
use warnings;
use Getopt::Long;
check_dep();
use FASTX::Reader;
 

my $usage = '
  Rescore Quality of Merged Pairs (REQUAMP)
  ------------------------------------------------------------------------------
  Usage:
  rescore_quality.pl -1 Forward.fq MergedFastq.pl > RescoredMerged.fq

';

my $opt_r1;

my $_opts = GetOptions(
  '1|first=s'      => \$opt_r1,
);

my $input_file = shift @ARGV;

if (not defined $input_file or not defined $opt_r1) {
	say $usage;
	exit;
}

my $R1;
my $READS;

# Instantiate FASTQ readers
$R1 = FASTX::Reader->new({ filename => "$opt_r1" });
$READS = FASTX::Reader->new({ filename => "$input_file" });

my $r1_read = $R1->getFastqRead();

our %counter;
while (my $m_read = $READS->getFastqRead() ) {
	$counter{'total_merged'}++;

	my $new_qual = $m_read->{qual};

	# Retrieve original R1 sequence and quality from unmerged R1 file
	while ($r1_read->{name} ne $m_read->{name}) {
		$r1_read = $R1->getFastqRead();
	}

	# Check that sequences are very similar?
	my $merge_start;
	my $r1_start;
 

	if ( length($m_read->{seq}) >= length($r1_read->{seq}) ) {
		$counter{'merged_longer'}++;
		$merge_start = substr($m_read->{seq}, 0, length($r1_read->{seq}));
		$r1_start    = $r1_read->{seq};

	} else {
		# Maybe discard these?
		$counter{'merged_shorter'}++;
		$merge_start = $m_read->{seq};
		$r1_start    = substr($r1_read->{seq}, 0, length($merge_start));

	}
	my $match_ratio = strings_similarity($r1_start, $merge_start);

	if ($match_ratio <= 0) {
		say STDERR " WARNING (", $match_ratio, "): Unable to rescore ", $m_read->{name}, " as its start differs from R1\n>",length( $r1_read->{seq}),":", $r1_read->{seq}, ">\n<",  
			length($merge_start),':', length($m_read->{seq}),'>', $merge_start ;
	} else {
	  $new_qual = '';
	  for (my $pos = 0; $pos < length($r1_start) ; $pos++) {
	  	my $merged_qual_char = substr($m_read->{qual}, $pos, 1);
	  	my $original_qual    = substr($r1_read->{qual},$pos, 1);
		if (ord($merged_qual_char) > ord($original_qual) ) {
			$new_qual .= $merged_qual_char;
		} else {
			$new_qual .= $original_qual;
		}
	  }
	  $new_qual .= substr($m_read->{qual}, length($new_qual));
	}

	# Print FASTQ sequence with new quality	

	 
	print '@', $r1_read->{name}, "\n",
		$m_read->{seq}, "\n+\n",
		$new_qual, "\n";
		
}


foreach my $s (sort keys %counter) {
	say STDERR $s, "\t", $counter{$s};
}
sub strings_similarity {
	my ($s1, $s2) = @_;

	# Return 0 if different lengths: this compares only matching sequences (no indels, no overhangs)
	return -1 if (length($s1) != length($s2) or length($s1) == 0 );

	my $matches = 0;
	for (my $pos = 0; $pos < length($s1); $pos++) {
		$matches++ if (substr($s1, $pos, 1) eq substr($s2, $pos, 1) );
	}
	 
	return $matches/length($s1);
}

sub check_dep {
	# Check FASTX::Reader is installed, suggests CPANminus
	my $got_mod = eval {require FASTX::Reader; 1;};
	if (! $got_mod) {
		die " This scripts requires 'FASTX::Reader'. You can install it with CPANminus:\ncpanm FASTX::Reader\n\n(If you don't have cpanm - shame - you can 'cpan FASTX::Reader')perl ";
	}

}
