#!/usr/bin/env perl

use v5.14;
use Getopt::Long;
 

our $opt_debug = 0;
#                            Tn
#                    <----------------->
our $tag = 'CCAGGGTTGAGATGTGTATAAGAGACAG';

our $min_score = 25;
our $min_length = 25;
our $printer_batch = 10000;
our $save_files;
our $outputdir;

our ($TAG_FILE, $SHORT_FILE, $NOTAG_FILE);
my $GetOptions = GetOptions(

	't|tag=s'               => \$tag,
	'm|min-identity=i'      => \$min_score,
	'l|min-length=i'        => \$min_length,
	'u|update-status=i'     => \$printer_batch,
	'o|outdir=s'            => \$outputdir,
	'd|debug'               => \$opt_debug,

);
our $seq2 = $tag;
my @aux = undef;
my ($name, $seq, $qual);
my ($n, $slen, $comment, $qlen) = (0, 0, 0);

if (defined $outputdir) {
	if (-d "$outputdir") {
		$save_files = 1;
		open $TAG_FILE,   '>', "$outputdir/tags.fastq" || die $!, "\n";
		open $SHORT_FILE, '>', "$outputdir/too_short.fastq" || die $!, "\n";
		open $NOTAG_FILE, '>', "$outputdir/untagged_reads.fastq" || die $!, "\n";
	} else {
		die " FATAL ERROR:\n Missing output directory ($outputdir)\n";
	}

}

if (defined $ARGV[0]) {
	open STDIN, '<', $ARGV[0] || die " FATAL ERROR:\n Unable to read $ARGV[0].\n";
} else {
	print STDERR " [waiting sequences from STDIN]\n";
}

my $TOTAL_SEQ = 0;
my $TAG_SEQ = 0;
my $PRINTED_SEQ = 0;

while (($name, $seq, $comment, $qual) = readfq(\*STDIN, \@aux)) {

 	$TOTAL_SEQ++;
 	# Update process
	unless ($TOTAL_SEQ % $printer_batch) {
		print STDERR 
			"$TAG_SEQ/$TOTAL_SEQ have tag; ",
			"$PRINTED_SEQ/$TOTAL_SEQ printed (", 
			sprintf("%.2f", 100*$PRINTED_SEQ/$TOTAL_SEQ), ")\r";
	}


	my ($status, $offset, $score) = smithwaterman($seq);
	my $new_seq = $seq;
	my $new_qual = $qual;

	if ($status) {
		$new_seq  = substr($seq, $offset);
		$new_qual = substr($qual, $offset);
	} 
	my $print_seq = '@' . $name . " $status|off=$offset|scr=$score|num=$TOTAL_SEQ\n$new_seq\n+\n$new_qual\n";


	if ($status) {
		$TAG_SEQ++;

		if ( (length($seq) - $offset) < $min_length) {
			print {$SHORT_FILE} '@', $name, " $offset|$score|$PRINTED_SEQ/$TOTAL_SEQ\n", 
			substr($seq, $offset), "\n",
			"+\n",
			substr($qual, $offset), "\n";
			next;
		} else {

		$PRINTED_SEQ++;
		#print "$seq\n";
		#print '-' x $offset, substr($seq, $offset), "\n";
		print {$TAG_FILE} '@', $name, " $offset|$score|$PRINTED_SEQ/$TOTAL_SEQ\n", 
			substr($seq, $offset), "\n",
			"+\n",
			substr($qual, $offset), "\n";
		}

	} else {
		print {$NOTAG_FILE} '@', $name, " |$offset|$score|seq_no=$TOTAL_SEQ\n", 
			$seq, "\n",
			"+\n",
			$qual, "\n";
	}
}

