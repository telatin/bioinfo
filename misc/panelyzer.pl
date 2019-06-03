#!/usr/bin/env perl
 
use Time::HiRes qw( time );
use Getopt::Long;
use File::Basename;
use Digest::MD5 qw(md5 md5_hex md5_base64);
my $version = '0.2.1-hpc';
my $start = time();
my $reference_file = '/path/to/db/hg.fa';
 
$pVal = 0.01;
$minCov = 20;
$minAllele = 4;
$threads = 1;
help() if ($ARGV[0] eq '');
 
$getinfo =GetOptions(
   'h|help'       => \$help,
   '1|i|first=s'  => \$first_pair_file,
   '2|second=s'   => \$second_pair_file,
   'r|ref=s'      => \$reference_file,
   'b|bed=s'      => \$bed_file,
   'l|log=s'      => \$log_file,
   'o|outdir=s'   => \$out_dir,
   't|threads=i'  => \$threads,
   'mincov=i'     => \$minCov,
   'minall=i'     => \$minAllele,
   'bindir=s'     => \$binaries_directory,
   'noclean'      => \$noclean,
   'n|skipannot'  => \$skipannotation,
   'deptest'      => \$deptest,
   'help'         => \$help
 );
  
help() if ($help);
 
my $title = get_title();
echolog("Starting pipeline, version: $version");
print  $title."\n";
 
%required_binaries = (
 'bamtools'        => 'usage: bamtools',
 'bwa'             => 'Heng Li',
 'samtools'        => 'Version:',
 'java'            => 'Usage:',
 'sam_filter.pl'   => 'SAM FILTER TOOL',
 'bedtools'        => 'usage:',
 'vcf_annotate.pl' => 'ANNOTATE VCF',
 'perbasecoverage_stats.pl' => 'COVERAGE'
 #'proch-cov'       => 'proch-cov BAM',
);
 
print STDERR "
 CHECKING PARAMETERS AND DEPENDENCIES:\n";
 
%bin = initialize_dependencies(\%required_binaries);
 
die " [E1] Fatal error: FASTQ reads, reference and BED target are required to start.\n"
    if (!($first_pair_file) or !($reference_file) or !($bed_file));
 
my $start = Time::HiRes::gettimeofday();
 
 
unless ($out_dir) {
    $out_dir = "panel_out";
    print STDERR " [i] Setting output directory to $out_dir\n";
    echolog(" [i] Setting output directory to $out_dir\n");
 
}
unless (-d "$out_dir") {
    print STDERR " [i] Trying to create \"$out_dir\"...";
    `mkdir "$out_dir"`;
    die " Fail" unless (-d "$out_dir");
    print STDERR "Done.\n";
} else {
    print STDERR " [i] Output directory \"$out_dir\" found. Content will be overwritten.\n";
    echolog(" [i] Output directory \"$out_dir\" found. Content will be overwritten.\n");
}
unless ($log_file) {
    $d = `date +%Y%m%d_%H%M`;
    chomp($d);
    $log_file = "$out_dir/bmr_$d\_$first_pair_file.txt";
}
print STDERR " [i] Log file: $log_file\n";
#open(LOG, ">$log_file") || die " [E0] Cant open log file destination \"$log_file\".\n";
 
if ($first_pair_file=~/bam$/) {
    $is_bam=1;
    ($basename, $dir, $ext) = fileparse($first_pair_file, '.bam');
    print STDERR " $base - $dir - $ext ";
    print STDERR " [i] Output basename from BAM: $out_dir/$basename\n";
 
} else {
    ($basename, $rest) = split /_R1/, $first_pair_file;
    ($basename, $dir, $ext) = fileparse($basename, '.fastq');
    print STDERR " [i] Output basename from FASTQ: $out_dir/$basename\n";
 
}
 
printmd5($first_pair_file); 
 
# Find second pair
unless ($second_pair_file) {
    $second_guess = $first_pair_file;
    $second_guess=~s/_R1/_R2/;
    if (-e "$second_guess" and ($second_guess ne $first_pair_file)) {
        $second_pair_file = $second_guess;
    } else {
        print STDERR " [W] Second pair \"$second_guess\" not found.\n";
    }
} elsif (!-e "$second_pair_file") {
    print STDERR " [W] Second pair \"$second_pair_file\" was not found. Ignoring it!\n";
    $second_pair_file = '';
} else {
    printmd5($second_pair_file);    
}
 
