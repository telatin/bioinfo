#!/usr/bin/env perl

use v5.14;

use File::Basename;
use Getopt::Long;
 
# User supplied parameters
my ($opt_sam, $opt_contigs);
my $got_options = GetOptions(
	's|sam-file=s'     => \$opt_sam,
	'c|contigs-file=s' => \$opt_contigs,
);


open my $samFH, '<', "$opt_sam" || crash(qq(Unable to open SAM file: "$opt_sam"));
open my $ctgFH, '<', "$opt_contigs" || crash(qq(Unable to read contigs: "$opt_contigs"));
my @aux = undef;
my ($n, $slen, $qlen) = (0, 0, 0);
while (my ($name, $seq, $qual) = readfq(\$ctgFH, \@aux)) {
    ++$n;
	print "$name\n$seq\n$qual\n";
    $slen += length($seq);
    $qlen += length($qual) if ($qual);
}
print join("\t", $n, $slen, $qlen), "\n";
 


my $sam_lines_total = 0;
my $sam_header_total= 0;
my $contigs_unmapped= 0;
my %ref_size = ();
my %contigs_matches = ();
my ($prev_contig_name, $prev_flag, $prev_ref_name, $prev_pos, $prev_mapq, $prev_cigar, @prev_cols);
# Parse header
while (my $line = readline($samFH)) {
	chomp($line);
	$sam_lines_total++;
	if ($line=~/^@/) {
		# PARSE HEADER
		$sam_header_total++;
		if ($line=~/^\@SQ/) {
			my @parse_line = split /[\t:]/, $line;
			my $ref_name = $parse_line[2];
			my $ref_size = $parse_line[4];
			say STDERR "#REF\t$ref_name -> $ref_size";
			crash("Invalid header: size ($ref_size) not a number?:\nOffending line: $line") 
				if ($ref_size=~/[^0-9]/);

			$ref_size{$ref_name} = $ref_size;
		}
	} else {
		# PARSE BODY
		my ($contig_name, $flag, $ref_name, $pos, $mapq, $cigar, @cols) = split /\t/, $line;

		if ($ref_name eq '*') {
			$contigs_unmapped++;
			next;
		}
		my $contig_seq  = $cols[3];
		my $contig_qual = $cols[4];
		my $contig_size = length($cols[3]);

		say "$contig_name <$contig_size>, $flag, $ref_name, $pos, $mapq, $cigar";
		$contigs_matches{$contig_name}++;
		my $size = cigar_size($cigar);
		if ($contig_name eq $prev_contig_name) {
			print "$contig_name\t$pos:$prev_pos\n";
		}
		($prev_contig_name, $prev_flag, $prev_ref_name, $prev_pos, $prev_mapq, $prev_cigar, @prev_cols) = 
		   ($contig_name,      $flag,      $ref_name,      $pos,      $mapq,      $cigar, @cols)
	}

}

say "Unmapped: $contigs_unmapped";

foreach my $contig (keys %contigs_matches) {
	say "$contig\t$contigs_matches{$contig}";
}
# 1 QNAME String [!-?A-~]{1,254} Query template NAME
# 2 FLAG Int [0,216-1] bitwise FLAG
# 3 RNAME String \*|[!-()+-<>-~][!-~]* Reference sequence NAME
# 4 POS Int [0,231-1] 1-based leftmost mapping POSition
# 5 MAPQ Int [0,28-1] MAPping Quality
# 6 CIGAR String \*|([0-9]+[MIDNSHPX=])+ CIGAR string
# 7 RNEXT String \*|=|[!-()+-<>-~][!-~]* Ref. name of the mate/next read
# 8 PNEXT Int [0,231-1] Position of the mate/next read
# 9 TLEN Int [-231+1,231-1] observed Template LENgth
# 10 SEQ String \*|[A-Za-z=.]+ segment SEQuence
# 11 QUAL String [!-~]+ ASCII of Phred-scaled base QUALity+33
if ($sam_header_total < 1) {
	crash("Input file ($opt_sam) has no header!");
}

say STDERR "$sam_lines_total lines ($sam_header_total header lines)";

 
sub cigar_size {
	my ($cigar) = @_;
	say STDERR "## $cigar";
	while (my $cigar =~/(\d+)([A-Z]+)/g) {
		say STDERR "\t$1:$2";

	}
}
sub crash {
	my ($message, $title) = @_;
	$title = 'FATAL ERROR' unless $title;

	say STDERR " $title";
	die " $message\n";
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