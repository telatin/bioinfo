#!/usr/bin/env perl
# ABSTRACT - A tool to prepare a template metadata file for Qiime2 or Lotus

use 5.012;
use warnings;
use Getopt::Long;
use File::Basename;
use Data::Dumper;
use File::Spec;
use Term::ANSIColor qw(:constants);

my ($R, $N);          # Color reset / Reset and newline

my (
    $opt_input_directory,
    $opt_single_end,
    $opt_debug,
    $opt_lotus,
);
my $opt_for_tag = '_R1\W';
my $opt_rev_tag = '_R2\W';
my $opt_sample_id_delimiter = '_';
sub validate_id($);

my $_opt = GetOptions(
    'i|reads=s'     => \$opt_input_directory,
    '1|for-tag=s'   => \$opt_for_tag,
    '2|rev-tag=s'   => \$opt_rev_tag,
    's|single-end'  => \$opt_single_end,
    'd|id-delim=s'  => \$opt_sample_id_delimiter,
    'l|lotus'       => \$opt_lotus,
    'debug'         => \$opt_debug,
);

unless (defined $opt_input_directory) {
    die " FATAL ERROR:\n Please specify input directory (-i DIR, --reads DIR)\n";
}

my @files = glob("$opt_input_directory/*");
my %samples = ();

for my $file (@files) {
    my $base = basename($file);
    my $abs = File::Spec->rel2abs( $file );
    my ($id) = split /$opt_sample_id_delimiter/, $base;
    die " FATAL ERROR:\n Autoinferred ID <$id> is not valid (file: $file)\n" unless (validate_id($id));
    $samples{$id}{'files'}++;
    if ($opt_single_end) {
        $samples{$id}{'R1'} = $abs;
    } else {
        if ($base =~/$opt_for_tag/) {
            $samples{$id}{'R1'} = $abs;
        } elsif ($base =~/$opt_rev_tag/) {
            $samples{$id}{'R2'} = $abs;
        } else {
            die " TAG DETECTION ERROR:\n File <$file> is not labeled <$opt_for_tag> or <$opt_rev_tag>: is it R1 or R2?\n Specify tags with -1/-2 or switch to --single-end\n";
        }
    }
}

my $mapping_file = '';

if ($opt_lotus) {
    $mapping_file .= lotus_header();
} else {
    $mapping_file .= qiime2_header();
}

if ($opt_debug) {
    say STDERR Dumper \%samples;
}

for my $id (sort keys %samples) {
    my $file_tag = '';
    if ($opt_single_end) {
        die " FATAL ERROR:\n ID <$id> was used for more than one file\n" if ($samples{$id}{'files'} != 1);
        $file_tag = $samples{$id}{'R1'};
    } else {
        die " FATAL ERROR:\n ID <$id> was used for more than two files\n" if ($samples{$id}{'files'} != 2);
        $file_tag = $samples{$id}{'R1'} . ',' . $file_tag = $samples{$id}{'R2'};
    }
    if ($opt_lotus) {
        $mapping_file .= "$id\t$file_tag\n";
    } else {
        $mapping_file .= "$id\tNNNNNNNN\tTreatment\n";
    }
    
}

print $mapping_file;
sub validate_id($) {
    my %reserved = (
    'id' => 1,
    'sampleid' => 1,
    'sample id' => 1,
    'sample-id' => 1,
    'featureid' => 1,
    'feature-id' => 1,
    'OTU' => 1,
    'OTUID' => 1,
    'OTU ID' => 1,
    'sample_name' => 1,
);
    my $id = shift @_;
    if ($id eq '' or $id =~/^#/ or $reserved{$id}) {
        return 0;
    }
    if (length($id) > 36) {
        say STDERR " WARNING: It's recommended to use IDs < 36 chars ($id)";
    }
    if ($id=~/[^A-Za-z0-9_\-.]/) {
        say STDERR " WARNING: It's recommended to use only alphanumeric chars, plus '-', '_' and '.' ($id)";
    }
    return 1;
}

sub qiime2_header {
    return "sample-id\tbarcode-sequence\ttreatment
#q2:types\tcategorical\tcategorical\n";
}

sub lotus_header {
    return "#SampleID\tfastqFile\n";
}
BEGIN { 
    $R = Term::ANSIColor::color('reset');
    $N = "$R\n";
    # Support no-color.org 
    if (defined $ENV{'NO_COLOR'}) {
        $ENV{ANSI_COLORS_DISABLED} = 1;
    }
}

__END__

