#!/usr/bin/env perl

use v5.14;
use Getopt::Long;
use File::Basename;
our $jobs_dir   = $ENV{'HOME'} . '/slurm/';
our $logs_dir   = $jobs_dir . '/logs';
our $sbatch_dir = $jobs_dir . '/jobs';
our $comments   = '';

my $opt_memory_gb = 16;
my $opt_days      = 0;
my $opt_hours     = 24;
my $opt_cores     = 1;
my $opt_depend;
my $opt_jobname   = '';
my $opt_queue     = 'qib';
my $script_queue = $opt_queue.'-short';

my $opt_mail      = 'none';
my $source_ei     = '';
my $constraint_intel='';
my $opt_recipient = read_content_from_file($ENV{'HOME'}.'/.slurm_default_mail');
my ($opt_logdir, $opt_help, $opt_save, $opt_verbose, $opt_conda,  $opt_intel, $opt_ei, $opt_sendmail, $opt_run, $opt_nocheck, @opt_modules);

my $PWD = `pwd`;
my $GetOptions = GetOptions(
	'help'       => \$opt_help,
	'm|mem=i'    => \$opt_memory_gb,
	'mail'       => \$opt_sendmail,
	'address=s'  => \$opt_recipient,
	'c|cores=i'  => \$opt_cores,
	'd|days=i'   => \$opt_days,
	'h|hours=i'  => \$opt_hours,
	'n|name=s'   => \$opt_jobname,
	'a|after=s'  => \$opt_depend,
	's|source=s' => \@opt_modules,
	'r|run'      => \$opt_run,
	'f|nocheck'  => \$opt_nocheck,
	'l|logdir=s' => \$logs_dir,
	'q|queue=s'  => \$opt_queue,
	'save'       => \$opt_save,
	'ei'         => \$opt_ei,
	'conda'      => \$opt_conda,
	'intel'      => \$opt_intel,
	'verbose'    => \$opt_verbose,

);
init();
help() if ($opt_help);

our $opt_mem_mb = $opt_memory_gb * 1000;

# Tune NBI queue
if ($opt_days > 1) {
	$script_queue = $opt_queue.'-long';
} elsif ($opt_days == 1 or $opt_hours > 2) {
	$script_queue = $opt_queue.'-medium'
}

# Set sendmail iw invoked --mail
if ($opt_sendmail) {
	$opt_mail = 'begin,end,fail';
}

# Enable EI (--ei) or Miniconda3 (--conda)
if ($opt_ei) {
	$source_ei = 'source switch-institute EI'
} elsif ($opt_conda) {
	if ( ! -e $ENV{'HOME'}."/conda_source" ) {
		die " FATAL ERROR:\n Please create a file " . $ENV{'HOME'}."/conda_source" . " to be sourced with Miniconda path\n";
	}
	$source_ei = 'source $HOME/conda_source';
}

# Force intel (--intel)
if ($opt_intel) {
	$constraint_intel = "#SBATCH --constraint=intel";
}

# Check logs dir
if ( ! -d "$logs_dir" ) {
	die "Fatal error:\nUnable to find log directory at \"$logs_dir\".\n";
}

our $source_modules;
my $activate_conda = '';
$activate_conda = 'activate' if ($opt_conda);
foreach my $module (@opt_modules) {
	$source_modules .= "source $activate_conda $module\n";
}
my $slurm_dependencies = '';
$slurm_dependencies = '#SBATCH -d afterok:' . $opt_depend if ($opt_depend);

my $command = join(" ", @ARGV);
my $part_name = validate($command);
$opt_jobname = $part_name unless ($opt_jobname);

  my $r = getProgressiveNumber($opt_jobname, $sbatch_dir);
  $opt_jobname .= '_'.$r;
  $opt_jobname=~s/\s//g;
  $opt_jobname=~s/[^A-Za-z0-9_\-]/-/g;


$comments .= '<Autorun> ' if ($opt_run);
print STDERR "JobName:$opt_jobname\n";




my $template = qq(#!/bin/bash
#SBATCH -p $script_queue
#SBATCH -t ${opt_days}-${opt_hours}:00
#SBATCH -c ${opt_cores}
#SBATCH --mem=$opt_mem_mb
#SBATCH -N 1
#SBATCH -J $opt_jobname
#SBATCH --mail-type=${opt_mail}
#SBATCH --mail-user=${opt_recipient}
#SBATCH -o $logs_dir/${opt_jobname}~%j.txt
#SBATCH -e $logs_dir/${opt_jobname}~%j.err
${slurm_dependencies}
${constraint_intel}
#THIS_JOB_TAGS: $comments
${source_ei}
${source_modules}
export THIS_JOB_NAME="$opt_jobname"
export THIS_JOB_LOGDIR="$logs_dir"
export THIS_JOB_CORES=$opt_cores      
# \$SLURM_NTASKS

cd $PWD
# \$SLURM_SUBMIT_DIR

bash $jobs_dir/node_info.sh > $logs_dir/\${THIS_JOB_NAME}.node_info.txt
$command
);

