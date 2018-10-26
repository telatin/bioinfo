#!/usr/bin/env perl

use v5.14;
use Term::ANSIColor  qw(:constants);
use Getopt::Long;
use Time::HiRes;
our $time_start = [Time::HiRes::gettimeofday()];

my $opt_log_file =  '/tmp/install_phylosift.log';
my $opt_install_module = 'cpanm -i ##';
my (
	$opt_install_dir,
	$opt_dont_die,
	$opt_no_log,
);

our @perl_modules = (
	'JSON',
	'App::Cmd::Setup',	
	'File::NFSLock',
	'Bio::Phylo'
);
open our $LOG, '>>', "$opt_log_file" || $opt_no_log++;

my $GetOptions = GetOptions(
	'd|install-dir=s'    =>    \$opt_install_dir,
	'l|log-file=s'       =>    \$opt_log_file,
);

splash_screen();
startup_stamp_on_log();

check_perl_modules(@perl_modules);


sub ilog {
	my ($message, $title) = @_;
	$title = 'INFO' unless defined $title;
	my $time_now = Time::HiRes::tv_interval($time_start);
	$time_now=formatsec($time_now);
	print STDERR BOLD CYAN "$title\t", RESET, "$message",
		YELLOW, " ($time_now)\n", RESET;
	
 	unless ($opt_no_log) {
	    print {$LOG} ":$title\t$time_now\tElapsed time: $time_now\n",
	    		"$message\n";
	}
}

sub startup_stamp_on_log {
	(my $date) = runcmd("date");
	(my $wd  ) = runcmd("pwd");
	
	ilog("Starting setup at '$wd' on '$date'",
	   "START");
}
sub check_perl_modules {
	foreach my $module (@_) {
		my (undef, $status)  = runcmd("perl -M$module -e 1 2>/dev/null", undef, 'Dont_Die');
		if ($status) {
			ilog("Perl module '$module' is not installed", "WARNING");
			my $cmd = $opt_install_module;
			if ($cmd =~s/##/$module/g) {
				runcmd($cmd, "Installing Perl module '$module'");
			}


		} else {
			ilog("Perl module '$module' was found", "CHECK");
		}
	}
}
sub runcmd {
    	state $cmd_counter = 0;

	my ($cmd, $title, $local_dont_die) = @_;
	if (defined $title) {
		$cmd_counter++;
		ilog("Running command:\n# $cmd", "CMD_$cmd_counter");
	}
	
	
	my $output = `$cmd`;
	chomp($output);
	my $status = $?;
	my $msg = "Executing this command:\n# $cmd\n Exit status was: $?";

	if ($status > 0 and !$local_dont_die) {
	    	ilog($msg, "ERROR");
		die unless ($opt_dont_die);
	}
	return ($output, $status);
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


sub splash_screen {
	
	print STDERR<<END;
	---------------------------------------------------------------
	Install PhyloSift 1.0.1 
	---------------------------------------------------------------
	Parameters:
	 -d, --install-dir    STR
	 		Destination directory to install PhyloSift
	 		and its Markers Databases

	 -l, --log-file       STR  [Default: $opt_log_file]
	 		Path where to save a log file for the process (append)
END
}

__END__
# BLOG: https://phylosift.wordpress.com/
INSTALL_BASE_DIR=$PWD

# Get package and markers
git clone https://github.com/gjospin/PhyloSift.git

mkdir markers
wget -O markers/data.zip https://ndownloader.figshare.com/articles/5755404/versions/4
unzip markers/data.zip

cd markers
tar xvfz ncbi.tgz
tar xvfz markers.tgz
tar xvfz markers_20140913.tgz
mv markers markers_20140913

for MOD in "App::Cmd::Setup" "File::NFSLock"  "Bio::Phylo" JSON;
do
	if [[ perl -M${MOD} -e 1 ]]; then
		cpanm -i $MOD
	fi
done
 
#Change phylosiftrc

# paths to required datasets
# leave these blank to use whatever is in $prefix/share/phylosift
#
#$marker_path="/home/ubuntu/data/tools/markers/markers";
#$ncbi_path="/home/ubuntu/data/tools/markers/ncbi";
#$marker_dir="/home/ubuntu/data/tools/markers/markers";
#$markers_extended_dir="/home/ubuntu/data/tools/markers/markers_20140913";
#$ncbi_dir = "/home/ubuntu/data/tools/markers/markers";



