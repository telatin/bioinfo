#!/usr/bin/env perl
# ABSTRACT: A script to calculate N50 from one or multiple FASTA/FASTQ files.
# PODNAME: n50.pl

use 5.014;
use warnings;
use Pod::Usage;
use Term::ANSIColor qw(:constants colorvalid colored);
use Getopt::Long;
use File::Basename;
use FindBin qw($Bin);
# The following placeholder is to be programmatically replaced with 'use lib "$Bin/../lib"' if needed
#~loclib~
use Proch::N50;
use Data::Dumper;
our %program = (
    'NAME'    => 'SEQUENCE N50',
    'AUTHOR'  => 'Andrea Telatin',
    'MAIL'    => 'andrea@telatin.com',
    'VERSION' => '2.0',
);
my $hasJSON = undef;
our $t;

local $Term::ANSIColor::AUTORESET = 1;

my $opt_separator = "\t";
my $opt_format    = 'default';
my %formats       = (
    'default' => 'Prints only N50 for single file, TSV for multiple files',
    'tsv'     => 'Tab separated output (file, seqs, total size, N50, min, max)',
    'json'    => 'JSON (JavaScript Object Notation) output',
    'csv'     => 'Alias for tsv and --separator ","',
    'custom'  => 'Custom format with --template STRING',
    'screen'  => 'Screen friendly table (requires Text::ASCIITable)',

    'short' => 'Not implemented',
    'full'  => 'Not implemented',
);

my (
    $opt_help,
    $opt_version,
    $opt_debug,
    $opt_color,
    $opt_nonewline,
    $opt_noheader,
    $opt_pretty,
    $opt_basename,
    $opt_template,
    $opt_fullpath,
    $opt_format_screen,    # x: same as -f screen
    $opt_format_json,      # j: same as -f json
    $opt_sort_by,          # o
    $opt_reverse_sort,     # r
);

$opt_sort_by      = 'N50';
$opt_reverse_sort = undef;
my %valid_sort_keys = (
    'N50'  => 1,
    'min'  => 1,
    'max'  => 1,
    'seqs' => 1,
    'size' => 1,
    'path' => 1,
);
my $tab    = "\t";
my $new    = "\n";
my $result = GetOptions(
    'a|abspath'     => \$opt_fullpath,
    'b|basename'    => \$opt_basename,
    'c|color'       => \$opt_color,
    'd|debug'       => \$opt_debug,
    'f|format=s'    => \$opt_format,
    'h|help'        => \$opt_help,
    'j|json'        => \$opt_format_json,
    'n|nonewline'   => \$opt_nonewline,
    'o|sortby=s'    => \$opt_sort_by,
    'p|pretty'      => \$opt_pretty,
    'r|reverse'     => \$opt_reverse_sort,
    's|separator=s' => \$opt_separator,
    't|template=s'  => \$opt_template,
    'u|noheader'    => \$opt_noheader,
    'v|version'     => \$opt_version,
    'x|screen'      => \$opt_format_screen,
);

$opt_sort_by = 'N50' if ( $opt_sort_by eq 'n50' );
pod2usage( { -exitval => 0, -verbose => 2 } ) if $opt_help;
version() if defined $opt_version;

our %output_object;

# Added in v1.5: list accepted output formats programmatically
# [-f list] or [--format list] will print a list of accepted formats

if ( $opt_format eq 'list' ) {
    say STDERR "AVAILABLE OUTPUT FORMATS:";
    for my $f ( sort keys %formats ) {

        # Use colors if allowed
        if ($opt_color) {
            print BOLD, $f, "\t";

            # Print in RED unimplemented format
            if ( $formats{$f} eq 'Not implemented' ) {
                say RED $formats{$f}, RESET;
            }
            else {
                say RESET, $formats{$f};
            }
        }
        else {
            say "$f\t$formats{$f}";
        }

    }
    exit;
}

# Shot output formats
die "Error: Please specify either -x (--screen) or -j (--json)\n"
  if ( $opt_format_screen and $opt_format_json );
die "Error: -x (--screen) or -j (--json) are incompatible with -f (--format)\n"
  if ( $opt_format ne 'default'
    and ( $opt_format_screen or $opt_format_json ) );
$opt_format = 'screen' if ($opt_format_screen);
$opt_format = 'json'   if ($opt_format_json);

# Sorting by / reverse

unless ( defined $valid_sort_keys{$opt_sort_by} ) {
    say STDERR " FATAL ERROR: Invalid sort key for -o ($opt_sort_by)";
    say STDERR " Valid sort keys are: ", join( ', ', keys %valid_sort_keys );
    die;
}

my %sorters = (
    asc => sub {
        $output_object{$b}{$opt_sort_by} <=> $output_object{$a}{$opt_sort_by};
    },
    desc => sub {
        $output_object{$a}{$opt_sort_by} <=> $output_object{$b}{$opt_sort_by};
    },
    string_asc  => sub { $a cmp $b },
    string_desc => sub { $b cmp $a },
);

