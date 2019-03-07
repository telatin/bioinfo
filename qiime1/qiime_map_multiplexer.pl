#!/usr/bin/env perl


use Getopt::Long;
$fasta = 1;
$reads_extension = 'fastq';

print STDERR " PREPROCESS READS TO BETTER SERVE QIIME AND THE COMMUNITY
 ---------------------------------------------------------------------------------
  This program prepare a single FASTQ/A file for Qiime starting from a mapping
  file and a FASTQ file per sample.
 
   -m, --mapping    Mapping file
   -i, --dir        Input directory containing reads. Each sample must have the
                    same name as specified in the mapping file. One file per sample.
   -o, --output     Output file
   -r, --rw         Force rewrite
   -e, --ext        Input file extension [default: fastq]
   -f, --fastq      Output in FASTQ format [default: FASTQ]

";


# TODO subsample reads


$getinfo =GetOptions(
  'm|mapping=s' => \$mapping_file,
  'i|dir=s'     => \$input_dir,
  'o|output=s'  => \$output_file,
  'r|rw'        => \$force_rw,
  'e|ext=s'     => \$reads_extension,
  'f|fastq'     => \$fastq
  );

$fasta = 0 if ($fastq);
if ($output_file eq '' and $mapping_file=~/map/) {
	$output_file=$mapping_file;
	$output_file=~s/map/fna/;
}
die " Missing parameter: MAPPING FILE (-m).\n" unless ($mapping_file);
print STDERR "

 Mapping:   $mapping_file
 Output:    $output_file
 Extension: $reads_extension

";

if (-e "$output_file" and $force_rw<1) {
	die " FATAL ERROR: Output file already exists ($output_file). Use the --rw switch to force rewrite.\n";
} else {
	open (O, ">$output_file") || die " FATAL ERROR:\n Cant write to output file '$output_file'.\n";
}
open (M, "$mapping_file") || die "FATAL ERROR: Unable to open mapping file.\n";

#SampleID    BarcodeSequence   LinkerPrimerSequence  Treatment Reverseprimer Description 
#16191STD8A  TAAGGCGATAGATCGC  TCCTACGGGAGGCAGCAGT   linea     TAGATCGC      16191STD8A
#16197STD8B  TAAGGCGACTCTCTAT  TCCTACGGGAGGCAGCAGT   linea     CTCTCTAT      16197STD8B
#16202STD8C  TAAGGCGATATCCTCT  TCCTACGGGAGGCAGCAGT   linea     TATCCTCT      16202STD8C

while (<M>) {
  $c++;
  next if ($_=~/^#/);

  chomp;
  ($sample_id, $bc, $primer, $tr, $rev, $desc) = split /\t/, $_;
  $barcode{$sample_id} = $bc;
}
print STDERR "Mapping file parsed: $c items.\n";


foreach $sample (keys %barcode) {
  print STDERR "=== NOW PROCESSING SAMPLE: $sample ===\n";
  next if ($sample eq '');
  my $file = getfile($sample, $input_dir);
  print STDERR " File:  $file\n";  
  if (-e "$file") {
    open (I, "$file")|| die " FATAL ERROR:\n Unable to open input file \"$filename\".\n";
    my @aux = undef;
    my $c;
    while (my ($name, $seq, $qual) = readfq(\*I, \@aux)) {
      $c++;
      my $diffs='0';
      #$seq=~s/($for|$rev)//gi;
      my $header = "$sample\_$c $name orig_bc=$barcode{$sample} new_bc=$barcode{$sample} bc_diffs=$diffs";

      if ($fasta) {
        print O ">$header\n$seq\n";
      } else {
        print O "\@$header\n$seq\n+\n$qual\n";
      }
    }
    close I;
  } else {
    print STDERR " MISSING FILE $sample$reads_extension\n";
    push(@missed, "$sample$reads_extension");
  }
}


foreach $m (@missed) {
  print STDERR " Missed: $m\n";
}

sub getfile {
	my ($id, $dir) = @_;
	
	@out = `ls  $dir/$id*$reads_extension`;
	
	if ($#out == 0 and $out[0]) {
		my $i = $out[0];
		chomp($i);
		return $i;
	} else { 
		die " Error: too many files for $id in $dir/*$reads_extension.\n";
	}
}

sub rc {
	my $s= shift;
	my $s=reverse($s);
	$s=~tr/ACGTacgt/TGCAtgca/;
	return $s;
}
sub randbc {
	my $seq;
	%bases = (0 => 'A', 1 => 'C', 2 => 'G', 3 => 'T');
	for (my $i = 0; $i <= 12; $i++) {
		my $dado = int(rand(4));
		my $base = $bases{$dado};
		$seq.=$base;
	}
	return $seq;
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
sub minqual {
  my $string = shift;
  my $min = -1;
 
  for (my $i=0; $i<length($string); $i++) {
    $q = substr($string, $i, 1);
    $Q = ord($q) - 33;
    $min = $Q if ($min<0 or $Q<$min); 
  }
         
  return $min;
}
