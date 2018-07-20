#!/usr/bin/env perl

use strict;
use Time::HiRes qw( time );
use Getopt::Long;
use File::Basename;
use Term::ANSIColor  qw(:constants);
use Pod::Usage;

my $program_version = '1.06';
my @nums = (0..9,'a'..'z','A'..'Z');
my %nums = map { $nums[$_] => $_ } 0..$#nums;

my $min_merge = 20;
my $max_merge = 280;
my $log_file;

# short descr
print STDERR "
	MICROBITTER (Andrea Telatin - Cambridge Feb 2016) v. $program_version
	-----------------------------------------------------------------------
	 -i 	Input Directory (with list of .gz or .fastq files)
	 -o 	Output Directory 
	 -m 	Mapping File
	 -f     No filter
	 -h     Extended help
	
";



# dependencies
my %bin = (
	'fastq_quality_tool.pl' => 1,
	'qiime_map_multiplexer.pl' => 1,
	'flash' => 1,
	'validate_mapping_file.py' => 1
);
&check_dependencies();

# parameters
my $output_directory;
my $help;
my $mapping_file;
my $input_directory;
my $debug;
my $output_directory;
my $public_run_subroutine_command = 0;
my $nofilter;

my $get_opt =GetOptions(
	'i|input-directory=s' => \$input_directory,
	'o|output-directory=s'=> \$output_directory,
    'h|help'              => \$help,
    'm|mapping-file=s'    => \$mapping_file,
    'f|nofilter'          => \$nofilter,
    'd|debug'             => \$debug
); 

pod2usage({-exitval => 0, -verbose => 2}) if ($help);

unless ($input_directory) {
	$input_directory = shift(@ARGV);
}
opendir(my $dh, $input_directory) || 
	die "Missing input directory (-i): $input_directory\n" . $!;

die " Missing output directory (-o).\n" unless ($output_directory);
unless (-d "$output_directory") {
	`mkdir "$output_directory"`;
	die " Unable to create output directory $output_directory.\n" if ($?);
	
}
$log_file = $output_directory.'/log_file.txt';
initializeLog($log_file);

my %forward;
my %reverse;

print STDERR GREEN BOLD " STEP1: Scanning files\n", RESET;

# Scan files
# -> Create list of samples to be processed
my $gunzip_counter = 0;
while (my $current_file = readdir($dh))  {
	#ID34031FROM30538_S7_L001_R2_001.fastq.gz
	#                    1:BASE              4:R1,R2        6:GZ
	if ($current_file =~/([^_]+)_(\w+)_(\w+)_(R[12])_(\d+).fastq(.*)/) {
		my $base = $1;
		my $ext  = $6;
		my $strand = $4;
		if ($ext eq '.gz') {
			$gunzip_counter++;
			deb("Decompress;$current_file");
			`gunzip "$input_directory/$current_file"`;
			die " FATAL ERROR: Error $? returned trying to decompress $current_file\n" if ($?);
		} elsif ($ext) {
			deb("Skipping;$current_file");
			next;
		}
		
		#Strip .gz (should be decompressed now)
		$current_file =~s/.gz$//;
		die " FATAL ERROR: Decompressing the file should give \"$input_directory/$current_file\". \n I cant find it.\n" 
			if (!-s "$input_directory/$current_file");
		if ($strand eq 'R1') {
			deb("Adding R1;$current_file");
			$forward{$base} = $current_file;
		} elsif ($strand eq 'R2') {
			deb("Adding R2;$current_file");
			$reverse{$base} = $current_file;
		} else {
			print STDERR ":WARNING: $4 not Rx in $current_file\n";
		}
	} else {
		deb("Skipping; $current_file not relevant");
	
	}

}

closedir($dh);

# FLASH MERGE READS R1 and R2
# ---------------------------------
print STDERR GREEN BOLD " STEP2. Flashing files...\n", RESET;
my $mappingFake = "#SampleID\tBarcodeSequence\tLinkerPrimerSequence\tTreatment\tReverseprimer\tDescription\n";
my $c = 0;
foreach my $forward_file (keys %forward) {
	$c++;
	my $for = $input_directory.'/'.$forward{$forward_file};
	my $rev = $input_directory.'/'.$reverse{$forward_file};
	my $primerRand = randomPrimer($c);
	$mappingFake .= "$forward_file\t$primerRand\tTCCTACGGGAGGCAGCAGT\t$c\tTCCTACGGGAGGCAGCAGT\tMicrobIT$c\n";
	die " No reverse found for $forward_file ($for).\n" unless (-e $for);
	my $command = qq(flash -m $min_merge -M $max_merge -o "$output_directory/$forward_file" $for $rev);
	run($command, "Flashing $forward_file [$primerRand]");
	my $delete = qq(rm "$output_directory/$forward_file.notCombined_1.fastq" && rm "$output_directory/$forward_file.notCombined_2.fastq");
	run($delete, "Cleaning poo");

}