# Check input files
 
die " [E2] Fatal error: FASTQ reads \"$first_pair_file\" doesn't exist.\n" unless (-e "$first_pair_file");
die " [E3] Fatal error: BED target \"$bed_file\" doesn't exist.\n" unless (-e "$bed_file");
die " [E4] Fatal error: FASTA reference \"$reference_file\" doesn't exist.\n" unless (-e "$reference_file");
 
 
print STDERR "
 INPUT DATA:
 [i] Data: $first_pair_file $second_pair_file
 [i] Target: $bed_file
 [i] Reference: $reference_file
 
";
# INDEX GENOME
 
unless ($is_bam) {
    if (!-e "$reference_file.bwt" or !-e "$reference_file.ann" or !-e "$reference_file.pac") {
        print STDERR " [I] Reference genome not indexed by BWA. Attempting now...\n";
        my $command = $bin{'bwa'}." index $reference_file";
        run($command, 'BWA reference index #01.1');
        #`echo BWA INDEXING: $command > $log_file; $command 2>> $log_file`;
    } else {
        print STDERR " [-] Reference BWA index found: OK\n";
    }
 
    if (!-e "$reference_file.fai") {
        print STDERR " [I] Reference genome not indexed by samtools. Attempting now...\n";
        my $command = $bin{'samtools'}." faidx $reference_file";
        run($command, 'Samtools faidx  #01.2');
    } else {
        print STDERR " [-] Reference FAI index found: OK\n";
    }
}
@temporary_files = ();
print STDERR "
 STARTING PIPELINE:\n";
 
#print STDERR "\n [i] Starting pipeline\n";
# Align reads
 
unless ($is_bam) {
    $align_cmd = $bin{'bwa'}." mem -t $threads -M $reference_file $first_pair_file $second_pair_file > $out_dir/$basename.raw.sam";
    $filter_cmd = 'perl '.$bin{'sam_filter.pl'}." -i $out_dir/$basename.raw.sam -h -p -q 1 > $out_dir/$basename.sam" unless ($nofilter);
    run($align_cmd, 'Align reads to reference #02.1');
    run($filter_cmd, 'Filtering out bad alignments #02.2');
    push(@temporary_files, "$basename.raw.sam");
    push(@temporary_files, "$basename.sam");
}
# SAM to BAM
$sort_bam = $bin{'samtools'}." sort -@ $threads -O bam -T sorting $out_dir/$basename.temp > $out_dir/$basename.bam";
$index_bam = $bin{'samtools'}." index $out_dir/$basename.bam";
unless ($is_bam) {
    $make_bam = $bin{'samtools'}." view -bS $out_dir/$basename.sam > $out_dir/$basename.temp";
    run($make_bam, "Make BAM file #03.1");
    run($sort_bam, "Sort BAM file #03.2");
    run($index_bam, "Index BAM file #03.3");
 
} else {
 
}
push(@temporary_files, "$basename.temp");
 
 
#INTERSECT
$bed1 = $bin{'bedtools'}. " coverage    -abam $out_dir/$basename.bam -b $bed_file > $out_dir/$basename.covsummary.txt";
$bed2 = $bin{'bedtools'}. " coverage -d -abam $out_dir/$basename.bam -b $bed_file > $out_dir/$basename.perbasecov.txt";
$stats= 'perl '.$bin{'perbasecoverage_stats.pl'}." $out_dir/$basename.perbasecov.txt > $out_dir/$basename.Coverage_on_Target.txt";
$final_bam = $bin{'bedtools'}. " intersect -abam $out_dir/$basename.bam -b $bed_file > $out_dir/$basename.target.temp.bam";
 
# SAM to BAM
$sort_bam1 = $bin{'samtools'}." sort -@ $threads -O bam -T sorting $out_dir/$basename.target.temp.bam > $out_dir/$basename.target.bam";
$index_bam1 = $bin{'samtools'}." index $out_dir/$basename.target.bam";
push(@temporary_files, "$basename.target.temp.bam");
 
