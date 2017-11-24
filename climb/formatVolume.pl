#!/usr/bin/env perl 

use v5.14;
use Pod::Usage;
use Getopt::Long;
use File::Basename;
use Term::ANSIColor  qw(:constants);

my $bin = basename($0);
my $user = 'ubuntu';
my $group = 'ubuntu';

say STDERR GREEN BOLD "
 FORMAT VOLUME FOR CLIMBVM
 -------------------------------------------------------------";
say STDERR<<END;
Syntax:
 $bin -v /dev/vdx -m /mount/point

 Parameters:
  -v, --volume  STRING          Volume to format [eg: /dev/vdc]
  -m, --mount   STRING          Mount point [eg: /data]. 
                                If non existent will be created,
				has to be empty and user owned
  -u, --user    STRING          Owner of mount point [$user]
  -g, --group   STRGIN          Group owner of mount point [$group]
  --format                      Format volume without asking!
  --force                       Ignore warnings
  --debug                       Enable verbose output

  This is an experimental program: currently will print to STDOUT
  commands so redirect to a script before running.
END

my %mounted_volumes;
my %available_volumes;
my %volume_partitions;
my @errors; my @warnings;
my @commands;
my ($opt_volume, $opt_mount, $opt_debug, $opt_format, $opt_force);

# Get parameters from command line
my $result = GetOptions(
	'v|volume=s'    => \$opt_volume,
	'm|mountpoint=s'=> \$opt_mount,
	'format'        => \$opt_format,
	'force'         => \$opt_force,
	'd|debug'       => \$opt_debug,
);

# Validate parameters
if (!defined $opt_volume) {
	push(@errors, 'Required parameter: -v, --volume [VOLUME] missing');
}
if ( $> > 0 ) {
	push(@errors, "You need administrative privileges. Run:\nsudo $0 @ARGV");
}

if (! defined $opt_mount ) {
	push(@errors, "Directory not specified. Use --mount");
}

# Scan mounted volumes and /dev/vd* to check available volumes
# Populate @errors/@warnings
check_volumes();

# DIE IF ERRORS ARE ENCOUNTERED
#
if ($errors[0]) {
    	my $err_count = 0;
	say STDERR "\n  ERRORS FOUND:", RESET;
	foreach my $error (@errors) {
	    $err_count++;
	    say STDERR " - $error"
	}
	exit $err_count;
}

if ($warnings[0]) {
    say STDERR RED BOLD " WARNING: ", RESET;
    say STDERR RED join ("\n  ", @warnings), RESET;
    say STDERR;
}

# 1. FDISK
if ($volume_partitions{$opt_volume}) {
    say STDERR "Skipping partition creation: $opt_volume partition found";

    if (!$opt_format) {
      say STDERR "Do you want FORMAT the volume $opt_volume (data will be lost!) [y/N]";
      my $answer = <STDIN>;
      chomp($answer);
 
      if ($answer ne 'y') {
      	say STDERR "Answer was not 'y': exiting";
	exit 1;
      
      }
      push(@commands, qq(echo " = Creating partition with FDISK"));
      fdisk($opt_volume);
  }

}

my $opt_volume1 = $opt_volume.'1';

# 2. FORMAT: mkfs.ext4 /dev/vdc1
push(@commands, qq(echo " = Format volume (EXT4)"));
push(@commands, qq(mkfs.ext4 $opt_volume1));

# 3. MKDIR /destinationn
push(@commands, qq(echo " = Creating mount point: $opt_mount"));
if (-d "$opt_mount") {
    push(@commands, qq(rmdir "$opt_mount"));
    push(@commands, qq(mkdir "$opt_mount"));
} else {
    push(@commands, qq(mkdir -p "$opt_mount"));
}

# 4. sudo mount /dev/vdc1 example/
push(@commands, qq(echo " = Mount volume"));
push(@commands, qq(mount $opt_volume1 "$opt_mount"));

# 5. sudo chown ubuntu:ubuntu example/
push(@commands, qq(echo " = Change mountpoint owner ($user:$group)"));
push(@commands, qq(chown $user:$group "$opt_mount"));

# 6. df -h

execute_commands(@commands);

sub check_volumes {
    	say STDERR BOLD GREEN "### INITIALIZING", RESET if ($opt_debug);
	my $mount_command = 'mount';
	my @lines = `$mount_command`;
	foreach my $line (@lines) {
		chomp($line);
		my ($what, $where) = split / on /, $line;
		if ($what =~m|/dev/(vd*)|) {
		    	$mounted_volumes{$what}++;
			print STDERR GREEN "#MOUNTED: ", RESET,
			"$what -> $where\n" if ($opt_debug);
			if (defined $opt_volume and $what=~/$opt_volume/) {
				$mounted_volumes{$opt_volume}++;
			}

		}
	}

	my $list_command = 'ls /dev/vd*';
	
	my @volumes_ls = `$list_command`;
	foreach my $line (@volumes_ls) {
		chomp($line);
		$available_volumes{$line}++;
		if ($line=~/^(.*?)(\d+)$/) {
			$volume_partitions{$1} .= "$1$2;";
			say STDERR YELLOW "#PARTIT:  ", RESET, "$1 -> $1$2" if ($opt_debug);
		} else {
			say STDERR GREEN "#DEVICE: ", RESET," $line" if ($opt_debug);
		}
		if ($line=~/$opt_volume(\d+)/) {
		    push(@warnings, "Partition found for $opt_volume: $opt_volume$1");
		}
	}

	if (defined $opt_volume and !$available_volumes{$opt_volume}) {
	    push(@errors, "The volume you specified [$opt_volume] was not found!");
	}

	if (defined $opt_volume and $mounted_volumes{$opt_volume}) {
	    push(@errors, "The volume you specified [$opt_volume] IS MOUNTED!");
	}
}


sub fdisk {
    my $disk = $_[0];
    my $format_command = "(  
    echo n
    echo p
    echo 1
    echo
    echo
    echo w
    ) | fdisk $opt_volume";

    push(@commands, $format_command);
}

sub execute_commands {
	my @commands = @_;
	foreach my $cmd (@commands) {
		say STDERR GREEN "#RUNCMD ", RESET;
		say $cmd;
	}
}
