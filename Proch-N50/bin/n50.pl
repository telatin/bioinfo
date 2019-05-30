#!/usr/bin/env perl
# ABSTRACT: A script to calculate N50 from one or multiple FASTA/FASTQ files.
# PODNAME: n50.pl

use 5.014;
use warnings;
use Pod::Usage;
use Term::ANSIColor  qw(:constants colorvalid colored);
use Getopt::Long;
use File::Basename;
use FindBin qw($Bin);
#~loclib~
use Proch::N50;
use Data::Dumper;
our %program = (
  'NAME'      => 'FASTx N50 CALCULATOR',
  'AUTHOR'    => 'Andrea Telatin',
  'MAIL'      => 'andrea@telatin.com',
  'VERSION'   => '1.5',
);
my $hasJSON = undef;
our $t;

local $Term::ANSIColor::AUTORESET = 1;


my $opt_separator = "\t";
my $opt_format = 'default';
my %formats = (
  'default' => 'Prints only N50 for single file, TSV for multiple files',
  'tsv'     => 'Tab separated output (file, seqs, total size, N50, min, max)',
  'full'    => 'Not implemented',
  'json'    => 'JSON (JavaScript Object Notation) output',
  'short'   => 'Not implemented',
  'csv'     => 'Alias for tsv',
  'custom'  => 'Custom format with --template STRING',
  'screen'  => 'Screen friendly table (requires Text::ASCIITable)',
 );

my ($opt_help,
	$opt_version,
	$opt_debug,
	$opt_color,
	$opt_nonewline,
	$opt_noheader,
	$opt_pretty,
	$opt_basename,
	$opt_template,
  $opt_fullpath,
);
our $tab  = "\t";
our $new  = "\n";
my $result = GetOptions(
    'f|format=s'    => \$opt_format,
    's|separator=s' => \$opt_separator,
    'p|pretty'      => \$opt_pretty,
    'n|nonewline'   => \$opt_nonewline,
    'j|noheader'    => \$opt_noheader,
    'b|basename'    => \$opt_basename,
    'a|abspath'     => \$opt_fullpath,
    't|template=s'  => \$opt_template,
    'c|color'       => \$opt_color,
    'h|help'        => \$opt_help,
    'v|version'     => \$opt_version,
    'd|debug'       => \$opt_debug,
);

pod2usage({-exitval => 0, -verbose => 2}) if $opt_help;
version() if defined $opt_version;

# TODO Added in 1.5. screen friendly format

# Added in v1.5: list accepted output formats programmatically
if ($opt_format eq 'list') {
  say STDERR "AVAILABLE OUTPUT FORMATS:";
  for my $f (sort keys %formats) {
    # Use colors if allowed
    if ($opt_color) {
      print BOLD, $f, "\t";
      # Print in RED unimplemented format
      if ($formats{$f} eq 'Not implemented') {
        say RED $formats{$f}, RESET;
      } else {
        say RESET, $formats{$f};
      }
    } else {
      say "$f\t$formats{$f}";
    }

  }
  exit;
}

our %output_object;

