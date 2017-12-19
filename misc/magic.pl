#!/usr/bin/env perl
# A script to calculate N50 from one or multiple FASTA/FASTQ files, 
# or from STDIN.

use v5.12;
use Pod::Usage;
use Term::ANSIColor  qw(:constants colorvalid colored);
use Getopt::Long;
use File::Basename;
use JSON;

local $Term::ANSIColor::AUTORESET = 1;


my $result = GetOptions(
    's|samcassette=s'    => \$opt_sam_cassette,
    'c|contigs=s'        => \$opt_contigs,
    'r|reference=s'      => \$opt_reference,
);

open my $SAM, '<', "$opt_sam_cassette" || die " ERROR: Unable to read SAM: <$opt_sam_cassette>\n";

my %contig_size = ();
my $count_contigs = 0;
my $count_aln = 0;
while (my $line = readline($SAM)) {
  if ($line=~/^@/) {
    if ($line=~/SN:(\S+)     LN:(\d+)/) {
      $contig_size{$1} = $2;
      $count_contigs++;
    }
  } else {
    $count_aln++;
    my ($read, $flag, $contig, $position, $qual, $cigar) = split /\t/, $line;
    my $tot = cigarSum($cigar);
  }

}
sub cigar_sum {
  my $c = shift @_;
  my $sum;
  while ($c =~/(\d+)(\D)/) {
    $sum += $1;
  }
  return $sum;
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