my $sorting_order;
if ( $opt_sort_by eq 'path' ) {
    $sorting_order = 'string_asc';
    $sorting_order = 'string_desc' if ($opt_reverse_sort);
}
else {
    $sorting_order = 'asc';
    $sorting_order = 'desc' if ($opt_reverse_sort);
}
debug("Sorting by <$opt_sort_by>: order=$sorting_order");

die("Unexpected fatal error:\nInvalid sort function \"$sorting_order\".\n")
  if ( not defined $sorters{$sorting_order} );
my $sort_function = $sorters{$sorting_order};

if ( defined $opt_format ) {
    $opt_format = lc($opt_format);
    if ( !$formats{$opt_format} ) {
        my @list = sort keys(%formats);

        die
" FATAL ERROR:\n Output format not valid (--format '$opt_format').\n Use one of the following: "
          . join( ', ', @list ) . ".\n";
    }

    # IMPORT JSON ONLY IF NEEDED
    if ( $opt_format eq 'json' ) {

        $hasJSON = eval {
            require JSON;
            JSON->import();
            1;
        };
        die
"FATAL ERROR: Please install perl module JSON first [e.g. cpanm JSON]\n"
          unless ($hasJSON);
    }

    # IMPORT ASCII TABLE ONLY IF NEEDE
    if ( $opt_format eq 'screen' ) {
        my $has_table = eval {
            require Text::ASCIITable;
            Text::ASCIITable->import();
            $t = Text::ASCIITable->new();
            $t->setCols( 'File', 'Seqs', 'Total bp', 'N50', 'min', 'max' );
            1;
        };
        if ( !$has_table ) {
            die
              "ERROR:\nFormat 'screen' requires Text::ASCIITable installed.\n";
        }
    }

    if ( $formats{$opt_format} eq 'Not implemented' ) {
        print STDERR
" WARNING: Format '$opt_format' not implemented yet. Switching to 'tsv'.\n";
        $opt_format = 'tsv';
    }

}
foreach my $file (@ARGV) {

    # Check if file exists / check if '-' supplied read STDIN
    if ( ( !-e "$file" ) and ( $file ne '-' ) ) {
        die " FATAL ERROR:\n File not found ($file).\n";
    }
    elsif ( $file eq '-' ) {

        # Set file to <STDIN>
        $file = '<STDIN>';
    }
    else {
        # Open filehandle with $file
        open STDIN, '<', "$file"
          || die " FATAL ERROR:\n Unable to open file for reading ($file).\n";
    }

    my $JSON      = 1 if ( $opt_format =~ /JSON/ );
    my $FileStats = Proch::N50::getStats( $file, $JSON );

    # Validate answer: check {status}==1
    if ( !$FileStats->{status} ) {
        print STDERR "[WARNING]\tError parsing \"$file\". Skipped.\n";
        next;
    }

    say Dumper $FileStats if ($opt_debug);
    if ( !defined $FileStats->{min} ) {
        say STDERR
          "Fatal error: statistics not calculated parsing \"$file\". Aborting.";
        say STDERR Dumper $FileStats;
        say STDERR $Proch::N50::VERSION;
        die;
    }

    my $n50  = $FileStats->{N50} + 0;
    my $n    = $FileStats->{seqs} + 0;
    my $slen = $FileStats->{size} + 0;
    my $min  = $FileStats->{min} + 0;
    my $max  = $FileStats->{max} + 0;

    say STDERR "[$file]\tTotalSize:$slen;N50:$n50;Sequences:$n" if ($opt_debug);

    $file = basename($file)            if ($opt_basename);
    $file = File::Spec->rel2abs($file) if ($opt_fullpath);

    my %metrics = (
        'seqs' => $n,
        'N50'  => $n50,
        'size' => $slen,
        'min'  => $min,
        'max'  => $max,
    );
    if (defined $output_object{$file}) {
       print STDERR " WARNING: Overwriting '$file': multiple items with the same filename. Try not using -b/--basename.\n";
    }
    $output_object{$file} = \%metrics;

}

my $file_num = scalar keys %output_object;

# Format Output

