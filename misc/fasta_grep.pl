#!/usr/bin/env perl

use v5.16;
use Getopt::Long;
use Data::Dumper;

our $VERSION = '0.15';

sub usage {
    my $line = '-' x 60;
    say STDERR<<END;

    PLASMID GREP v. $VERSION
    ${line}

	-i, --input FILE
	                  Input file in FASTA/FASTQ format

	-p, --pattern STRING
	                  DNA pattern to locate. IUPAC allowed.

	-r, --rotate 
	                  Makes the plasmid start where the pattern
	                  is found, if the pattern is unique

	-e, --enzyme STRING
	                  Restriction enzyme name (e.g. EcoRI).
	                  Invoke the parameter twice for slicing
	                  the insert. Assumes unique restriction site.

    This program should be used with a single sequence in the 
    FASTX file, but multiple are allowed. For each sequence will
    check the presence of the pattern.
    If a single instance of the pattern is found, the sequence
    can be rotated/reversed as needed.

    Will print SEQ_NAME:POSITION:STRAND for each sequence having
    a unique hit.

    Examples:
      grep.pl -i file.fa -p GATTACA -r > restarted.fa
      grep.pl -i file.fa -p GATTACA -r -e ecori -e bamhi > insert.fa

END
	exit;
}

my (
		$opt_inputfile,
		$opt_pattern,
		$opt_verbose,
		$opt_rotate,
		$opt_help,
);
my @opt_enzymes = ();

my $GetOptions = GetOptions(
	'i|input=s'         => \$opt_inputfile,
	'p|pattern=s'       => \$opt_pattern,
	'v|verbose'         => \$opt_verbose,
	'e|enzyme=s'        => \@opt_enzymes,
	'rotate'            => \$opt_rotate,
	'h|help'            => \$opt_help,
);

# Essential parameters (-i, -p)
if (defined $opt_help or !defined $opt_inputfile) {
	usage();
}

# Read from STDIN if "-i -"
if ($opt_inputfile ne '-') {
	if (-e "$opt_inputfile") {
		open STDIN, '<', "$opt_inputfile" || die "FATAL ERROR:\nUnable to read input file <$opt_inputfile>.\n";
	} else {
		die "FATAL ERROR:\nInput file <$opt_inputfile> not found.\n";
	}
}

$opt_pattern = uc($opt_pattern);
my $opt_revpattern = rc($opt_pattern);

$opt_pattern = dna_to_regex($opt_pattern);
$opt_revpattern = dna_to_regex($opt_revpattern);

# Load Restriction enzyme DNA sites
our %re_site = re_init();


if ($opt_verbose) {
	say STDERR "Scanning $opt_inputfile for:\n",
	" - $opt_pattern (+)\n - $opt_revpattern (-)";

	say STDERR "Enzymes:"; 
	foreach my $enzyme (@opt_enzymes) {
		$enzyme = uc($enzyme);
		my $dna_pattern = $re_site{$enzyme};
		say STDERR " - $enzyme ($dna_pattern)";
	}

	say STDERR "";
}

# Check provided enzymes are present in the script db
foreach my $enzyme (@opt_enzymes) {
		$enzyme = uc($enzyme);
		my $dna_pattern = $re_site{$enzyme};
		die "FATAL ERROR: Enzyme '$enzyme' not found\n" unless ($dna_pattern);
}
my @aux = undef;
my ($name, $seq);
my $comment = '';

my %count_matches;