# CALLING
$pileup    = $bin{'samtools'}. " mpileup -f $reference_file -Q 16 $out_dir/$basename.target.bam > $out_dir/$basename.mpileup";
$calling1   = $bin{'java'}. " -jar  $binaries_directory/varscan.jar mpileup2snp  $out_dir/$basename.mpileup  ".
        "--strand-filter 0  --p-value $pVal --min-coverage $minCov --min-reads2 $minAllele --output-vcf 1 > $out_dir/$basename.snps.vcf";
$calling2   = $bin{'java'}. " -jar  $binaries_directory/varscan.jar mpileup2indel $out_dir/$basename.mpileup ".
        "--strand-filter 0  --p-value $pVal --min-coverage $minCov --min-reads2 $minAllele --output-vcf 1 > $out_dir/$basename.indel.vcf";
$merging = "cat $out_dir/$basename.indel.vcf $out_dir/$basename.snps.vcf | sort -u > $out_dir/$basename.temporary.vcf";
#$header = "grep ^# $out_dir/$basename.snps.vcf > $out_dir/$basename.vcf";
$filtervcf = "grep ^# $out_dir/$basename.indel.vcf > $out_dir/$basename.vcf && intersectBed -a  $out_dir/$basename.temporary.vcf -b $bed_file >> $out_dir/$basename.vcf";
push(@temporary_files, "$basename.target.temp.bam");
#$filtervcf = "intersectBed -a  $out_dir/$basename.merge.vcf -b $bed_file >> $out_dir/$basename.vcf";
#$annotate1 = $bin{'vcf_annotate.pl'}." $out_dir/$basename.snps.vcf ";
#$annotate2 = $bin{'vcf_annotate.pl'}." $out_dir/$basename.indel.vcf ";
$annotate = $bin{'vcf_annotate.pl'}." $out_dir/$basename.vcf ";
 
push(@temporary_files, "$out_dir/$basename.merge.vcf", "$out_dir/$basename.indel.vcf", "$out_dir/$basename.snps.vcf");
run($bed1, "Per-base coverage calculation #04.1");
run($bed2, "Coverage summary calculation #04.2");
run($stats, "Coverage per target statistics #04.3");
 
run($final_bam, "Intersect alignment with BED #05");
run($sort_bam1, "Sort BAM file #05.2");
run($index_bam1, "Index BAM file #05.3");
 
run($pileup, "Make MPILEUP file #06");
run($calling1, "SNP calling #07.1");
run($calling2, "INDEL calling #07.2");
run($merging, "Merging SNPs and INDELs #07.3");
run($filtervcf, "Filtering VCF #07.4");
unless ($skipannotation) {
    run($annotate, "SNP annotation #08");
}
 
# STATS
open(I, "$log_file") || die " Cant read log at $log_file.\n";
 
#*Coverage stats: 
#*    0:0.28    -> 3964/1416998
#* 1-19:1.36 -> 19330/1416998
#*10-19:1.62 -> 23016/1416998
#*20-29:2.69 -> 38091/1416998
#*30-79:15.03 -> 213021/1416998
#*80+:79.01 -> 1119576/1416998
$waste='TOT_SAM_LINES:$c
NUM_PRINTED_ALN:$ok
NUM_NOQUAL:$noQual
NUM_NOQUAL_BADFLAG:$noQual_noFlag
NUM_NOQUAL_BADFLAG_BADCIGAR:$noQual_noFlag_noCigar';
#47 variant positions reported (0 SNP, 47 indel)
while (<I>) {
        chomp;
        if ($_=~/main_mem\] read (\d+) sequences/) {
                $reads_number += $1;
        } elsif ($_=~/TOT_SAM_LINES:(\d+)/) {
                $rawalignments_number = $1;
        } elsif ($_=~/NUM_PRINTED_ALN:(\d+)/) {
                $alignments_number = $1;
        } elsif ($_=~/mean and std.dev: \(([0-9\.]+), ([0-9\.]+)\)/) {
                ($mean, $st) = ($1, $2);
        } elsif ($_=~/AVG_COV:(\d+)/) {
        $avg_cov = $1;
    }
 
    if ($_=~/COV_RANGE:([^:]+):([^,]+),/) {
        push(@covstats, "$1:$2");
    } 
 
  
    if ($_=~/(\d+) variant positions \((\d+) SNP, (\d+) indel\)/) {
        $num_var = $1;
        $num_snp = $2;
        $num_ind = $3;
    }
     
 
 
} 
 
 
$stat_text.= "
 PIPELINE STATISTICS:
 -----------------------------------------------------------------------------
 Total reads        \t$reads_number
 Total alignments   \t$rawalignments_number
 Filtered alignments\t$alignments_number
 Average coverage   \t$avg_cov\X (on target)
 Variants found     \t$num_var
   of which SNPs    \t$num_snp
   of which INDELs  \t$num_ind
 -----------------------------------------------------------------------------
 Targeted regions coverage per nucleotide:
