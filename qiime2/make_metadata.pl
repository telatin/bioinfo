#!/usr/bin/env perl
# ABSTRACT - A tool to prepare a template metadata file for Qiime2 or Lotus

use 5.012;
use warnings;
use Getopt::Long;
use File::Basename;
use Data::Dumper;
use File::Spec;
use Term::ANSIColor qw(:constants);
use Pod::Usage;
my ($R, $N);          # Color reset / Reset and newline

my (
    $opt_input_directory,
    $opt_single_end,
    $opt_debug,
    $opt_lotus,
    $opt_help,
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
    'h|help'        => \$opt_help,
);
pod2usage({-exitval => 0, -verbose => 2}) if $opt_help;

unless (defined $opt_input_directory) {
    die " FATAL ERROR:\n Please specify input directory (-i DIR, --reads DIR)\n";
}

my @files = glob("$opt_input_directory/*");
my %samples = ();

for my $file (@files) {
    my $base = basename($file);

    if ($base !~/\.(fastq|fq|fna)/i) {
        say STDERR RED " WARNING: ", RESET, "File \"$file\" will be ignored: no FASTQ extension detected.";
        next;
    }
    
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
    say STDERR BLUE 'Sample list:', "\n", Dumper \%samples;
    say RESET '';
}

my $sample_count = 0;
for my $id (sort keys %samples) {
    my $file_tag = '';
    my $abs_file_tag = '';
    $sample_count++;
    if ($opt_single_end) {
        die " FATAL ERROR:\n ID <$id> was used for more than one file\n" if ($samples{$id}{'files'} != 1);
        $abs_file_tag = $samples{$id}{'R1'};
        $file_tag     = basename($samples{$id}{'R1'});
    } else {
        die " FATAL ERROR:\n ID <$id> was used for more than two files\n" if ($samples{$id}{'files'} != 2);
        $file_tag = basename($samples{$id}{'R1'}) . ',' . basename($file_tag = $samples{$id}{'R2'});
        $abs_file_tag     = $samples{$id}{'R1'} . ',' . $file_tag = $samples{$id}{'R2'};
    }
    if ($opt_lotus) {
        $mapping_file .= "$id\t$file_tag\t$abs_file_tag\n";
    } else {
        $mapping_file .= "$id\tNNNNNNNN\tTreatment\n";
    }
    
}

if ($sample_count) {
    print $mapping_file;
} else {
    print RED "ERROR", RESET, "\n No samples found in <$opt_input_directory>.\n";
}

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
    return "#SampleID\tfastqFile\tfastqFilePath\n";
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

 
=head2 NAME
 
B<make_metadata.pl> - a script to draft a metadata table for Qiime 2 or Lotus.

The program will ensure that the proper number of files (1 or 2) is found for
each sample, and that the sample ID (initial part of the filename) does not 
contain unsupported chars.
 
=head2 AUTHOR
 
Andrea Telatin <andrea.telatin@quadram.ac.uk>
 
=head2 SYNOPSIS
 
make_metadata.pl [options] -i INPUT_DIR 
 
=head2 PARAMETERS
 
=over 4

=item B<-i>, B<--reads> DIR

Path to the directory containing the FASTQ files

=item B<-s>, B<--single-end>

Input directory contains unpaired files (default is Paired-End mode)

=item B<-l>, B<--lotus>

Print metadata in LOTUS format (default: Qiime2)

=item B<-1>, B<--for-tag> STRING

Tag to detect that a file is forward (default: _R1)


=item B<-2>, B<--rev-tag> STRING

Tag to detect that a file is forward (default: _R2)

=item B<-d>, B<--delim> STRING

The sample ID is the filename up to the delimiter (default: _)


=back
 
=head2 BUGS
 
Please report them to <andrea@telatin.com>
 
=head2 COPYRIGHT
 
Copyright (C) 2013-2020 Andrea Telatin 
 
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
 
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
 
You should have received a copy of the GNU General Public License
along with this program.  If not, see L<http://www.gnu.org/licenses/>.
 
=cut