print STDERR "$PRINTED_SEQ/$TOTAL_SEQ printed (", sprintf("%.2f", 100*$PRINTED_SEQ/$TOTAL_SEQ), ")\n";
sub smithwaterman {
	my $seq1 = shift @_;
	

	# scoring scheme
	my $MATCH     =  1; # +1 for letters that match
	my $MISMATCH = -1; # -1 for letters that mismatch
	my $GAP       = -2; # -1 for any gap

	# initialization
	my @matrix;
	$matrix[0][0]{score}   = 0;
	$matrix[0][0]{pointer} = "none";
	for(my $j = 1; $j <= length($seq1); $j++) {
	     $matrix[0][$j]{score}   = 0;
	     $matrix[0][$j]{pointer} = "none";
	}
	for (my $i = 1; $i <= length($seq2); $i++) {
	     $matrix[$i][0]{score}   = 0;
	     $matrix[$i][0]{pointer} = "none";
	}

	# fill
	 my $max_i     = 0;
	 my $max_j     = 0;
	 my $max_score = 0;


	 for(my $i = 1; $i <= length($seq2); $i++) {
	     for(my $j = 1; $j <= length($seq1); $j++) {
	         my ($diagonal_score, $left_score, $up_score);
	         
	         # calculate match score
	         my $letter1 = substr($seq1, $j-1, 1);
	         my $letter2 = substr($seq2, $i-1, 1);      
	         if ($letter1 eq $letter2) {
	             $diagonal_score = $matrix[$i-1][$j-1]{score} + $MATCH;
	          }
	         else {
	             $diagonal_score = $matrix[$i-1][$j-1]{score} + $MISMATCH;
	          }
	         
	         # calculate gap scores
	         $up_score   = $matrix[$i-1][$j]{score} + $GAP;
	         $left_score = $matrix[$i][$j-1]{score} + $GAP;
	         
	         if ($diagonal_score <= 0 and $up_score <= 0 and $left_score <= 0) {
	             $matrix[$i][$j]{score}   = 0;
	             $matrix[$i][$j]{pointer} = "none";
	             next; # terminate this iteration of the loop
	          }

	         
	         # choose best score
	         if ($diagonal_score >= $up_score) {
	             if ($diagonal_score >= $left_score) {
	                 $matrix[$i][$j]{score}   = $diagonal_score;
	                 $matrix[$i][$j]{pointer} = "diagonal";
	              }
	             else {
	                 $matrix[$i][$j]{score}   = $left_score;
	                 $matrix[$i][$j]{pointer} = "left";
	              }
	          } else {
	             if ($up_score >= $left_score) {
	                 $matrix[$i][$j]{score}   = $up_score;
	                 $matrix[$i][$j]{pointer} = "up";
	              }
	             else {
	                 $matrix[$i][$j]{score}   = $left_score;
	                 $matrix[$i][$j]{pointer} = "left";
	              }
	          }
	         
	       # set maximum score
	         if ($matrix[$i][$j]{score} > $max_score) {
	             $max_i     = $i;
	             $max_j     = $j;
	             $max_score = $matrix[$i][$j]{score};
	          }
	      }
	 }

	 # trace-back

	 my $align1 = "";
	 my $align2 = "";

	 my $j = $max_j;
	 my $i = $max_i;
     my $diag = 0;
     my $up = 0;
     my $left = 0;

	 while (1) {
	     last if $matrix[$i][$j]{pointer} eq "none";
	     
	     if ($matrix[$i][$j]{pointer} eq "diagonal") {
	         $align1 .= substr($seq1, $j-1, 1);
	         $align2 .= substr($seq2, $i-1, 1);
	         $i--; $j--;
	         $diag++;
	      }
	     elsif ($matrix[$i][$j]{pointer} eq "left") {
	         $align1 .= substr($seq1, $j-1, 1);
	         $align2 .= "-";
	         $j--;
	         $left++;
	      }
	     elsif ($matrix[$i][$j]{pointer} eq "up") {
	         $align1 .= "-";
	         $align2 .= substr($seq2, $i-1, 1);
	         $i--;
	         $up++;
	      }  
	 }

	$align1 = reverse $align1;
	$align2 = reverse $align2;

	my $match = $align1;
	$match =~s/-//g;

	$seq1=~/$match/g;
	
	if ($opt_debug) {

		print STDERR "~" x 80, "\n", ">$match<", join(',',@-),"\n";

		print STDERR "Query=", length($seq1), "| diag=$diag left/up=$left/$up | MAXi=$max_i; MAXj=$max_j  i=$i j=$j\n";
		print STDERR "$seq1\n";
		print STDERR '.' x $-[0], " $align2 [tag]\n";
		print STDERR '.' x $-[0], " $align1\n";
		print STDERR "=" x $+[0], "|\n";
	}
	my $status = 0;
	$status = 1 if ($diag > $min_score);

	return ($status, $+[0], $diag, $match);

}
 
sub readfq {
    my ($fh, $aux) = @_;
    @$aux = [undef, 0] if (!(@$aux));	# remove deprecated 'defined'
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
    my $comm = /^.\S+\s+(.*)/? $1 : ''; # retain "comment"
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
            return ($name, $seq, $comm, $qual);
        }
    }
    $aux->[1] = 1;
    return ($name, $seq, $comm);
}


sub print_help {

	print STDERR <<END;

    Given a sequence like:
    XXXXXXX-ADAPTER-YYYYYYYYYY

    The output is only YYYYYYYY, as long its length
    is longer than a threshold

	-t, --tag (String)           $tag
			Tag to scan in the fasta/fastq input file

	-m, --min-identity (Int)     $min_score
			Minimum identities to keep the alignment as valid

	-l, --min-length (Int)       $min_length
			Minimum length after trimming

	-u, --update-status (Int)    $printer_batch
			Update the status every INT sequences

END
}