#!/usr/bin/env perl -w

use v5.14;
my @numbers;

my $steps = 20;
my $c = 0;
my $min;
my $max;
while (my $line=<STDIN>) {
	chomp($line);
	if ($line=~/^([0-9\.]+)/) {
		$c++;
		push(@numbers, $1);
		$min = $1 if (!defined $min or $min > $1);
		$max = $1 if (!defined $max or $max < $1);
	}
}

my ($st, $av) = stdev(@numbers);

say STDERR "Tot\tMin\tMax\tAvg\tStDev";
say        "$c\t$min\t$max\t$av\t$st";


my $step = int($max / $steps);

my $last = 0;
for (my $i = $step; $i <= $max; $i+=$step) {
	my $tot = 0;
	my $rep;
	foreach my $n (sort {$a <=> $b} @numbers) {
		last if ($n >= $i);
		$tot++ if ($n > $last);
		$rep = $n;# if (!defined $rep);
	}
	$last = $i;
	$rep = '' unless ($tot);
	my $line = '=' x int($tot/$c * 50);
	say "$i\t$tot\t$line\t$rep";
	undef $rep;
}
sub stdev {
	my @n = @_;
	my $sum = 0; 
        my $delta = 0; my $count = 0; 
        my $mean = 0; my $stddev = 0;
 
	foreach my $number (@n) {
		$count++;
		$delta = $number - $mean;
		$mean = $mean + ($delta / $count);
		$sum = $sum + $delta*($number - $mean);
	}
	return (0,0) if ($count == 1);
	$stddev = sqrt($sum/($count - 1));
 
 
	return(sprintf("%.6f", $stddev), sprintf("%.6f",$mean));
 
 
}