while (($name,$comment, $seq, ) = readfq(\*STDIN, \@aux)) {
	my $seq_len = length($seq);

	if ($opt_verbose) {
		say STDERR "Parsing $name...";
	}

	my @pos     = ();
	my @str     = ();
	my $matches =  0;

	while ($seq=~/($opt_pattern|$opt_revpattern)/ig) {
		my $m = $1;
		$matches++;
		my $strand = '+';
		$strand = '-' if ($m=~/$opt_revpattern/i);

		my $end = pos($seq) + 1;
		my $start = $end - length($opt_pattern);

		say STDERR " - match at ${start}-${end} ($strand)" if ($opt_verbose);
		$count_matches{$seq}++;
		push(@pos, $start);
		push(@str, $strand);
	}
	my $print_seq = $seq;
	$comment = ' '. $comment if (length($comment));
	if ($opt_rotate) {
		if ($matches == 1) {
			# If there is only a match
			say STDERR "#$name:$pos[0]:$str[0]";

			
			$print_seq = rotate_seq($print_seq, $pos[0]);
			if ($str[0] eq '-') {
				$print_seq = rc($print_seq);
				$print_seq = substr($print_seq, -1*length($opt_pattern)) . substr($print_seq, 0, -1*length($opt_pattern));
			}


			
			


			# ALTERNATIVE:
			#seqkit grep -s -p '$name $comment'
			#seqkit seq --complement ... 
			#seqkit restart -i $pos[0] ...
		} else {
			say STDERR "Multiple matches ($matches) found. Cannot rotate \"$name\"";
		}


			if (defined $opt_enzymes[1]) {
				my $cutting_1 = $re_site{uc($opt_enzymes[0])};
				my $cutting_2 = $re_site{uc($opt_enzymes[1])};
				$cutting_1 =~s/[^ACGT]//g;
				$cutting_2 =~s/[^ACGT]//g;
				my @ins = ();
				my @feat = ();
				my $inserts_count = 0;
				say STDERR "Looking for inserts $opt_enzymes[0]:$opt_enzymes[1] ($cutting_1:$cutting_2)" if (defined $opt_verbose);
				while ($print_seq=~/${cutting_1}(.+)${cutting_2}/ig) {
					my $pos = pos($print_seq) + 1;
					push(@ins, $1);
					push(@feat, "+ $opt_enzymes[0]:$opt_enzymes[1] at $pos");
					$inserts_count++;
					if (defined $opt_verbose) {
						say STDERR " - Insert found ", length($1), "bp"; 
					}
				}
				say STDERR "Looking for inserts $opt_enzymes[1]:$opt_enzymes[0] ($cutting_2:$cutting_1)" if (defined $opt_verbose);
				while ($print_seq=~/${cutting_2}(.+)${cutting_1}/ig) {
					my $pos = pos($print_seq) + 1;
					push(@ins, $1);
					push(@feat, "- $opt_enzymes[1]:$opt_enzymes[0] at $pos");
					$inserts_count++;
					if (defined $opt_verbose) {
						say STDERR " - Insert found ", length($1), "bp"; 
					}
				}
				if (defined $opt_verbose) {
					say STDERR " - $inserts_count inserts found";
				}
				if ($inserts_count == 1) {
					my $len = length($ins[0]);
					my $bone_len = $seq_len - $len;
					say ">$name$comment [$feat[0]] plasmid=$bone_len;insert=$len;";
					say "$ins[0]";
				}

			} else {
				say ">$name$comment\n$print_seq\n";
			}




	}


}

my $seqs_number = keys %count_matches;
say STDERR "$seqs_number sequences parsed";

sub get_pos {
	my ($seq, $pattern) = @_;

	$pattern = uc($pattern);
	$pattern=~s/[^ACGT]//g;

	if ($seq=~/$pattern/) {
		my $p = $-[0] + 1;
		return $p;
	} else {
		return 0;
	}
}

sub count_matches {
	my ($string, $pattern) = @_;
	my $number = () = $string =~ /$pattern/gi;
	return $number;
}

sub rotate_seq {
	my ($seq, $position) = @_;
	$position--;
	my $start = substr($seq, 0, $position);
	my $end   = substr($seq, $position);
	return $end.$start;
}
sub rc {
	my ($sequence) = @_;
	if ($sequence=~/[^ACGTN]/i) {
		return 0;
	}
	$sequence = reverse($sequence);
	$sequence =~tr/acgtACGT/tgcaTGCA/; 
	return $sequence;
}

sub dna_to_regex {
	my $dna = shift @_;
	$dna = uc($dna);
	my %replacements = (
		'R'      => '[AG]',
		'Y'      => '[CT]',
		'S'      => '[GC]',
		'W'      => '[AT]',
		'K'      => '[GT]',
		'M'      => '[AC]',
		'B'      => '[CGT]',
		'D'      => '[AGT]',
		'H'      => '[ACT]',
		'V'      => '[ACG]',
		'N'      => '[ACGT]',
	);

	for my $r (keys %replacements) {
		$dna =~s/$r/$replacements{$r}/g;
	}
	return $dna;
}
sub readfq {
    my ($fh, $aux) = @_;
    @$aux = [undef, 0] if (!@$aux);
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
    my ($name, $comm) = /^.(\S+)(?:\s+)(.+)/ ? ($1, $2) : 
                        /^.(\S+)/ ? ($1, '') : ('', '');
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
    return ($name, $comm, $seq) if ($c ne '+');
    my $qual = '';
    while (<$fh>) {
        chomp;
        $qual .= $_;
        if (length($qual) >= length($seq)) {
            $aux->[0] = undef;
            return ($name, $comm, $seq, $qual);
        }
    }
    $aux->[1] = 1;
    return ($name, $seq);
}


