#!/usr/bin/env perl

use v5.12;

use Getopt::Long;
use Carp qw(confess cluck);
use File::Basename;
use Data::Dumper;

my $opt_kmer_size = 45;
my ($opt_file_1, $opt_file_2, $opt_verbose, $opt_help, $opt_debug);

my $GetOptions = GetOptions(
	'1|first=s'       => \$opt_file_1,
	'2|first=s'       => \$opt_file_2,
  'k|kmer-size=i'   => \$opt_kmer_size,
	'v|verbose'       => \$opt_verbose,
  'd|debug'         => \$opt_debug,
 	'help'            => \$opt_help,
);

die " FATAL ERROR: Error in input parameters.\n" if ($GetOptions == 0);

if (! defined $opt_file_1 or ! defined $opt_file_2) {
    die " FATAL ERROR: Missing parameters.\n Both -1 <First.fa> and -2 <Second.fa> are required\n";
}
if ($opt_kmer_size <= 7) {
  $opt_kmer_size = 7;
  cluck "Setting k-mer size to $opt_kmer_size";
}

if ($opt_kmer_size % 2 == 0) {
  $opt_kmer_size--;
  cluck "Setting k-mer size to $opt_kmer_size";
}


open I, '<', "$opt_file_1" || die " Unable to open <$opt_file_1>\n";
open L, '<', "$opt_file_2" || die " Unable to open <$opt_file_2>\n";
print "Hello $opt_file_1\n";

my @aux1 = undef;
while (my ($name, $seq) = readfq(\*I, \@aux1)) {
  print "$name\n";
}
sub readfq {
    my ($fh, $aux) = @_;
    @$aux = [undef, 0] if (!(@$aux));
    return if ($aux->[1]);
    if (!defined($aux->[0])) {
        while (<$fh>) {
            chomp;
            if (substr($_, 0, 1) eq '>' || substr($_, 0, 1) eq '@') {
                $aux->[0] = $_;
                last;
            }
        }
        if (!defined($aux->[0])) {
            $aux->[1] = 1;
            return;
        }
    }

    my $name = '';
    if (defined $_) {
    	$name = /^.(\S+)/? $1 : '';
    }

    my $seq = '';
    my $c;
    $aux->[0] = undef;
    while (<$fh>) {
        chomp;
        $c = substr($_, 0, 1);
        last if ($c eq '>' || $c eq '@' || $c eq '+');
        $seq .= $_;
    }
    $aux->[0] = $_;
    $aux->[1] = 1 if (!defined($aux->[0]));
    return ($name, $seq) if ($c ne '+');
    my $qual = '';
    while (<$fh>) {
        chomp;
        $qual .= $_;
        if (length($qual) >= length($seq)) {
            $aux->[0] = undef;
            return ($name, $seq, $qual);
        }
    }
    $aux->[1] = 1;
    return ($name, $seq);
}
