#!/usr/bin/env perl

# A script to psplit a multifasta file in pieces

use v5.12;
use Getopt::Long;
use Carp qw(confess cluck);
use File::Basename;
use Data::Dumper;


my $opt_verbose;
my $opt_input_file;
my $opt_output_file;
my $opt_max_chunk_size = 5000;

my $GetOptions = GetOptions(
    'v|verbose'          => \$opt_verbose,
    'i|input=s'          => \$opt_input_file,
    'o|output=s'         => \$opt_output_file,
    's|size=i'           => \$opt_max_chunk_size,
);

unless (defined $opt_input_file) {
  die " Missing parameters.\n Split FASTA file in chunks.\n Paramers: -i INPUT [-o OUTPUT] [-s SIZE]\n";
}

unless (defined $opt_output_file) {
  $opt_output_file = $opt_input_file.'chunks.fa';
}


open I, '<', "$opt_input_file"   || die "FATAL ERROR: Unable to read input file <$opt_input_file>\n";
open O, '>', "$opt_output_file"  || die "FATAL ERROR: Unable to write to <$opt_output_file> (specify with -o)\n";


my @aux = undef;
my $n = 0;
while (my ($name, $seq) = readfq(\*I, \@aux)) {
    ++$n;
    my $size = length($seq);

    print STDERR ">$name ($size) " if ($opt_verbose);

    my $chunk_num = 0;
    for (my $pos = 0; $pos < $size; $pos += $opt_max_chunk_size) {
      $chunk_num++;
      my $chunk = substr($seq, $pos, $opt_max_chunk_size);
      print O ">${name}_$pos:$opt_max_chunk_size\n$chunk\n";
    }

    print STDERR "\t$chunk_num\n" if ($opt_verbose);
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
