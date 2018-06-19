#!/usr/bin/env perl

# a program to reduce a featureCounts output to feed edgeR

use v5.14;
use File::Basename;

my $filename = shift(@ARGV);

die " USAGE: $0 featureCounts.txt StringToStrip1 StringToStrip2..\n" unless $filename;
open I, '<', $filename || die " FATAL ERROR:\n Unable to open file <$filename>\n";



# Check header and skip
my $header = <I>;
if ($header =~/featureCounts/) {
	print STDERR "Header:\n$header\n----------------------------------\n";
} else {
	print STDERR " WARNING: This file is not in featureCounts format.\n The output can be unexpected.\n----------------------------------\n";
}

# Get first line, and beautify
my $firstLine = <I>;
chomp($firstLine);
my @fields = split /\t/, $firstLine;
# Remove un-necessary fields (col 2-6)
splice @fields, 1, 5;
# Print gene key (geneId)
our %keys;
print shift(@fields);
foreach my $sample (@fields) {
	$sample = basename($sample);
	for my $pattern (@ARGV) {
		$sample=~s/$pattern//;
	}
	die " ERROR: Duplicate header found $sample" if ($keys{$sample});
	$keys{$sample}++;
	print "\t", $sample;
}
print "\n";


my $c = 0;
while (my $line = <I>) {
	$c++;
	chomp($line);
	my @fields = split /\t/, $line;
	splice @fields, 1, 5;
	print join "\t", @fields;
	print "\n";
}
