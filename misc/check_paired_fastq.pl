#!/usr/bin/env perl

use v5.14;
use Getopt::Long;

our @errors;
our ($filename_R1, $filename_R2);
my $GetOptions = GetOptions(
    '1|first-pair=s'  => \$filename_R1,
    '2|second-pair=s' => \$filename_R2,

);


if (! $filename_R1) {
    push(@errors, "Missing required parameter: -1, --first-pair FILENAME_R1.FASTQ");
} else {
    if (! -e "$filename_R1") {
        push(@errors, "Unable to find first pair file: <$filename_R1>.");
    }

    if (! $filename_R2) {
        $filename_R2 = $filename_R1;
        $filename_R2 =~s/_R1/_R2/;
        if ($filename_R1 eq $filename_R2) {
            push(@errors, "Missing required parameter -2 (--second-pair), and _R1 not found in $filename_R1");
        } else {
            if (! -e "$filename_R2") {
                push(@errors, "Missing required parameter -2 (--second-pair) and inferred name <$filename_R2> not found.");
            }
        }
    }
}

if ($errors[0]) {
    die "FATAL ERRORS:\n * ", join("\n * ", @errors);
}

print STDERR "R1: $filename_R1
R2: $filename_R2
";

my $error_R1 = "FATAL ERROR:\n * Unable to read file R1 <$filename_R1>\n";
my $error_R2 = "FATAL ERROR:\n * Unable to read file R2 <$filename_R2>\n";
my $readmode1 = '<';
my $readmode2 = '<';

if ($filename_R1=~/gz$/) {
    $readmode1 = '-|';
    $filename_R1 = qq(gzip -dc "$filename_R1");
}

if ($filename_R2=~/gz$/) {
    $readmode2 = '-|';
    $filename_R2 = qq(gzip -dc "$filename_R2");
}

open R1, $readmode1, $filename_R1 || die $error_R1;
open R2, $readmode2, $filename_R2 || die $error_R2;

my $c = 0;
while (my $n1 = <R1> ) {
  $c++;
  my $n2 = <R2>;

  <R1>;
  <R1>;
  <R1>;

  <R2>;
  <R2>;
  <R2>;

  chomp($n1);
  chomp($n2);
  ($n1) = split /\s+/, $n1;
  ($n2) = split /\s+/, $n2;
  die "Mismatching names in sequence $c:
$n1 != $n2\n" if ($n1 ne $n2);
}
print "OK\n";