# Create mapping file (empty)
unless ($mapping_file) {
	$mapping_file = "$output_directory/mapping_auto.tsv";
	open(O, ">", $mapping_file ) || die  "Unable to write mapping file to $mapping_file\n";
	print O $mappingFake;
	close O;	
	deb("Mapping file created: $mapping_file");
} else {
	die " FATAL ERROR:\n Mapping file provided ($mapping_file) does not exist\n"   unless (-e "$mapping_file");
	my $copy = qq(cp "$mapping_file" "$output_directory/mapping_auto.tsv" );
	run($copy, "Copying mapping file");
	$mapping_file = "$output_directory/mapping_auto.tsv";
}
opendir(my $dh, "$output_directory") || 
	die "Missing input directory (-i): $input_directory\n" . $!;


# Filter by quality the extende fragments
# ---------------------------------
print STDERR GREEN BOLD " STEP3. Quality filter...\n", RESET;
while (my $file = readdir($dh)){
	my $out = $file;
	$out =~s/fastq/fq/;
	next unless ($file=~/extended/);
	deb("info; Found $file in $output_directory");
	if ($file=~/fastq/) {
		my $command = qq(fastq_quality_tool.pl -f "$output_directory/$file" -minq 33 > "$output_directory/$out");
		run($command, "Filtering $file");
	}
}

# Prepare single FNA file for Qiime
# ---------------------------------
print STDERR GREEN BOLD " STEP4. Prepare reads...\n", RESET;
my $fna_file = "$output_directory/reads.fna";
my $multimapper = qq(qiime_map_multiplexer.pl -m "$mapping_file" -o "$fna_file" --ext "fq"  --dir "$output_directory");
run($multimapper, "The famous fake multiplexer");
my $compress = "gzip $output_directory/*extended*";
run($compress, "Compressing extended fragments");
$compress = "gzip $input_directory/*fastq";
run($compress, "Compressing extended fragments");

# Qiime 
# ---------------------------------
print STDERR GREEN BOLD " STEP5. Qiime...\n", RESET;
my $validate = qq(validate_mapping_file.py -s -m "$mapping_file");
my $invalid = run($validate, "Validating mapping file");
die " FATAL ERROR:\nMapping file not valid\n" if ($invalid);

my $closed = qq(pick_closed_reference_otus.py -i "$output_directory/reads.fna" -o "$output_directory/OTUs");
run($closed, "Pick closed reference");
my $filter = qq(filter_otus_from_otu_table.py -i "$output_directory/OTUs/otu_table.biom" -o "$output_directory/OTUs/filtered.biom" --min_count_fraction 0.00005);
run($filter, "Filtering OTUs") unless ($nofilter);


    
sub randomPrimer {
	my $number = shift;
	my $base4  = to_base(4, $number);
	$base4=~tr/0123/ACGT/;
	my $length = 8;
	my $stretch = 'A' x ($length - length($base4));
	my $result = $stretch.$base4;
	my $return;
	for (my $i = 0; $i < length($result); $i++) {
		$return.= substr($result, $i, 1) . substr($result, $i, 1);
	}
	return $return;
}
sub to_base    {
        my $base   = shift;
        my $number = shift;
        return $nums[0] if $number == 0;
        my $rep = ""; # this will be the end value.
        while( $number > 0 )
        {
            $rep = $nums[$number % $base] . $rep;
            $number = int( $number / $base );
        }
        return $rep;
    }
 
sub fr_base {
        my $base = shift;
        my $rep  = shift;
        my $number = 0;
        for( $rep =~ /./g )
        {
            $number *= $base;
            $number += $nums{$_};
        }
        return $number;
}

