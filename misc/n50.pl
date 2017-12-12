#!/usr/bin/env perl
# A script to calculate N50 from one or multiple FASTA/FASTQ files, 
# or from STDIN.

use v5.12;
use Pod::Usage;
use Term::ANSIColor  qw(:constants colorvalid colored);
use Getopt::Long;
use JSON;

local $Term::ANSIColor::AUTORESET = 1;

our %program = (
	'NAME'      => 'FASTx N50 CALCULATOR',
	'AUTHOR' 	=> 'Andrea Telatin',
	'MAIL'      => 'andrea.telatin@quadram.ac.uk',
	'VERSION'   => '1.1',
);
my $opt_separator = "\t";
my $opt_format = 'default';
my %formats = (
	'default' => 'Prints only N50 for single file, TSV for multiple files',
	'tsv'     => 'Tab separated output (file, seqs, total size, N50)',
	'full'    => 'Not implemented',
    'json'    => 'JSON (JavaScript Object Notation) output',
    'short'   => 'Not Implemented'
 );

my ($opt_help, $opt_version, $opt_input, $opt_verbose, $opt_debug, $opt_nocolor, $opt_nonewline, $opt_pretty);
my $result = GetOptions(
    'f|format=s'    => \$opt_format,
    's|separator=s' => \$opt_separator,
    'p|pretty'      => \$opt_pretty,
    'n|nonewline'   => \$opt_nonewline,
    'h|help'        => \$opt_help,
    'v|version'     => \$opt_version,
    'd|debug'       => \$opt_debug,
);

pod2usage({-exitval => 0, -verbose => 2}) if $opt_help;
version() if defined $opt_version;

our %output_object;

if (defined $opt_format) {
	$opt_format = lc($opt_format);
	if (!$formats{$opt_format}) {
		my @list = sort keys(%formats);

		die " FATAL ERROR:\n Output format not valid (--format '$opt_format').\n Use one of the following: " .
			join(', ',@list) . ".\n";
	}

}
foreach my $file (@ARGV) {
	
	if (!-e "$file" and $file ne '-') {
		die " FATAL ERROR:\n File not found ($file).\n";	
	} elsif ($file eq '-') {
		$file = '<STDIN>';
	} else {
		open STDIN, '<', "$file" || die " FATAL ERROR:\n Unable to open file for reading ($file).\n";
	}



	my @aux;
	my %sizes;
	my ($n, $slen) = (0, 0);

	while (my ($name, $seq) = readfq(\*STDIN, \@aux)) {
	    ++$n;

	    my $size = length($seq);
	    $slen += $size;
	    $sizes{$size}++;
	}
	my $n50 = n50fromHash(\%sizes, $slen);

	say STDERR "[$file]\tTotalSize:$slen;N50:$n50;Sequences:$n" if ($opt_debug);
	
	my %metrics = (
		'seqs' => $n,
		'N50'  => $n50,
		'size' => $slen,
	);
	$output_object{$file} = \%metrics;
}

my $file_num = scalar keys %output_object;

if (!$opt_format) {
# DEFAULT
	if ($file_num == 1) {
		my @keys = keys %output_object;
		say $output_object{$keys[0]}{'N50'};
	} else {
		foreach my $r (keys %output_object) {
			say $output_object{$r}{'path'}, $opt_separator ,$output_object{$r}{'N50'};
		}		
	}
} elsif ($opt_format eq 'json') {
	#my $json = encode_json \@file_stats;
	my $json = JSON->new->allow_nonref;
	my $pretty_printed = $json->pretty->encode( \%output_object );
	say $pretty_printed;
} elsif ($opt_format eq 'tsv') {
	my @fields = ('path', 'seqs', 'size', 'N50');
	say '#', join($opt_separator, @fields);

	foreach my $r (keys %output_object) {
		for (my $i = 0; $i <= $#fields; $i++) {
			print $output_object{$r}{$fields[$i]};
			if ($i == $#fields) {
				print "\n";
			} else {
				print $opt_separator;
			}

		}
	}
}


sub debug {
	my ($message, $title) = @_;
	$title = 'INFO' unless defined $title;
	$title = uc($title);
	printMessage($message, $title, 'green', 'reset');
}
sub printMessage {
	my ($message, $title, $title_color, $message_color) = @_;
	$title_color   = 'reset' if (!defined $title_color or !colorvalid($title_color) or $opt_nocolor);
	$message_color = 'reset' if (!defined $message_color or !colorvalid($message_color) or $opt_nocolor);

	
	say STDERR colored("$title", $title_color), "\t", colored("$message", $message_color);
}
sub n50fromHash {
	my ($hash_ref, $total) = @_;
	my $tlen = 0;
	foreach my $s (sort {$a <=> $b} keys %{$hash_ref}) {
		$tlen += $s * ${$hash_ref}{$s};
		return $s if ($tlen >= ($total/2));
	}

}

sub version {
	say STDERR<<END;
	$program{NAME}, ver. $program{VERSION}
	$program{AUTHOR}

	Program to calculate N50 from multiple FASTA/FASTQ files.
	Type --help (or -h) to see the full documentation.
END
exit 0;
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

__END__

=head1 NAME
 
B<n50.pl> - A program to calculate N50 from FASTA/FASTQ files
 
=head1 AUTHOR
 
Andrea Telatin <andrea.telatin@quadram.ac.uk>
 
=head1 SYNOPSIS
 
n50.pl [options] [FILE1 FILE2 FILE3...]

=head1 PARAMETERS

=over 12

=item U<-f, --format>

Output format: default, tsv, json. See below for details

=item U<-s, --separator>

Separator to be used in 'tsv' output. Default: tab.

=item U<-n, --nonewline>

If used with 'default' output format, will NOT print the
newline character after the N50. Usually used in bash scripting.

=item U<-p, --pretty>

If used with 'json' output format, will format the JSON
in pretty print mode.

=back

=head1 DESCRIPTION
 
This program parses a list of FASTA/FASTQ files calculating for each one
the number of sequences, the sum of sequences lengths and the N50.
It will print the result in different formats, by default only the N50 is
printed for a single file and all metrics in TSV format for multiple files.
 
=head1 OPTIONS

=head1 COPYRIGHT
 
Copyright (C) 2013 Andrea Telatin 
 
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
