#!/usr/bin/perl

use v5.14;

use Getopt::Long;

my $opt_fasta; 
my $opt_help;
my $opt = GetOptions(
	'i=s' => \$opt_fasta,
	'h|help' => \$opt_help
);
if ($opt_help or !$opt_fasta) {
	say STDERR " fastaToGenomeFile.pl";
	say STDERR " -------------------------------------------------------------";
	say STDERR " A script to produce a bedtools genome file (name TAB length)";
	say STDERR " Parameters: -i INPUTFILE.fasta";
	exit 1 if (!defined $opt_fasta);
}
open my $fh, '<', $opt_fasta || die " Unable to read FASTA file: \"$opt_fasta\".\n";
 
my @aux = undef;
my ($n, $slen, $qlen) = (0, 0, 0);
while (my ($name, $seq) = readfq(\$fh, \@aux)) {
	my $len = length($seq);
	say "$name\t$len";
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
    my $name = /^.(\S+)/? $1 : '';
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
