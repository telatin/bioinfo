#!/usr/bin/env perl

use v5.12;
my $matrix = shift @ARGV;

open I, '<', $matrix || die "Unable to read input file $matrix.\n";

our $count_lines = 0;

my %total = ();
my %colsum = ();
my %cols  = ();
my @header;

while (my $line = <I>) {
    chomp($line);
    if ($line =~/^#/) {
      @header = split /\t/, $line;
      next;
    }

    my ($key, @values) = split /\t/, $line;


    my $sum = 0;
    my $cols = 0;
    for my $i (@values) {
      $cols++;
      $sum += $i;
      $colsum{$cols} += $i;
    }

    $total{$key} = $sum;
    $cols{$key}  = $cols;

}

print STDERR "
Lines:\t$count_lines
";
say STDERR "COLUMNS SUMS";
foreach my $key (sort keys %cols)
say STDERR "TOP KEYS:";
my $c = 0;
foreach my $key (sort {$total{$a} <=> $total{$b} } keys %total) {
  $c++;
  say STDERR "$c\t$key\t$total{$key}";
  last if ( $c >  10 );
}


say STDERR "LAST KEYS:";
my $c = 0;
foreach my $key (sort {$total{$b} <=> $total{$a} } keys %total) {
  $c++;
  say STDERR "$c\t$key\t$total{$key}";
  last if ( $c >  10 );
}