$template=~s/(^|\n)[\n\s]*/$1/g;

if ($opt_run or $opt_save) {
	open O, '>', "$sbatch_dir/${opt_jobname}.job" || die " Unable to write job to $logs_dir/${opt_jobname}.job\n";
	print O $template;
	close O;
	if ($opt_run) {
		my $output = `sbatch "$sbatch_dir/${opt_jobname}.job"`;
		$output=~/(\d+)/;
		say "JobID:$1";
	}
} else {
	print $template;
}
sub getProgressiveNumber {
	my ($jobname, $dir) = @_;
	die "Unable to find directory <$dir> for 'getProgressiveNumber'\n" 
		unless (-d "$dir");
	my @list = `ls "$dir"/${jobname}*.job 2>/dev/null`;
	my $max = 0;
	for my $file (@list) {
		$file = basename($file);
		if ($file=~/_(\d+)\.job$/) {
			$max = $1 if ($1 > $max);
		}
	}
	$max++;
	return sprintf("%04d", $max);
	exit;
}
sub validate {

	if (! -d "$sbatch_dir") {
		die " Job scripts directory not found at: $sbatch_dir\n";
	}

	if (! -d "$logs_dir") {
		die " Logs dir not found at: $logs_dir\n";
	}
	my $command = shift @_;
	unless ($command) {
		help();
		die "Nothing to do.\n";
	}
	my @frags = split /\s+/, $command;
	my $warnings = 0;

	my $name = '';
	if ($frags[0]!~/(bash|perl|python|R)/) {
		$name = $frags[0];
	} else {
		$name = basename($frags[1]);
	}

	foreach my $f (@frags) {
		
		if ($f=~/\w\.\w{2,4}$/) {
		my $filename = $f;
		$filename =~s/\~/$ENV{HOME}/;
			if (! -e "$filename") {
				$warnings++;
				print STDERR " WARNING * \"$f\" not found, is a file?\n";
			} else {
				print STDERR " * OK found: $f\n";
			}
		}

		last if ($f=~/>/);
	}
	die "Missing files? If not run with --nocheck\n" if ($warnings and !$opt_nocheck);
	return $name;	
}

sub help {
say STDERR<<END;
 ------------------------------------------------------------------------------------
  Prepare job for SLURM scheduler at NBI/QIB
 ------------------------------------------------------------------------------------
 General use:
 sb.pl [options]  'your unix command'

 Options:
   -d, --days  INT              Days required ($opt_days)
   -h, --hours INT              Hours required ($opt_hours)
   -c, --cores INT              CPU cores required ($opt_cores)
   -m, --mem   INT              Gb of RAM required ($opt_memory_gb)
   -n, --name  STR              Job name (can be autogenerated)
   -s, --source STR             Load this module, can be invoked multiple times
   -a, --after INT              After success of JOB ID
   
   --intel                      Force intel CPU
   --ei                         Use EI software catalogue (otherwise NBI)
   --conda                      Source Anaconda (requires \$HOME/conda_source)

   --mail                       Send mail with job details
   --address                    Specify e-mail address ($opt_recipient)

   --save                       Save the job in $sbatch_dir (default: STDOUT)
   -r, --run                    Save AND run the job (default: print to STDOUT)
   -f, --nocheck                Disable filepath check 

   Job files are saved in $sbatch_dir
   Log files are saved in $logs_dir
 ------------------------------------------------------------------------------------

END
exit;
}


sub init {
	for my $dir ($jobs_dir, $logs_dir, $sbatch_dir) {
		check_dir($dir);
	}
}

sub check_dir {
	my $dir_name = $_[0];
	if (! -d "$dir_name") {
		print STDERR " * Warning: jobs folder '$dir_name' was not found. Attempt creating it.\n";
		`mkdir -p "$dir_name"`;
		die "FATAL ERROR: Unable to create '$dir_name'\n" if ($?);
	} else {
		print STDERR " * Directory $dir_name found\n" if ($opt_verbose);
	}
}

sub read_content_from_file {
	my $file = $_[0];
	if (-e "$file") {
		open I, '<', "$file" || die " FATAL ERROR:\n Unable to read parameter file <$file>.\n";
		my $content=<I>;
		chomp($content);
		return $content;
	} else {
		print STDERR " * WARNING: Settings file <$file> was not found. Ignoring.\n" if ($opt_verbose);
		return;
	}
}
