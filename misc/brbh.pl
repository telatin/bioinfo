#!/usr/bin/env perl
use 5.012;
use warnings;
use Getopt::Long;

my ($file1, $file2) = @ARGV;

open my $I, '<', $file1 || die " Unable to open file1 <$file1>.\n";
open my $J, '<', $file2 || die " Unable to open file1 <$file2>.\n";

my %file1;
my $file1_lines = 0;
my $file1_hits = 0;
my %file2;
my $file2_lines = 0;
my $file2_hits = 0;
say STDERR "Parsing $file1";
while (my $line = readline($I) ) {
	chomp($line);
	$file1_lines++;
	next if ($line=~/^#/);
	my ($query_id, $subject_id, $identity, $length, $mismatches, $gaps, $query_start, $query_end, $sub_start, $sub_end, $e_value, $bit_score) = split /\t/, $line;
	next if (defined $file1{$query_id});
	$file1_hits++;
	$file1{$query_id}{'s'} = $subject_id;
	$file1{$query_id}{'i'} = $identity;
	$file1{$query_id}{'l'} = $length;
	$file1{$query_id}{'ev'} = $e_value;
	$file1{$query_id}{'bs'} = $bit_score;
}
say STDERR " - $file1_hits/$file1_lines hits";

say STDERR "Parsing $file2";
while (my $line = readline($J) ) {
	chomp($line);
	$file2_lines++;
	next if ($line=~/^#/);
	my ($query_id, $subject_id, $identity, $length, $mismatches, $gaps, $query_start, $query_end, $sub_start, $sub_end, $e_value, $bit_score) = split /\t/, $line;
	next if (defined $file2{$query_id});
	$file2_hits++;
	$file2{$query_id}{'s'} = $subject_id;
	$file2{$query_id}{'i'} = $identity;
	$file2{$query_id}{'l'} = $length;
	$file2{$query_id}{'ev'} = $e_value;
	$file2{$query_id}{'bs'} = $bit_score;
}
say STDERR " - $file2_hits/$file2_lines hits";

my $count_bad_reciprocal = 0;
my $count_ok_reciprocal  = 0;
foreach my $gene1 (sort keys %file1) {
	my $best_hit = $file1{$gene1}{'s'};

	if ($gene1 eq $file2{$best_hit}{'s'}) {
		$count_ok_reciprocal++;
		print "$gene1\t$best_hit\t$file1{$gene1}{i}\t$file1{$gene1}{l}\t$file1{$gene1}{ev}\n";
	} else {
		$count_bad_reciprocal++;
	}
}
say STDERR "$count_ok_reciprocal\tBRBH";
say STDERR "$count_bad_reciprocal\tNot-BRBH";