if (defined $opt_format) {
	$opt_format = lc($opt_format);
	if (!$formats{$opt_format}) {
		my @list = sort keys(%formats);

		die " FATAL ERROR:\n Output format not valid (--format '$opt_format').\n Use one of the following: " .
			join(', ',@list) . ".\n";
	}

  # IMPORT JSON ONLY IF NEEDED
  if ($opt_format eq 'json') {

    $hasJSON = eval {
    	require JSON;
    	JSON->import();
     	1;
    };
    die "FATAL ERROR: Please install perl module JSON first [e.g. cpanm JSON]\n" unless ($hasJSON);
  }

  # IMPORT ASCII TABLE ONLY IF NEEDE
  if ($opt_format eq 'screen') {
    my $has_table = eval {
      require Text::ASCIITable;
      Text::ASCIITable->import();
      $t = Text::ASCIITable->new();
      $t->setCols('File','Seqs', 'Total bp','N50', 'min', 'max');
      1;
    };
    if (! $has_table) {
      die "ERROR:\nFormat 'screen' requires Text::ASCIITable installed.\n";
    }
  }

	if ($formats{$opt_format} eq 'Not implemented') {
		print STDERR " WARNING: Format '$opt_format' not implemented yet. Switching to 'tsv'.\n";
		$opt_format = 'tsv';
	}

}
foreach my $file (@ARGV) {
  # Check if file exists / check if '-' supplied read STDIN
	if ( (!-e "$file") and ($file ne '-') ) {
		die " FATAL ERROR:\n File not found ($file).\n";
	} elsif ($file eq '-') {
    # Set file to <STDIN>
		$file = '<STDIN>';
	} else {
    # Open filehandle with $file
		open STDIN, '<', "$file" || die " FATAL ERROR:\n Unable to open file for reading ($file).\n";
	}

  my $JSON = 1 if ($opt_format =~/JSON/ );
  my $FileStats = Proch::N50::getStats($file, $JSON);

  # Validate answer: check {status}==1
  if ( ! $FileStats->{status} )  {
    print STDERR "Error parsing <$file>\n";
    next;
  }
  say Dumper $FileStats if ($opt_debug);
  if (! defined $FileStats->{min}) {
    say Dumper $FileStats;
    say $Proch::N50::VERSION;
    die;
  }
  my $n50 = $FileStats->{N50};
  my $n   = $FileStats->{seqs};
  my $slen= $FileStats->{size};
  my $min = $FileStats->{min};
  my $max = $FileStats->{max};



	say STDERR "[$file]\tTotalSize:$slen;N50:$n50;Sequences:$n" if ($opt_debug);

	$file = basename($file) if ($opt_basename);
  $file = File::Spec->rel2abs($file) if ($opt_fullpath);
	my %metrics = (
		'seqs' => $n,
		'N50'  => $n50,
		'size' => $slen,
    'min'  => $min,
    'max'  => $max,
	);
	$output_object{$file} = \%metrics;
}

my $file_num = scalar keys %output_object;

# Format Output