sub deb {
	return 0 if (!$debug);
	
	my $input = shift;
	my $title;
	my $message;
	chomp($input);
	if ($input =~/;/) {
		($title, $message) = split /;/, $input;
		print STDERR BOLD YELLOW " $title ";
	} else {
		$message = $input;
	}
	print STDERR CYAN "$message\n", RESET;
}

sub run {
	# Requires: $log_file, $public_run_subroutine_command publicly available
	# Requires: use Time::HiRes qw( time );
	my ($cmd, $descr) = @_;
	my $timeStamp = timeStamp();
	$public_run_subroutine_command++;
	$descr = 'Computing...' unless ($descr);
	
	my $headerLog = "\n# --------------------------------------------------------------------\n".
		"# [INFO] Running command $public_run_subroutine_command\n".
		"# [INFO] Timestamp: $timeStamp\n";
																					# echo ' (start)
	`echo "$headerLog# [INFO] Task: $descr\n$cmd\n# --------- Command log ---------\necho '\n" >> $log_file`;
	
	print STDERR BOLD " [$public_run_subroutine_command]", RESET, "\t$descr\n", BLUE, "#$cmd\n", RESET;
	my $s = Time::HiRes::gettimeofday();
	`$cmd 2>> $log_file`;
	`echo "'\n" >> $log_file`;
	
	my $msg  = "[ !!! ERROR $? ]" if ($?);
	
	my $e = Time::HiRes::gettimeofday();
	my $elapsed = formatsec(sprintf("%.2f", $e - $s));
	my $tree = `tree "$output_directory"`;
	#`echo "#TREE\n$tree\n#
	`echo "[INFO] Finished in $elapsed $msg s " >> $log_file`;

	print STDERR YELLOW "\t\t$msg Done in $elapsed\n", RESET;
	return $?;

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
sub timeStamp {
	my $t = `date +%Y-%m-%d_%H:%M:%S`;
	chomp($t);
	return $t;
}
sub check_dependencies {
	
	foreach my $binary (keys %bin) {
		deb("Starting;Checking $binary\n");
		`which "$binary" 2>&1 > /dev/null`;
		if ($?) {
			print STDERR BOLD RED  "\n FATAL ERROR $?\n", RESET;
			die " Dependency '$binary' not found in path. \n";
		}
	}
}

sub initializeLog {
	my $log_file = shift(@_);
	`touch "$log_file"`;
	die " ERROR $?\n Unable to initialize log file: $log_file\n" if ($!);
	my $current_directory = `pwd`;
	my $user_name  = `whoami`;
	my $time = `date`;
	my $md5 = `md5sum "$0"`;
	open LOG, ">>", "$log_file" || die " ERROR 2\n Unable to write to log file: \"$log_file\"\n";
	my $bar = '=' x 80;
	print LOG "$bar\n$bar\n MICROBITTER $program_version\nLaunched by: $user_name";
	print LOG "Working directory: $current_directory";
	print LOG "Time stamp: $time";
	print LOG "MD5: $md5\n";
	
	print LOG $bar."\n";
	close LOG;
}
__END__


=head1 NAME
 
B<microbitter.pl> - Pipeline for Italian Microbiome Project projects

=head1 SYNOPSIS
 
microbitter.pl -i INPUT_DIR -o OUTPUT_DIR -m MAPPING_FILE
 
=head1 DEPENDENCIES
 
This program require the whole Qiime 1.9 environment installed. In addition the following programs have to be in the PATH:

 * flash, available from https://ccb.jhu.edu/software/FLASH/ 
 * qiime_map_multiplexer.pl
 * fastq_quality_tool.pl
   
=head1 PARAMETERS

=over 12

=item B<-i, --input-directory> DIR

Directory containing the sequencing output of the project, i.e. a set of Paired End Illumina files in FASTQ format (.gz accepted).

=item B<-o, --output-directory> DIR

Directory where all output files will be stored. Will be created if not exists.

=item B<-m, --mapping-file> FILE

Mapping file for the project. Each sample name has to start with the same code as the paired end file. 
In general terms this parameter is B<optional> as the program will synthesise a fake mapping file.

=item B<-f, --nofilter>

Skip OTU filtering 0.5%

=item B<-d, --debug>

Enable detailed reporting

=back

=head1 CHANGELOG

v. 1.06
 * Introducing "Validate mapping file step". Exit if failing.
 
v. 1.05
 * Bug fixing (check dependencies didn't check well) 
	 