";
foreach my $i (@covstats) {
    @t = split /:/, $i;
    $stat_text.= " Coverage range: $t[0]\t$t[1]%\n";
}
 
 
# CLEANING UP
unless ($noclean) {
    my $c;
    foreach my $file (@temporary_files) {
        $c++;
        my $cmd = "rm -rf $out_dir/$file";
        run($cmd, "Removing $file #10.$c");
    }
 
}
 
# END
my $time = formatsec(t());
print STDERR "\n Pipeline finished in $time.\n\n";
 
 
print STDERR "$stat_text";
open(LOG, ">>$log_file") || die " [E0] Cant open log file destination \"$log_file\".\n";
print LOG "\n".$stat_text;
#bedtools coverage -d -abam Sorted12.bam -b ../data/panel.exons+15.bed 
#bedtools coverage -d -abam Sorted12.bam -b ../data/panel.exons+15.bed 
sub echolog {
    my $i = shift;
    chomp($i);
    open(L, ">>$logfile");
    print L "#LOG:$i\n";
    close L;
    return 1;
}
sub run {
    my ($cmd, $descr) = @_;
    $script_sh.="# $descr\n$cmd\n\n";
    $global_command++;
    # Write to log
    `echo "# ---------------" >> $log_file`;
    `echo "CMD_START  [$global_command]: $descr " >> $log_file`;
    `echo "COMMAND [$global_command]:   $cmd <end> " >> $log_file`;
    print STDERR " [-] $descr... ";
 
    # Run command, get elapsed time
    my $s = Time::HiRes::gettimeofday();
    `$cmd 2>> $log_file`;
    my $e = Time::HiRes::gettimeofday();
     
    # Print elapsed time
    my $t = sprintf("%.2f", $e - $s);
    `echo "CMD_END  [$global_command]: Command ran in $t seconds." >> $log_file`;
    `echo >> $log_file`;
    print STDERR "Done in ".sprintf("%.2f", $e - $s)." s\n";
     
 
}
 
sub testvcf {
    my $file = shift;
    my $raw = `grep -v '#' "$file" | wc -l`;
    if ($raw =~/(\d+)\s*/) {
        return $1;
    } else {
        return -1;
    }   
}
 
 
 
sub countlines {
    my $file = shift;
    my $raw = `wc -l "$file"`;
    if ($raw =~/(\d+)\s*/) {
        return $1;
    } else {
        return -1;
    }
}
 
