#!/usr/bin/env perl -w

# Experimental Perl wrapper to query the bigsi.io service

#curl "http://api.bigsi.io/search?seq=ATTGCCGAATGGCGTGGTGATGACGTCATACTGCTTCACCACGTTGGCGATGCTCTCGTCATCCAGTCTATACTTCTTTGCCGCATCGGCATCGATGTAGTCATCAATGACTTCACCGAA&threshold=1&score=0"
#      http://api.bigsi.io/search?seq=ATTGCCGAATGGCGTGGTGATGACGTCATACTGCTTCACCACGTTGGCGATGCTCTCGTCATCCAGTCTATACTTCTTTGCCGCATCGGCATCGATGTAGTCATCAATGACTTCACCGAA&threshold=1&score=0
use v5.14;
use Getopt::Long;
use JSON::Parse 'parse_json';
use LWP::Simple;
use Pod::Usage;
use Term::ANSIColor;
use Data::Dumper;
local $Term::ANSIColor::AUTORESET = 1;
my $base_url = 'http://api.bigsi.io/search?seq=';

my $min_stretch  = 31;
my $min_res_frac = 0.75;
my $opt_ths = 1;
my $opt_score = 0;
my $opt_verbose;
my $opt_json;
my $opt_column = 30;
my $opt_minid = 90;
my $opt_interactive;
my $opt_color;
my $opt_debug;
my $opt_help;

my $opt = GetOptions(
	'k|threshold=i'     => \$opt_ths,
	's|score=i'         => \$opt_score,
	'v|verbose'         => \$opt_verbose,
	'j|json'            => \$opt_json,
	'm|minabundance=f'   => \$opt_minid,
	'i|interactive'     => \$opt_interactive,
	'r|result-ths=f'    => \$min_res_frac,
	'color'             => \$opt_color,
	'debug'             => \$opt_debug,
	'h|help'            => \$opt_help,
);
pod2usage({-exitval => 0, -verbose => 2}) if $opt_help;

$opt_ths = 1 if ($opt_ths > 1);
my $parameters = "&threshold=" . $opt_ths . "&score=" . $opt_score;

our $seqnum = 0;
if ($opt_interactive) {
	print STDERR color('blue') if ($opt_color);
	say STDERR "Type sequence: ";
	my $seq = <STDIN>;
	chomp($seq);
	push(@ARGV, $seq);
	print STDERR color('reset');
} elsif (! $ARGV[0]) {
	die " Type a sequence to pseudoalign, or use -i for interactive prompt.\n";
}

my %GENUS = ();
my %SPEC = ();
my $res_count = 0;
foreach my $sequence (@ARGV) {
	$sequence = extractSeq($sequence);
	$seqnum++;
	my $size = length($sequence);
	my $tag  = $sequence;
	if ($size > $min_stretch) {
		$tag = substr($sequence, 0, $min_stretch/2).'...';
	}
	message("#Scanning $seqnum sequence ($size bp)");
	$sequence = uc($sequence);
	if ($sequence =~/^[ACGTN]+$/ ) {
		my $request_url = $base_url . $sequence . $parameters;
		message("#curl \"$request_url\"");
		my $content = get($request_url);
		my $b = length($content);
		if ($b) {
			message("#OK, received $b chars") if ($opt_verbose);
		} else {
			message("Skipping $tag: no answer from server");
			next;
		}
		say STDERR $content if ($opt_verbose);
		if ($opt_json) {
			print $content;
		} else {
			my %result;
			my $count = 0;
			my $obj = parse_json($content);
			message("#Time: ". $obj->{"$sequence"}->{time}) if ($opt_debug);
			
			foreach my $id (keys %{$obj->{"$sequence"}->{results}}) {
				$count++;
				$result{id} = $id;
				$result{kmercov} = ${ $obj->{"$sequence"}->{results} }{$id}->{percent_kmers_found};
				my        $match = ${ $obj->{"$sequence"}->{results} }{$id}->{species};
				while ($match =~/(\w[A-Za-z ]+?)\s*:\s*([0-9\.]+)%/g) {
					$result{species} = $1;
					$result{identity} = $2;

					if ($result{identity} >= $opt_minid and $result{kmercov} >= $opt_ths) {
						$res_count++;
						say $res_count, "\t", $result{id}, "\t", $result{species}, "\t", $result{identity}, "\t",$result{kmercov};
						my ($gen, $sp) = split /\s/, $result{species};
						$GENUS{$gen}++;
						$SPEC{"$gen $sp"}++;
					}
					 
					

				}
			}
			 
			
		}
		
	} else {
		message("#Skipping sequence: unrecognized chars found in '$sequence'");
	}
}