sub re_init {
	my $re_list = re_load();
	my @l = split /\n/, $re_list;
	my %dna;
	foreach my $e (@l) {
     chomp($e);
     my ($name, $site) = split /\s+/, $e;
     next unless (defined $site);
     $name = uc($name);
     
     $dna{$name} = $site;
	}
	return %dna;
}
sub re_load {
return '
HindIII A/AGCTT
Psp1406I    AA/CGTT
SspI    AAT/ATT
AgeI    A/CCGGT
BspLU11I    A/CATGT
MaeII   A/CGT
MluI    A/CGCGT
PinAI   A/CCGGT
SpeI    A/CTAGT
AluI    AG/CT
BglII   A/GATCT
Eco47III    AGC/GCT
ScaI    AGT/ACT
StuI    AGG/CCT
AseI    AT/TAAT
AsnI    AT/TAAT
BspDI   AT/CGAT
ClaI    AT/CGAT
NsiI    ATGCA/T
SwaI    ATTT/AAAT
AlwNI   CAGNNN/CTG
BbrPI   CAC/GTG
DraIII  CACNNN/GTG
MfeI    C/AATTG
MunI    C/AATTG
NdeI    CA/TATG
NlaIII  CATG/
PmaCI   CAC/GTG
PmlI    CAC/GTG
PvuII   CAG/CTG
AciI    C/CGC
AocI    CC/TNAGG
AvrII   C/CTAGG
BinI    C/CTAGG
BsaJI   C/CNNGG
BsiYI   CCNNNNN/NNGG
BslI    CCNNNNN/NNGG
BssGI   CCANNNNN/NTGG
BstXI   CCANNNNN/NTGG
Bsu36I  CC/TNAGG
EcoNI   CCTNN/NNNAGG
HpaII   C/CGG
KspI    CCGC/GG
MspI    C/CGG
MstII   CC/TNAGG
NcoI    C/CATGG
PflMI   CCANNNN/NTGG
SacII   CCGC/GG
SauI    CC/TNAGG
ScrFI   CC/NGG
SmaI    CCC/GGG
Sse8387I    CCTGCA/GG
SstII   CCGC/GG
Van91I  CCANNNN/NTGG
XcmI    CCANNNNN/NNNNTGG
XmaI    C/CCGGG
XmaCI   C/CCGGG
BsiWI   C/GTACG
BstUI   CG/CG
EclXI   C/GGCCG
FnuDII  CG/CG
MvnI    CG/CG
PvuI    CGAT/CG
ThaI    CG/CG
XmaIII  C/GGCCG
AflII   C/TTAAG
BfaI    C/TAG
BfrI    C/TTAAG
DdeI    C/TNAG
MaeI    C/TAG
PaeR7I  C/TCGAG
PstI    CTGCA/G
RmaI    C/TAG
XhoI    C/TCGAG
AatII   GACGT/C
AspI    GACN/NNGTC
Asp700  GAANN/NNTTC
AspEI   GACNNN/NNGTC
BsaBI   GATNN/NNATC
DpnII   /GATC
DrdI    GACNNNN/NNGTC
Eam1105I    GACNNN/NNGTC
Ecl136II    GAG/CTC
EcoRI   G/AATTC
EcoRV   GAT/ATC
HinfI   G/ANTC
MamI    GATNN/NNATC
MboI    /GATC
NdeII   /GATC
SacI    GAGCT/C
Sau3AI  /GATC
SstI    GAGCT/C
Tth111I GACN/NNGTC
BglI    GCCNNNN/NGGC
Bpu1102I    GC/TNAGC
BsePI   G/CGCGC
BssHII  G/CGCGC
CelII   GC/TNAGC
CfoI    GCG/C
EspI    GC/TNAGC
Fnu4HI  GC/NGC
HhaI    GCG/C
HinPI   G/CGC
ItaI    GC/NGC
NaeI    GCC/GGC
NgoMI   G/CCGGC
NheI    G/CTAGC
NotI    GC/GGCCGC
SphI    GCATG/C
SrfI    GCCC/GGGC
Acc65I  G/GTACC
ApaI    GGGCC/C
AscI    GG/CGCGCC
Asp718  G/GTACC
BamHI   G/GATCC
BstEII  G/GTNACC
FseI    GGCCGG/CC
HaeIII  GG/CC
KasI    G/GCGCC
KpnI    GGTAC/C
NarI    GG/CGCC
NlaIV   GGN/NCC
Sau96I  G/GNCC
SfiI    GGCCNNNN/NGGCC
Alw44I  G/TGCAC
ApaLI   G/TGCAC
Bst1107I    GTA/TAC
HpaI    GTT/AAC
MaeIII  /GTNAC
PmeI    GTTT/AAAC
RsaI    GT/AC
SalI    G/TCGAC
SnoI    G/TGCAC
SnaBI   TAC/GTA
AccII   T/CCGGA
BseAI   T/CCGGA
BspEI   T/CCGGA
BspHI   T/CATGA
MroI    T/CCGGA
NruI    TCG/CGA
RcaI    T/CATGA
TaqI    T/CGA
XbaI    T/CTAGA
AosI    TGC/GCA
AviII   TGC/GCA
BalI    TGG/CCA
BclI    T/GATCA
Bsp1407I    T/GTACA
FspI    TGC/GCA
MluNI   TGG/CCA
MscI    TGG/CCA
MstI    TGC/GCA
SspBI   T/GTACA
AhaIII  TTT/AAA
AsuII   TT/CGAA
BstBI   TT/CGAA
DraI    TTT/AAA
MseI    T/TAA
NspV    TT/CGAA
PacI    TTAAT/TAA
SfuI    TT/CGAA
EcopP15i    CAG/CAG
Tru9I   T/TAA
Nick    CCTCAGC
'
;
}
