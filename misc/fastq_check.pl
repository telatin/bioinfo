#!/usr/bin/env perl
#!/usr/bin/env perl

use v5.14;
use Getopt::Long;

our @errors;
our ($filename_R1, $filename_R2, $output_basename);
my $GetOptions = GetOptions(
    '1|first-pair=s'  => \$filename_R1,
    '2|second-pair=s' => \$filename_R2,
    'o|output-basename=s' => \$output_basename,
);


# Check parameters
if (! $output_basename) {
    push(@errors, "Missing required parameter: -o, --output-basename OUTPUTBASENAME");
}
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

print STDERR " READING FROM:
 - $filename_R1
 - $filename_R2

 WRITING TO:
 - ${output_basename}_R1.fastq
 - ${output_basename}_R2.fastq

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

my $output_error_R1 = "FATAL ERROR:\n * Unable to write output R1 ",${output_basename}.'_R1.fastq', "\n";
my $output_error_R2 = "FATAL ERROR:\n * Unable to write output R2 ",${output_basename}.'_R2.fastq', "\n";

open my $O1, '>', ${output_basename}.'_R1.fastq' || die $output_error_R1;
open my $O2, '>', ${output_basename}.'_R2.fastq' || die $output_error_R2;


our %reads;
our $counter_R1 = 0;
our $counter_R2 = 0;
our $common = 0;

# -----------------------------------------------------------------------
my @aux = undef;

while (my ($name, $seq, $qual) = readfq(\*R1, \@aux)) {
    next if (
                ( length($seq) != length($qual) )
            or
                !length($seq)
    );

    $reads{$name} = 1;
    $counter_R1++;
}
print STDERR " File R1 passed: $counter_R1 reads\n";

# -----------------------------------------------------------------------

my @aux = undef;
while (my ($name, $seq, $qual) = readfq(\*R2, \@aux)) {
    next if (
                ( length($seq) != length($qual) )
            or
                !length($seq)
    );

    $counter_R2++;

    if ($reads{$name}) {
        print {$O2} '@', $name, "\n", $seq, "\n+\n", $qual, "\n";
        $reads{$name} = 2;
        $common++;
    }
}
print STDERR " File R2 ($filename_R2) printed: $counter_R2 total\n";


close R1;
open  R1, $readmode1, $filename_R1 || die $error_R1;
my @aux = undef;
while (my ($name, $seq, $qual) = readfq(\*R1, \@aux)) {
    print {$O1} '@', $name, "\n", $seq, "\n+\n", $qual, "\n"
        if ($reads{$name} == 2);
}

print STDERR " File R1 ($filename_R1) printed\n";

print STDERR " Common sequences: $common\n";

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


 sub head_hash {
    my $r = $_[0];
    my $c = 0;

    foreach my $key (sort { ${$r}{$a} <=> ${$r}{$b} } keys %{$r}) {
        $c++;
        print STDERR " # $key\t${$r}{$key}\n";
        last if ($c > $_[1]);
    }
 }