if ( not $opt_format or $opt_format eq 'default' ) {
    debug("Activating format <default>");

    # DEFAULT: format
    if ( $file_num == 1 ) {

# If only one file is supplied, just return N50 (to allow easy pipeline parsing)
        my @keys = keys %output_object;
        if ($opt_nonewline) {
            print $output_object{ $keys[0] }{'N50'};
        }
        else {
            say $output_object{ $keys[0] }{'N50'};
        }

    }
    else {
        # Print table
        foreach my $r ( keys %output_object ) {
            say $r, $opt_separator, $output_object{$r}{'N50'};
        }
    }
}
elsif ( $opt_format eq 'json' ) {

    # Print JSON object
    my $json           = JSON->new->allow_nonref;
    my $pretty_printed = $json->pretty->encode( \%output_object );
    say $pretty_printed;

}
elsif ( $opt_format eq 'tsv' or $opt_format eq 'csv' ) {

    $opt_separator = ',' if ( $opt_format eq 'csv' );

    # TSV format
    my @fields = ( 'path', 'seqs', 'size', 'N50', 'min', 'max' );
    say '#', join( $opt_separator, @fields ) if ( !defined $opt_noheader );

    foreach my $r ( sort $sort_function keys %output_object ) {
        print $r, $opt_separator;

        for ( my $i = 1 ; $i <= $#fields ; $i++ ) {
            print $output_object{$r}{ $fields[$i] }
              if ( defined $output_object{$r}{ $fields[$i] } );

            if ( ( $i == $#fields ) and ( not $opt_nonewline ) ) {
                print "\n";
            }
            else {
                print $opt_separator;
            }

        }
    }
}
elsif ( $opt_format eq 'custom' ) {
    my @fields = ( 'seqs', 'size', 'N50', 'min', 'max' );

    # Format: custom (use tags {new}{tab} {path} ...)
    foreach my $r ( sort $sort_function keys %output_object ) {
        my $output_string = '';
        $output_string .= $opt_template if ( defined $opt_template );

        $output_string =~ s/{new}/$new/g if ( $output_string =~ /{new}/ );
        $output_string =~ s/{tab}/$tab/g if ( $output_string =~ /{tab}/ );
        $output_string =~ s/{path}/$r/g  if ( $output_string =~ /{path}/ );
        foreach my $f (@fields) {
            $output_string =~ s/{$f}/$output_object{$r}{$f}/g;
        }
        print $output_string;
    }
}
elsif ( $opt_format eq 'screen' ) {

    my @fields = ( 'path', 'seqs', 'size', 'N50', 'min', 'max' );

    #my $field = 'N50';

    foreach my $r ( sort $sort_function keys %output_object ) {
        my @array;
        push( @array, $r );
        for ( my $i = 1 ; $i <= $#fields ; $i++ ) {
            push( @array, $output_object{$r}{ $fields[$i] } )
              if ( defined $output_object{$r}{ $fields[$i] } );
        }
        $t->addRow(@array);
    }

    print $t;
}

# Print debug information
sub debug {
    return unless defined $opt_debug;
    my ( $message, $title ) = @_;
    $title = 'INFO' unless defined $title;
    $title = uc($title);
    printMessage( $message, $title, 'green', 'reset' );
    return 1;
}

# Print message with colors unless --nocolor
sub printMessage {
    my ( $message, $title, $title_color, $message_color ) = @_;
    $title_color = 'reset'
      if ( ( !defined $title_color )
        or ( !colorvalid($title_color) )
        or ( !$opt_color ) );
    $message_color = 'reset'
      if ( ( !defined $message_color )
        or ( !colorvalid($message_color) )
        or ( !$opt_color ) );

    say STDERR colored( "$title", $title_color ), "\t",
      colored( "$message", $message_color );
    return 1;
}

sub version {
   print STDERR '-' x 65, "\n";
    printMessage( "$program{NAME}, ver. $program{VERSION}",
        '', 'reset', 'bold green' );

   print STDERR '-' x 65, "\n";

    printMessage(
        qq(
  $program{AUTHOR}

  Program to calculate N50 from multiple FASTA/FASTQ files, 
  based on Proch::N50 $Proch::N50::VERSION
  https://metacpan.org/pod/distribution/Proch-N50/bin/n50.pl

  Type --help (or -h) to see the full documentation.), '', 'blue', 'green'
    );

   print STDERR '-' x 65, "\n";

    return $program{VERSION};
}

# Calculate N50 from a hash of contig lengths and their counts
sub n50fromHash {
    my ( $hash_ref, $total ) = @_;
    my $tlen = 0;
    foreach my $s ( sort { $a <=> $b } keys %{$hash_ref} ) {
        $tlen += $s * ${$hash_ref}{$s};

       # In my original implementation it was >=, here > to comply with 'seqkit'
        return $s if ( $tlen > ( $total / 2 ) );
    }
    return 0;

}

# Heng Li's subroutine (edited)
sub readfq {
    my ( $fh, $aux ) = @_;
    @$aux = [ undef, 0 ] if ( !(@$aux) );
    return if ( $aux->[1] );
    if ( !defined( $aux->[0] ) ) {
        while (<$fh>) {
            chomp;
            if ( substr( $_, 0, 1 ) eq '>' || substr( $_, 0, 1 ) eq '@' ) {
                $aux->[0] = $_;
                last;
            }
        }
        if ( !defined( $aux->[0] ) ) {
            $aux->[1] = 1;
            return;
        }
    }

    my $name = '';
    if ( defined $_ ) {
        $name = /^.(\S+)/ ? $1 : '';
    }

    my $seq = '';
    my $c;
    $aux->[0] = undef;
    while (<$fh>) {
        chomp;
        $c = substr( $_, 0, 1 );
        last if ( $c eq '>' || $c eq '@' || $c eq '+' );
        $seq .= $_;
    }
    $aux->[0] = $_;
    $aux->[1] = 1 if ( !defined( $aux->[0] ) );
    return ( $name, $seq ) if ( $c ne '+' );
    my $qual = '';
    while (<$fh>) {
        chomp;
        $qual .= $_;
        if ( length($qual) >= length($seq) ) {
            $aux->[0] = undef;
            return ( $name, $seq, $qual );
        }
    }
    $aux->[1] = 1;
    return ( $name, $seq );
}

__END__


=head1 DESCRIPTION

This program parses a list of FASTA/FASTQ files calculating for each one the
number of sequences, the sum of sequences lengths and the N50.
It will print the result in different formats, by default only the N50 is printed
for a single file and all metrics in TSV format for multiple files.

=head1 SYNOPSIS

  n50.pl [options] [FILE1 FILE2 FILE3...]

=head1 PARAMETERS

=over 12

=item I<-o, --sortby>

Sort by field: 'N50' (default), 'min', 'max', 'seqs', 'size', 'path'.
By default will be descending for numeric fields, ascending for 'path'.
See C<-r, --reverse>.

=item I<-r, --reverse>

Reverse sort (see: C<-o>);

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
the filename, stripping relative or absolute paths to it. See C<-a>.
Warning: if you are reading multiple files with the same basename, only one will be printed. 
This is the intended behaviour and you will only receive a warning.

=item I<-a, --abspath>

Instead of printing the path of each file, as supplied by
the user (can be relative), it will the absolute path.
Will override -b (basename). See C<-b>.

=item I<-u, --noheader>

When used with 'tsv' output format, will suppress header
line.

=item I<-n, --nonewline>

If used with 'default' (or 'csv' output format), will NOT print the
newline character after the N50 for a single file. Useful in bash scripting:

  n50=$(n50.pl filename);

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
     "N50"  : 290,
     "seqs" : 2
  },
   "file2.fa" : {
     "N50"  : 456,
     "size" : 456,
     "seqs" : 2
  }
 }

