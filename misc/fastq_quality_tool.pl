#!/usr/bin/perl
use Getopt::Long;

$SIG{INT} = sub { print "Received SIGINT\n"; $last = 1; };
print STDERR "
  +---------------------------------------------------------------------+
  | The Fastq Quality Filter v 1.06DE         A. Telatin 2012 (C) CRIBI |
  +---------------------------------------------------------------------+
";

$print_every = 100000;

GetOptions('f=s' => \$filename,
	'tags=s' => \$tags,
	'tage=s' => \$tage,
        'rename' => \$rename,
        'il|interleaved' => \$interleaved,
	'ts=i' =>   \$ts,
	'te=i' =>   \$te,
	'minq=f' => \$minq,
	'm|minlen=i' => \$minlen,
	'x|maxlen=i' => \$maxlen,
	'maxrd=i' =>\$maxrd,
	'maxbp=i' =>\$maxbp,
	'fasta'   =>\$fasta,
	'double'  =>\$double,
        'every'   =>\$print_every,
	'test=i' => \$test); 
	
die "
   -f       string    filename (fastq format) [REQUIRED]
   -ts      int       trim start (remove n bases from begin)
   -te      int       trim end (remove n bases from end)
   -tags    string    add string before sequence name (tag start)
   -tage    string    add string at the end of sequence name (tag end)
   -rename            rename read with a progressive number (plus tags)
   -il                reads are interleaved

   -minq    int       minimum average quality of trimmed seq
   -m       int       minimum sequence length
   -x       int       maximum sequence length

   -maxbp   int       print up to n bases then stop
   -maxrd   int       stop after having printed n sequences
   -fasta             print in FASTA rather than FASTQ format
   -double            double endode reads from Color Space      
   -test    int       print only statistics, not reads [every int reads]
                      (when printing seqs, statistics are every 100k)

  Hit Ctrl+C to gracefully stop reading file.
  +---------------------------------------------------------------------+

" unless ($filename);

# Parse parameters
#GetOptions('color:s' => \$variable); # a string value is optional

#GetOptions('color:i' => \$variable); # an integer value is optional
#GetOptions('color=f' => \$variable); # a float value is required
#GetOptions('color:f' => \$variable); # a float value is optional

if  ($filename ne '=') {
	open (STDIN, "$filename") || die " FATAL ERROR:\n Unable to open fastq file '$filename' for reading.\n";
}

# Parse FASTQ
my @aux = undef;

while (my ($name, $seq, $qual) = readfq(\*STDIN, \@aux)) {
    # Check max sequences
    ++$n;
    if ($rename) {
        if ($interleaved) {
                $name = int($n/2);
                my $t = $n%2;
                if ($t) { $name.="_1"; } else { $name.="_2";}
        } else {
               $name = $n;
        }
    }
    $oriq = string2qual($qual); 
    $oribp+=length($seq);
    $sumoriq+=$oriq;
    $avgoriq=sprintf("%.1f", $sumoriq/$n);
    if ($last>0) {
	print STDERR "\n Stopped reading input file by user request.\n";
	last;
    }
    last if ($n == $maxrd);

    next if ($minlen and length($seq) < $minlen);
    next if ($maxlen and length($seq) > $maxlen);

    # Tag reads
    my $seqname = $tags.$name.$tage;
    

    my $avgqual = string2qual($qual);
    next if ($minq and $avgqual < $minq);
    # Check max bp
    $totalbp += length($seq);
    if ($maxbp and ($totalbp > $maxbp)) {
		print STDERR "\nFinishing for maxbp reached $totalbp.\n";
		last;
    }

	
    # print!
    $printed++;

    $sumavg+=$avgqual;
    $avgq  = sprintf("%.1f", $sumavg/$printed);

    $percentage = sprintf("%.1f", 100*$printed/$n).'%';
    if ($test) {

	print STDERR "$printed/$n seqs ($percentage), $avgq/$avgoriq quality (".bp($totalbp,0).'/'.bp($oribp,1).'='.int(100*$totalbp/$oribp)."%).     \r" unless ($n%$test);
	next;	
    } 


	print STDERR "$printed/$n seqs ($percentage), $avgq/$avgoriq quality (".bp($totalbp).'/'.bp($oribp).'='.int(100*$totalbp/$oribp)."%).      \r" unless ($n%$print_every);
    my $firstbase;
    if ($double) {
	($seq, $firstbase) = cs2de($seq);
        $firstbase=" $firstbase";
        $qual=substr($qual, 2);
    }

    # trim
    if ($ts) {
        if ($double) {
                print STDERR " WARNING: I'm not going to trim at the begin. If you want to fuck sequences, do it by yourself.\n" if ($n<100);
                
        } else {
        	$seq = substr($seq,  $ts);
                $qual= substr($qual, $ts);      
        }
    }
    if ($te) {
	$seq = substr($seq, 0, -1*$te);
	$qual= substr($qual,0, -1*$te);
    }


    if ($fasta) {
	print ">$seqname$firstbase\n$seq\n";
    } else {
    	print "\@$seqname$firstbase\n$seq\n+\n$qual\n";    
    }
    
    
}
print STDERR "\n";

sub string2qual {
    my $string = shift;
    my $sum;
    for (my $i=0; $i<length($string); $i++) {
        my $q = substr($string, $i, 1);
        $sum += ord($q) - 33;
    }
    return $sum/length($string) if (length($string));
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

sub bp {
	 my $i = shift;
	if ($i<1000)  {
           return "$i bp";
        } elsif ($i<1000*1000) {
           return sprintf("%.2f", $i/1000).' kbp';
        } elsif ($i<1000*1000*1000) {
	   return sprintf("%.2f", $i/1000000).' Mbp';
        } elsif ($i<1000*1000*1000*1000) {
	   return sprintf("%.2f", $i/1000000000).' Gbp';
	}
}

sub double_encode {
	my $seq = shift;
	$seq =~tr/0123./ACGTN/;
	return $seq;
}

sub cs2de {
        %baseT = (0 => 'T',1 => 'G',2 => 'C',3 => 'A');
        %baseG = (0 => 'G',1 => 'T',2 => 'A',3 => 'C');
        %baseA = (0 => 'A',1 => 'C',2 => 'G',3 => 'T');
        %baseC = (0 => 'C',1 => 'A',2 => 'T',3 => 'G');
	my $s = shift;
        my $l = substr($s, 0, 1);
	my $b = substr($s, 1, 1);
	#remove first to chars
	$s = substr($s, 2);

	$s=~tr/ACGT//;
	$s=~tr/0123./ACGTN/;
	return ($s, ${"base$l"}{$b});
}