if ($res_count) {
	our $sp_count = scalar keys %SPEC;
	our $gn_count = scalar keys %GENUS;
	our @sp_hits;
	our @gn_hits;
	message("#Species found: $sp_count; genus: $gn_count");

	if ($sp_count) {
		@sp_hits = sort {$SPEC{$b} <=> $SPEC{$a}} keys %SPEC;
		message("# $sp_hits[0] -> ". sprintf("%.2f", 100*$SPEC{$sp_hits[0]}/$res_count) );
		message("# $sp_hits[1] -> ". sprintf("%.2f", 100*$SPEC{$sp_hits[1]}/$res_count)) if ($sp_hits[1]);
		message("# $sp_hits[2] -> ". sprintf("%.2f", 100*$SPEC{$sp_hits[2]}/$res_count)) if ($sp_hits[2]);
	}

	if ($gn_count) {
		@gn_hits = sort {$GENUS{$b} <=> $GENUS{$a}} keys %GENUS;
		message("# $gn_hits[0] -> ". sprintf("%.2f", 100*$GENUS{$gn_hits[0]}/$res_count) );
		message("# $gn_hits[1] -> ". sprintf("%.2f", 100*$GENUS{$gn_hits[1]}/$res_count)) if ($gn_hits[1]);
		message("# $gn_hits[2] -> ". sprintf("%.2f", 100*$GENUS{$gn_hits[2]}/$res_count)) if ($gn_hits[2]);
	}
	if ( ( $SPEC{$sp_hits[0]} / $res_count ) > $min_res_frac ) {
		message(">Species:\t$sp_hits[0]\t$SPEC{$sp_hits[0]}/$res_count");

	} elsif ( ( $GENUS{$gn_hits[0]} / $res_count ) > $min_res_frac ) {
		message(">Genus:\t$gn_hits[0]\t$GENUS{$gn_hits[0]}/$res_count");
	}
} else {
	message("No hits found");
}


sub extractSeq {
	my $text = shift @_;
	$text =~s/\s//g;
	$text = uc($text);
	if ($text =~/([ACGT]{$min_stretch,})/) {
		return $1;
	}
	message("#Sequence has a DNA stretch shorter than $min_stretch. Skipped");
	return '';
}

sub message {
  my $message = shift @_;
  say STDERR '';

  if (substr($message, 0, 1) eq '#') {
  	print STDERR color('green') if ($opt_color);
    print STDERR substr($message, 1),"\n" if ($opt_verbose);
  } elsif (substr($message, 0, 1) eq '>') {
  	print STDERR color('yellow') if ($opt_color);
    print STDERR substr($message, 1),"\n" if ($opt_verbose);
  } else {
    print STDERR "$message\n";
  }

  if ($opt_color) {
  	print STDERR color('reset');
  }
}

__END__	


=head1 NAME
 
B<kBactSearch> - a Perl wrapper to match a query sequence against metagenomic datasets using 'bigsi.io'
 
=head1 AUTHOR
 
Andrea Telatin <andrea.telatin@quadram.ac.uk>
 
=head1 SYNOPSIS
 
kBactSearch.pl [options] QUERY_SEQUENCE(s)
 
=head1 DESCRIPTION
 
This program is an experimental wrapper to automate queries against 'bigsi.io', that indexed the complete 
bacterial and viral whole-genome sequence content of the European Nucleotide Archive as of December 2016, 
from the command line.
More info at https://bigsi.readme.io/ and http://github.com/phelimb/bigsi.
 
=head1 PARAMETERS
 
=over 12

=item I<-j, --json>

Print raw output from web service in JSON format. Default output is TSV with the following columns:
serial number, experiment accession number, species name, species abundance in sample, matching kmers

=item I<-t, --threshold>

Minimum threshold (k-mers) for search, as floating point. Default = 1;

=item I<-m, --minabundance>

Print only species with abundance higher than this. Each sample can contain multiple species,
with this parameters is possible to reduce the output to the most abundant.
Default = 70

=item I<-i, --interactive>

Will ask for sequence interactively at runtime.

=item I<-c, --color>

Use colored messages for STDERR

=item I<-v, --verbose>

Enable verbose mode

=item I<-d, --debug>

Always print raw output from web service

 
=back