=item I<-h, --help>

Will display this full help message and quit, even if other
arguments are supplied.

=back

=head2 Output formats

These are the values for C<--format>.

=over 4

=item I<tsv> (tab separated values)

  #path	seqs 	size	N50	min	max
  test2.fa	8	 825	189	4	256
  reads.fa	5	 247	100	6	102
  small.fa 	6	130	65	4	65

=item I<csv> (comma separated values)

Same as C<--format tsv> and C<--separator ,>:

  #path,seqs,size,N50,min,max
  test.fa,8,825,189,4,256
  reads.fa,5,247,100,6,102
  small_test.fa,6,130,65,4,65

=item I<screen> (screen friendly)

Use C<-x> as shortcut for C<--format screen>.

  .-----------------------------------------------------------.
  | File               | Seqs  | Total bp | N50  | min | max  |
  +--------------------+-------+----------+------+-----+------+
  | test_fasta_grep.fa |     1 |       80 |   80 |  80 |   80 |
  | small_test.fa      |     6 |      130 |   65 |   4 |   65 |
  | rdp_16s_v16.fa     | 13212 | 19098167 | 1467 | 320 | 2210 |
  '--------------------+-------+----------+------+-----+------'

=item I<json> (JSON)

Use C<-j> as shortcut for C<--format json>.

  {
    "small_test.fa" : {
       "max"  : 65,
       "N50"  : 65,
       "seqs" : 6,
       "size" : 130,
       "min"  : 4
    },
    "rdp_16s_v16.fa" : {
       "seqs" : 13212,
       "N50"  : 1467,
       "max"  : 2210,
       "min"  : 320,
       "size" : 19098167
    }
  }

=back

=head1 EXAMPLE USAGES

Screen friendly table (C<-x> is a shortcut for C<--format screen>), sorted by N50 descending (default):

  n50.pl -x files/*.fa

Screen friendly table, sorted by total contig length (C<--sortby max>) ascending (C<--reverse>):

  n50.pl -x -o max -r files/*.fa

Tabular (tsv) output is default:

  n50.pl -o max -r files/*.fa

A custom output format:

  n50.pl data/*.fa -f custom -t '{path}{tab}N50={N50};Sum={size}{new}'

=head1 COPYRIGHT

Copyright (C) 2017-2019 Andrea Telatin

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