if (not $opt_format or $opt_format eq 'default') {
  # DEFAULT: format
	if ($file_num == 1) {
    # If only one file is supplied, just return N50 (to allow easy pipeline parsing)
		my @keys = keys %output_object;
		say $output_object{$keys[0]}{'N50'};
	} else {
    # Print table
		foreach my $r (keys %output_object) {
			say $r, $opt_separator ,$output_object{$r}{'N50'};
		}
	}
} elsif ($opt_format eq 'json') {
  # Print JSON object
	my $json = JSON->new->allow_nonref;
	my $pretty_printed = $json->pretty->encode( \%output_object );
	say $pretty_printed;

} elsif ($opt_format eq 'tsv' or $opt_format eq 'csv') {
  # TSV format
	my @fields = ('path', 'seqs', 'size', 'N50', 'min', 'max');
	say '#', join($opt_separator, @fields) if (!defined $opt_noheader);

	foreach my $r (keys %output_object) {
		print $r,$opt_separator;

		for (my $i = 1; $i <= $#fields; $i++) {
			print $output_object{$r}{$fields[$i]} if (defined $output_object{$r}{$fields[$i]});

			if ( ($i == $#fields) and (not $opt_nonewline) ) {
				print "\n";
			} else {
				print $opt_separator;
			}

		}
	}
} elsif ($opt_format eq 'custom') {
  # Format: custom (use tags {new}{tab} {path} ...)
	foreach my $r (keys %output_object) {
		my $output_string = $opt_template;
		$output_string =~s/{new}/$new/g;
		$output_string =~s/{tab}/$tab/g;
		$output_string =~s/{(\w+)}/$output_object{$r}{$1}/g;
		$output_string =~s/{path}/$r/g;
		print $output_string;
	}
} elsif ($opt_format eq 'screen' ) {

  my @fields = ('path', 'seqs', 'size', 'N50', 'min', 'max');
	foreach my $r (keys %output_object) {
		my @array;
    push(@array, $r);
		for (my $i = 1; $i <= $#fields; $i++) {
			push(@array, $output_object{$r}{$fields[$i]}) if (defined $output_object{$r}{$fields[$i]});
		}
    $t->addRow(@array);
	}
  print $t;
}


# Print debug information
sub debug {
	my ($message, $title) = @_;
	$title = 'INFO' unless defined $title;
	$title = uc($title);
	printMessage($message, $title, 'green', 'reset');
	return 1;
}

# Print message with colors unless --nocolor
sub printMessage {
	my ($message, $title, $title_color, $message_color) = @_;
	$title_color   = 'reset' if ((!defined $title_color)  or (!colorvalid($title_color)) or (!$opt_color));
	$message_color = 'reset' if ((!defined $message_color) or (!colorvalid($message_color)) or (!$opt_color));


	say STDERR colored("$title", $title_color), "\t", colored("$message", $message_color);
	return 1;
}

# Calculate N50 from a hash of contig lengths and their counts
sub n50fromHash {
	my ($hash_ref, $total) = @_;
	my $tlen = 0;
	foreach my $s (sort {$a <=> $b} keys %{$hash_ref}) {
		$tlen += $s * ${$hash_ref}{$s};

		# In my original implementation it was >=, here > to comply with 'seqkit'
		return $s if ($tlen > ($total/2));
	}
	return 0;

}

sub version {
	printMessage("$program{NAME}, ver. $program{VERSION}", '', 'reset', 'bold green');
	printMessage(qq(
	$program{AUTHOR}

	Program to calculate N50 from multiple FASTA/FASTQ files.
	Type --help (or -h) to see the full documentation.), '', 'blue', 'green');

	return $program{VERSION};
}

# Heng Li's subroutine (edited)
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

sub swrite {
  die "usage: swrite PICTURE ARGS" unless @_;
  my $format = shift;
  $^A = "";
  formline($format,@_);
  return $^A;
}

__END__

=head1 NAME

B<n50.pl> - A program to calculate N50, min and max length from FASTA/FASTQ files

=head1 AUTHOR

Andrea Telatin <andrea@telatin.com>

=head1 DESCRIPTION

This program parses a list of FASTA/FASTQ files calculating for each one the
number of sequences, the sum of sequences lengths and the N50.
It will print the result in different formats, by default only the N50 is printed
for a single file and all metrics in TSV format for multiple files.

=head1 SYNOPSIS

n50.pl [options] [FILE1 FILE2 FILE3...]

=head1 PARAMETERS

=over 12

=item I<-f, --format>

Output format: default, tsv, json, custom, screen.
See below for format specific switches. Specify "list" to list available formats.

=item I<-s, --separator>

Separator to be used in 'tsv' output. Default: tab.
The 'tsv' format will print a header line, followed by a line for each file
given as input with: file path, as received, total number of sequences,
total size in bp, and finally N50.

=item I<-b, --basename>

Instead of printing the path of each file, will only print
the filename, stripping relative or absolute paths to it.

=item I<-a, --abspath>

Instead of printing the path of each file, as supplied by
the user (can be relative), it will the absolute path.
Will override -b (basename).

=item I<-j, --noheader>

When used with 'tsv' output format, will suppress header
line.

=item I<-n, --nonewline>

If used with 'default' or 'csv' output format, will NOT print the
newline character after the N50. Usually used in bash scripting.

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

=head2 Output formats

=over 4

=item I<tsv> (tab separated values)

  #path    seqs 	size	N50	min	max
  test.fa	  8	 825	189	4	256
  reads.fa	  5	 247	100	6	102
  small_test.fa 	6	130	65	4	65

=item I<screen> (screen friendly)

  .-----------------------------------------------------------.
  | File               | Seqs  | Total bp | N50  | min | max  |
  +--------------------+-------+----------+------+-----+------+
  | test_fasta_grep.fa |     1 |       80 |   80 |  80 |   80 |
  | small_test.fa      |     6 |      130 |   65 |   4 |   65 |
  | rdp_16s_v16.fa     | 13212 | 19098167 | 1467 | 320 | 2210 |
  '--------------------+-------+----------+------+-----+------'

=item I<json> (JSON)


  {
    "small_test.fa" : {
       "max" : "65",
       "N50" : "65",
       "seqs" : 6,
       "size" : 130,
       "min" : "4"
    },
    "rdp_16s_v16.fa" : {
       "seqs" : 13212,
       "N50" : "1467",
       "max" : "2210",
       "min" : "320",
        "size" : 19098167
    }
  }

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
