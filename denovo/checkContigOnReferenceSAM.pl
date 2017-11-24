#!/usr/bin/env perl

use v5.14;

use File::Basename;
use Getopt::Long;
 
# User supplied parameters
my ($opt_sam);
my $got_options = GetOptions(
	's|sam-file=s'     => \$opt_sam,
	'c|contigs-file=s' => \$opt_contigs,
);

open my $samFH, '<', "$opt_sam" || crash(qq(Unable to open SAM file: "$opt_sam"));


sub crash {
	my ($message, $title) = @_;
	$title = 'FATAL ERROR' unless $title;

	say STDERR " $title"
	die " $message\n";
}