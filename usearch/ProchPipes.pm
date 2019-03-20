#!/usr/bin/env perl

package ProchPipes;

require Exporter;
use v5.16;

use Carp;
use Time::HiRes qw(gettimeofday tv_interval);
use Term::ANSIColor;
use Data::Dumper;
$Data::Dumper::Terse = 1;

use Storable qw(nstore store_fd nstore_fd freeze thaw dclone);
use Digest::MD5 qw(md5 md5_hex md5_base64);
use File::Spec;



our @ISA = qw(Exporter);
our @EXPORT = qw(
    set_globals 

    crash 
    deb 
    ver 

    cmd

    mod_toy 
    auto_dump 
    
);

our %color = (
        'error'    =>    'white on_red',
        'debug'    =>    'yellow',
        'verbose'  =>    'reset',
        'red'      =>    'red',
        'green'    =>    'green',
        'cyan'     =>    'cyan',
        'reset'    =>    'reset',
        'yellow'   =>    'yellow',
        'bold'     =>    'bold',
);

my @valid_settings = qw(no_color debug verbose timestamp);
# GLOBAL VARIABLES
# no_color            bool, disable color print
# log_file            str,  save info to this file (will always check permissions)
# project_name        str, 


# FUNCTIONS
# crash(ERR, GLOBALS)	Die better


# DEFAULTS
our @aux = undef;
our $SETTINGS = {
	no_color   => 1,
    debug      => 0,
    verbose    => 0,
};

BEGIN {
	# Check dependencies?

}

 
sub cmd {
    state $counter = 0;
    $counter++;
    my ($cmd) = @_;
    $cmd->{messages} = '';
    $cmd->{status}   = 1;

    auto_dump($cmd) if (! $cmd->{no_dump});
    # CHECK input_exists
    foreach my $file ( @{ $cmd->{check_in} }) {
        if ( ! -e "$file" ) {
            $cmd->{status} = 0;
            $cmd->{messages}.= "Input file <$file> not found";
            

        } else {
            my $chk = file_checksum("$file");
            push(@{ $cmd->{check_in_ok} }, "$file:$chk");
        }
    }

    # TO CACHE OR NOT TO CACHE: Check Command AND input files

    my $cmd_start_time = [gettimeofday];    
    my $redirector = '';
    $redirector = '2>&1' if ($cmd->{redirect}->{err_to_out});
    $redirector = '2>/dev/null' if ($cmd->{redirect}->{discard_err});
  
    $cmd->{executed} = get_time_stamp();



    my $output = `$cmd->{command} $redirector`;
    
    # cmd
    #   $command
    #   $description
    #   @input_exists/_notnull/_fasta/_fastq
    #   @output_exists/_notnull/_fasta/_fastq

    my $elapsed_time = tv_interval ( $cmd_start_time, [gettimeofday]);
    $cmd->{elapsed_sec} = $elapsed_time;
    my $elapsed_time = formatsec($elapsed_time);
    $cmd->{elapsed_time} = $elapsed_time;

    return $cmd;
}
sub set_globals {
	my $global_settings = shift @_;
	$SETTINGS = $global_settings;
	$SETTINGS->{timestamp} = `date`;
	chomp($SETTINGS->{timestamp});

	return 1;
}
sub _color {
    return '' if ($SETTINGS->{no_color} == 1);
        
	my $requested_color = shift @_;


	
    if (defined $color{$requested_color} ) {
		return color($color{$requested_color});
	} else {
		return color('reset');
	}
	

}

sub auto_dump {
	my ($ref, $name) = @_;
    print STDERR _color('yellow'), get_time_stamp(), " VARIABLE $name\n";
	print STDERR Dumper $ref;
    print STDERR _color('reset'), "";
}

sub crash {
	my ($err, $local_settings) = @_;
    # ERROR:
	#  message*     string        error message for the user
	#  title        string, opt   title (default FATAL ERROR)
	#  dumpvar      ref           also print this variable content


	my ($package, $filename, $line) = caller;
	
	# DEFAULTS
	$err->{title} = $err->{title} // 'FATAL ERROR';
	$err->{code}  = $err->{code}  // 1;

	# RED_ON

	say STDERR  _frame_text($err->{title}), color('reset');
    

	if (defined $err->{dumpvar}) {
	 
		say _color('yellow'), " Debug info:\n ", Dumper  $err->{dumpvar};
		print STDERR _color('reset'), "";
	}

	say STDERR _color('red'),_color('bold'), $err->{message}, color('reset');
    print STDERR (caller(0))[3], " $filename -> $package\[line:$line\] -> ",  _color('reset'), "\n";

	exit $err->{code};
}

sub _frame_text {
    my $string = shift @_;
 #   +-----------------+
 #   |    TEXT         |
 #   +-----------------+

    
    my $spacer = ' ' x 5;
    my $title = $spacer . $string . $spacer;
    my $len = length($title);

    return '+' . ( '-' x $len) . "+\n" .
           '|' . $title .        "|\n" .
           '+' . ( '-' x $len) . "+";
}

sub deb {
    state $counter = 0;
    $counter++;
    # Print a message if {debug = 1}
    return 0 if (! $SETTINGS->{debug});
    my ($message, $local_settings) = @_;
    my $info = get_time_stamp();
    say STDERR _color('debug'), $info , ' ', _color('reset'), $message , " [$counter]";
}

sub ver {
    state $counter = 0;
    # Print a message if {verbose = 1 (or debug = 1, that implies verbose)}
    return 0 if ($SETTINGS->{debug} == 0 and $SETTINGS->{verbose} == 0);
    my ($message, $local_settings) = @_;

    say STDERR _color('verbose'), $message, _color('reset');
}

sub get_time_stamp {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    my $time_stamp = sprintf ( "[%04d-%02d-%02d %02d:%02d:%02d]",
                                   $year+1900,$mon+1,$mday,$hour,$min,$sec);
    return $time_stamp;
}

sub mod_toy {

}

sub file_checksum {
    my ($filename) = @_;
    open (my $fh, '<', $filename) or return 0;
    binmode ($fh);
    return Digest::MD5->new->addfile($fh)->hexdigest;
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


1;
