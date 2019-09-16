#!/usr/bin/env perl
use 5.012;
use warnings;

my ($cluster_file) = @ARGV;

open my $f, '<', "$cluster_file" || die "Fatal error:\nUnable to read input file ($!).\n";

my %clusters;
my %cfreq;
my %nfreq;
while (my $line = readline($f) ) {
	chomp($line);
	my($id, $seq) = split /\t/, $line;
	push( @{ $clusters{$id} }, $seq);
}

my $total_clusters = keys %clusters;
say "$total_clusters clusters found";

foreach my $id (sort keys %clusters) {
	my $t = scalar @{ $clusters{$id} } + 1;
	$cfreq{$t}++;	
	$nfreq{$t} = ${ $clusters{$id} }[0];
	say "$id\t$t";
}

foreach my $size (sort {$a <=> $b} keys %cfreq) {
	say "cluster size: $size\tclusters: $cfreq{$size}\t$nfreq{$size}";
}


