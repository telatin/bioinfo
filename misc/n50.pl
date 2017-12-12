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
	'AUTHOR' 	=> 'Andrea Telatin',
	'MAIL'      => 'andrea.telatin@quadram.ac.uk',
	'VERSION'   => '1.1',
);
my $opt_separator = "\t";
my @formats = ('line', 'json', 'full', 'short');
my ($opt_help, $opt_version, $opt_input, $opt_verbose, $opt_debug, $opt_nocolor, $opt_format);
my $result = GetOptions(
    'i|input=s' => \$opt_input,
    'h|help'    => \$opt_help,
    'v|version' => \$opt_version,
    'd|debug'   => \$opt_debug,
    's|separator=s' => \$opt_separator,
    'f|format=s'    => \$opt_format,
    'nocolor'   => \$opt_nocolor,
);

pod2usage({-exitval => 0, -verbose => 2}) if $opt_help;

our @file_stats;

foreach my $file (@ARGV) {
	
	if (!-e "$file") {
		# File not found	
	} else {
		open I, '<', "$file" || die " FATAL ERROR:\n Unable to read file <$file>.\n";
	}
	my @aux;
	my %sizes;
	my ($n, $slen) = (0, 0);
	while (my ($name, $seq) = readfq(\*I, \@aux)) {
	    ++$n;

	    my $size = length($seq);
	    $slen += $size;
	    $sizes{$size}++;
	}
	my $n50 = n50fromHash(\%sizes, $slen);
	say STDERR "[$file]\tTotalSize:$slen;N50:$n50;Sequences:$n" if ($opt_debug);
	
	my %file_object = (
		'path' => $file,
		'seqs' => $n,
		'N50'  => $n50,
		'size' => $slen,
	);
	push(@file_stats, \%file_object);
}

my $file_num = scalar @file_stats;

if (!$opt_format) {
# DEFAULT
	if ($file_num == 1) {
		say ${$file_stats[0]}{'N50'};
	} else {
		foreach my $r (@file_stats) {
			say ${$r}{'path'}, $opt_separator ,${$r}{'N50'};
		}		
	}
} elsif ($opt_format eq 'json') {
	#my $json = encode_json \@file_stats;
	my $json = JSON->new->allow_nonref;
	my $pretty_printed = $json->pretty->encode( \@file_stats );
	say $pretty_printed;
} elsif ($opt_format eq 'csv') {
	my @fields = ('path', 'seqs', 'size', 'N50');
	say join($opt_separator, @fields);
	foreach my $r (@file_stats) {
		for (my $i = 0; $i <= $#fields; $i++) {
			print ${$r}{$fields[$i]};
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


=head1 DESCRIPTION
 
After running jellyfish with a particular KMERLEN and one or more FASTQ files,
determine the PEAK using jellyplot.pl and find_valleys.pl. Next, use this
PEAK as well as the KMERLEN and the FASTQ files used in the jellyfish run
as input. The script will determine the coverage and genome size.
 
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
