#!/usr/bin/env perl -w

use v5.14;
use Getopt::Long;
 
my ($opt_in);
my $opt_min = 0;
my $opt_max = 2_000_000_000;
my $opt_minlen = 0;
my $opt_maxcov = 100;
my $opt_help;

my $opt = GetOptions(
	'i=s'      => \$opt_in,
	'min=i'    => \$opt_min,
	'max=i'    => \$opt_max,
	'len=i'    => \$opt_minlen,
	'h|help'   => \$opt_help,
);

if ($opt_help) {

print STDERR "
 --------------------------------------------------------------------
 SAMTOOLS DEPTH TO BED [Andrea Telatin, 2015]
 ---------------------------------------------------------------------
 A program that convert the output of \"samtools depth\" into a BED
 track

 Example usage:
 samtools depth -a {BAMFILE} | $0 -min {COV} -max {COV} -len {MINSPAN}

 or:
 $0 -min {COV} -max {COV} -len {MINSPAN} -i INPUTFILE
";
exit;	
} elsif ($opt_min == 0 and $opt_max == 2_000_000_000) {
	print "  [Reading from STDIN. Type Ctrl+C to exit. Launch with -h for help]\r";
}
my $prev_chr;
my $prev_pos;

if (defined $opt_in) {
	open STDIN, '<', "$opt_in" || die " FATAL ERROR\n Unable to open <$opt_in>.\n";
} 

#FN692037        13953   13954   ?       0       +       13953   13954   0,128,128

my $end;
my $start;
my @cov = ();

while (my $line = <STDIN> ) {
	chomp($line);
	my ($chromosome_name, $position, $coverage) = split /\t/, $line;

	die "$chromosome_name, $position, $coverage" unless (defined $coverage); 

	if (defined $prev_chr and $chromosome_name ne $prev_chr) {

		if (defined $start) {
			my $avg = avg(@cov);
			my $color = col($avg);
			print "$prev_chr\t$start\t$prev_pos\tAVG=$avg\t0\t+\t$start\t$prev_pos\t$color\n"
				 if ($prev_pos - $start > $opt_minlen);
		}

	}


	if ($coverage >= $opt_min and $coverage < $opt_max) {
		

		if ( ! defined $start ) {
			$start = $position - 1;
			push(@cov, $coverage);
		}

	} else {

		if ( defined $start ) {
			my $avg = avg(@cov);
			my $color = col($avg);
			print "$prev_chr\t$start\t$prev_pos\tAVG=$avg\t0\t+\t$start\t$prev_pos\t$color\n"
				 if ($prev_pos - $start > $opt_minlen);
		}
		$start = undef;
		$end   = undef;

	}

	$prev_chr = $chromosome_name;
	$prev_pos = $position;



}

if (defined $start) {
			my $avg = avg(@cov);
			my $color = col($avg);
			print "$prev_chr\t$start\t$prev_pos\tAVG=$avg\t0\t+\t$start\t$prev_pos\t$color\n"
				 if ($prev_pos - $start > $opt_minlen);
}

sub avg {
	my $sum = 0;
	my $tot = 0;

	foreach my $n (@_) {
		$tot++;
		$sum+=$n;
	}

	if ($tot) {
		return sprintf("%.4f", $sum/$tot);
	}
}

sub col {
	my $num = shift @_;
	my $col = int( $num/$opt_maxcov * 128 );
	return "$col,$col,$col";
}