sub printmd5 {
    my $file = shift;
    my $digest = getmd5($file);
    echolog("MD5_SUM:$file:$digest");# >> $log_file`;
     
}
sub initialize_dependencies {
    my %t;
    my $binhash = $_[0];
 
    if (!$binaries_directory) {
        ($base, $program_dir, $ext) = fileparse($0);
        $binaries_directory = $program_dir.'hosted_bin/';
        print STDERR " [i] Setting binary dir to $binaries_directory\n";
    }
 
    foreach my $binary (keys %$binhash) {
        my $checkstring = $$binhash{$binary};
 
        if (-e $binaries_directory.$binary) {
            ## *********************************************
            ## CHECK_IN_SELF_BINARY
            ## *********************************************
 
            @test = `$binaries_directory$binary 2>&1`;
            $test = join('|', @test);
            if ($test=~/$checkstring/i) {
                print STDERR " [-] $binary found in $binaries_directory: OK\n";
                $t{$binary} =   $binaries_directory.$binary;    
            } else {
                die " [E] Fatal error: \"$binary\" found in \"$binaries_directory\", but not working...\nDEBUG:\n<<$test>>";
            }
        } else {
            ## *********************************************
            ## CHECK_IN_PATH
            ## *********************************************
 
            @test = `$binary 2>&1`;
            $test = join('|', @test);
            if ($test=~/$checkstring/i) {
                print STDERR " [-] $binary found in PATH: OK\n";
                $t{$binary} = $binary;  
            } else {
                ## *********************************************
                ## CHECK_IN_SELF_BINARY
                ## *********************************************
                if (try_module($binary, $checkstring)) {
 
                } else {
                    die " [E] Fatal error: $binary not found in PATH! (After looking in $binaries_directory $binary)\nDEBUG:\n<<Raw: $test>>";
                }
             
            }
 
        }
    }
    return %t;
}
 
 
sub try_module {
    my ($program, $teststr) = @_;
    unless ($module_loaded) {
        my $m = `. /etc/profile.d/modules.sh`;
        print " [i] Loading modules: $m\n";
        $module_loaded++;
    }
    `module load $program`;
    @test = `$binary 2>&1`;
    $test = join('|', @test);   
    if ($test=~/$teststr/i) {
        print STDERR " [-] $program found in PBS MODULE with the same name: OK: $teststr in $test\n";
        $t{$binary} = $binary;  
        return 1;
    } else {
        die " [E] Fatal error: $program not found in MODULE! (After looking in $binaries_directory  AND in PATH)\n";
        return 0;
    }
}
 
 
sub t {
    my $end = Time::HiRes::gettimeofday();
    return sprintf("%.2f", $end - $start);
} 
 
sub formatsec { 
  my $time = shift; 
  my $days = int($time / 86400); 
   $time -= ($days * 86400); 
  my $hours = int($time / 3600); 
   $time -= ($hours * 3600); 
  my $minutes = int($time / 60); 
  my $seconds = $time % 60; 
  
  $days = $days < 1 ? '' : $days .'d '; 
  $hours = $hours < 1 ? '' : $hours .'h '; 
  $minutes = $minutes < 1 ? '' : $minutes . 'm '; 
  $time = $days . $hours . $minutes . $seconds . 's'; 
  return $time; 
}
sub get_title {
return "ILLUMINA PANEL ANALYZER v. $version                  Andrea Telatin 2014
 -----------------------------------------------------------------------------";
}
 
sub help {
my $title = get_title();
print  $title.  
"
  This script performs a full variant calling for target enrichment experiments
   starting from either FASTQ reads or BAM aligments. 
 
   -1, --first FILE           First pair file (should contain R1 in the name)
                              If a BAM file is supplied will skip alignment!
   -2, --second FILE          Second pair, if the first doesn't have R1
   -b, --bed FILE             Target regions
   -r, --ref FILE             Reference genome [hg19 default]
   -t, --threads INT          CPU cores 
 -----------------------------------------------------------------------------
";
 
print  "
 
 Other parameters:
  -n, --skipannotation       Skip variant annotation step
  -2, --second FILE          Second pair (autodetected using _R1/_R2 scheme)
  -o, --outdir DIR           Output directory
  --mincov INT               Minimum coverage for SNP calling
  --minall INT               Minimum reads supporting alternative allele
  --noclean
  -h, --help                 Display this message
  -d, --deptest              Test dependencies (skipped if no arguments)
 -----------------------------------------------------------------------------
 This pipeline requires samtools, bedtools, java, varscan and bwa to be
 available. If no system-wide program is found, a local binary will be used.
 Steps:
  1) Alignment of the pairs (or single ends) against the reference using BWA
  2) Proper pair filter using custom script
  3) Sam to BAM pipeline
  4) Mpileup generation using samtools
  5) SNP and INDEL calling using VarScan
  6) Merge, sort and filter variants in a single file
  7) Intersection with the supplied bed file using bedtools
  8) Annotation with custom script
 ----------------------------------------------------------------------------- 
 ";
 
initialize_dependencies(\%required_binaries) if ($deptest);
exit;
}
 
 
sub getmd5 {
    my $file = shift;
    my $digest = md5($data);
    return $digest;
 
}
