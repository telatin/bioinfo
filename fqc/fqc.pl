#!/usr/bin/perl
use strict;
use warnings;

unless ($ARGV[0]) {
	my $lines = 0;
	my $buffer;
	while (sysread STDIN, $buffer, 65536) {
        $lines += ($buffer =~ tr/\n//);
    }
    
    $lines = int($lines/4);
    print "$lines\n";

} else {
	for my $filename (@ARGV) {
	    my $lines = 0;
	    my $buffer;
	    if ($filename =~/gz$/) {
	    	open(FILE, "gunzip -c \"$filename\" |") or die "ERROR: Cannot open gzipped file $filename: $!\n"; 
	    } else {
	    	open(FILE, $filename) or die "ERROR: Can not open file $filename: $!\n";
	    }

	    while (sysread FILE, $buffer, 65536) {
	        $lines += ($buffer =~ tr/\n//);
	    }
	    close FILE;
	    $lines = int($lines/4);
	    print "$filename,$lines\n";
	}
}
