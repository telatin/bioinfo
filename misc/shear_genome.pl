#!/usr/bin/perl

use v5.12;
use Getopt::Long;

our $format      = 'fastq';
our $read_length = 100;
our $step        = 10;
print STDERR<<END;
    -----------------------------------------
        Shear Fasta File
    -----------------------------------------
        -i     Input genome (Fasta)
        -o     Output basename
        -s     Step in bp (default: $step)
        -l     Read length (default: $read_length)
    -----------------------------------------
END
my ($opt_help, $opt_version, $opt_input, $opt_genome, $opt_out);

my $result = GetOptions(
    'i|input=s' => \$opt_genome,
    'o|output=s'=> \$opt_out,
    'f|format=s'=> \$format,
    'l|length=i'=> \$read_length,
    's|step=i'  => \$step,
    'version'   => \$opt_version,
    'help'      => \$opt_help
);
$format = lc($format);
if ($format ne 'fasta' and $format ne 'fastq') {
    die " Please, specify format either 'fasta' or 'fastq'.\n";
}

die " FATAL ERROR\n Missing parameters.\n" if (!$opt_genome and !$opt_out);

open my $fh, '<', "$opt_genome" || die " FATAL ERROR\n Unable to open input file: <$opt_genome>.\n";
open my $out, '>', "$opt_out.$format" || die " FATAL ERROR\n Unable to write to <$opt_out.$format>\n";
my @aux = undef;
my ($n, $slen, $qlen) = (0, 0, 0);
while (my ($ref_name, $seq) = readfq(\$fh, \@aux)) {
    ++$n;
    my $ref_length = length($seq);
    my $read_number = 0;

    for (my $pos = 0; $pos <= ($ref_length - $read_length); $pos += $step) {
        $read_number++;
        my $read = substr($seq, $pos, $read_length);
        my $qual = 'I' x $read_length;
        my $name = $ref_name.'_'.$pos. " #$read_number";
        if ($format eq 'fastq') {
            say {$out} qq(\@$name\n$read\n+\n$qual);
        } else {
            say {$out} qq(>$name\n$read);
        }
    }
    say STDERR "$ref_name ($ref_length bp, $read_number reads printed)";
}

 
 
sub readfq {
    my ($fh, $aux) = @_;
    @$aux = [undef, 0] if (!(@$aux));
    return if ($aux->[1]);
    if (!defined($aux->[0])) {
        while (readline(${$fh})) {
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
    while (readline(${$fh})) {
        chomp;
        $c = substr($_, 0, 1);
        last if ($c eq '>' || $c eq '@' || $c eq '+');
        $seq .= $_;
    }
    $aux->[0] = $_;
    $aux->[1] = 1 if (!defined($aux->[0]));
    return ($name, $seq) if ($c ne '+');
    my $qual = '';
    while (readline(${$fh})) {
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
