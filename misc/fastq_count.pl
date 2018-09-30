#!/usr/bin/env perl
# A script to calculate N50 from one or multiple FASTA/FASTQ files, 
# or from STDIN.

use v5.12;
use Pod::Usage;
use Term::ANSIColor  qw(:constants colorvalid colored);
use Getopt::Long;
use File::Basename;

local $Term::ANSIColor::AUTORESET = 1;

our %program = (
  'NAME'      => 'FASTQ COUNTER',
  'AUTHOR'    => 'Andrea Telatin',
  'MAIL'      => 'andrea.telatin@quadram.ac.uk',
  'VERSION'   => '1.1',
);


my ($opt_help, 
	$opt_version, 
	$opt_debug, 
	$opt_color, 
 	$opt_basename,
);
our $tab  = "\t";
our $new  = "\n";
my $result = GetOptions(
    'c|color'       => \$opt_color,
    'h|help'        => \$opt_help,
    'v|version'     => \$opt_version,
    'd|debug'       => \$opt_debug,
    'b|basename'    => \$opt_basename,
    's|separator=s' => \$tab,
);

pod2usage({-exitval => 0, -verbose => 2}) if $opt_help;
version() if defined $opt_version;



foreach my $file (@ARGV) {
	
	if (!-e "$file" and $file ne '-') {
		die " FATAL ERROR:\n File not found ($file).\n";	
	} elsif ($file eq '-') {
		$file = '<STDIN>';
	} else {
		open STDIN, '<', "$file" || die " FATAL ERROR:\n Unable to open file for reading ($file).\n";
	}
	my $counter = 0;
	my $print_name = $file;
	$print_name = basename($file) if ($opt_basename);
	while (<STDIN>) {
		$counter++;
	}
	if ($counter % 4) {
		print STDERR "# Warning $file has $counter, not multiple of 4\n";
	}
	my $read_counter = $counter / 4;
	print $print_name, $tab, $read_counter, $new;
}


sub debug {
	my ($message, $title) = @_;
	$title = 'INFO' unless defined $title;
	$title = uc($title);
	printMessage($message, $title, 'green', 'reset');
}
sub printMessage {
	my ($message, $title, $title_color, $message_color) = @_;
	$title_color   = 'reset' if (!defined $title_color or !colorvalid($title_color) or !$opt_color);
	$message_color = 'reset' if (!defined $message_color or !colorvalid($message_color) or !$opt_color);

	
	say STDERR colored("$title", $title_color), "\t", colored("$message", $message_color);
}



sub version {
	printMessage("$program{NAME}, ver. $program{VERSION}", '', 'reset', 'bold green');
	printMessage(qq(
	$program{AUTHOR}

	Program to count reads in FASTQ files.
	Type --help (or -h) to see the full documentation.), '', 'blue', 'green');
END

}

__END__

=head1 NAME
 
B<fastq_count.pl> - A program to count reads in FASTQ files
 
=head1 AUTHOR
 
Andrea Telatin <andrea.telatin@quadram.ac.uk>

=head1 DESCRIPTION
 
This program parses a list of FASTA/FASTQ files calculating for each one
the number of sequences, the sum of sequences lengths and the N50.
It will print the result in different formats, by default only the N50 is
printed for a single file and all metrics in TSV format for multiple files.
 
=head1 SYNOPSIS
 
n50.pl [options] [FILE1 FILE2 FILE3...]

=head1 PARAMETERS

=over 12

=item I<-f, --format>

Output format: default, tsv, json, custom. 
See below for format specific switches.

=item I<-s, --separator>

Separator to be used in 'tsv' output. Default: tab.
The 'tsv' format will print a header line, followed
by a line for each file given as input with: file path,
as received, total number of sequences, total size in bp,
and finally N50.

=item I<-b, --basename>

Instead of printing the path of each file, will only print
the filename, stripping relative or absolute paths to it.

=item I<-j, --noheader>

When used with 'tsv' output format, will suppress header
line.

=item I<-n, --nonewline>

If used with 'default' or 'csv' output format, will NOT print the
newline character after the N50. Usually used in bash scripting.ù

=item I<-t, --template>

String to be used with 'custom' format. Will be used as template
string for each sample, replacing {new} with newlines, {tab} with
tab and {N50}, {seqs}, {size}, {path} with sample's N50, number of sequences,
total size in bp and file path respectively (the latter will
respect --basename if used).

=item I<-p, --pretty>

If used with 'json' output format, will format the JSON
in pretty print mode. Example:

 
 {
   "file1.fa" : {
     "size" : 290,
     "N50" : "290",
     "seqs" : 2
  },
   "file2.fa" : {
     "N50" : "456",
     "size" : 456,
     "seqs" : 2
  }
 }
 
=item I<-h, --help>

Will display this full help message and quit, even if other
arguments are supplied.

=back

=head1 COPYRIGHT
 
Copyright (C) 2017 Andrea Telatin 
 
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
 
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
 
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
=cut
