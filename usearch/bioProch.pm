#!/usr/bin/env perl

package prochPipes;

require Exporter;
use v5.16;
use Carp;
use Term::ANSIColor;
use Data::Dumper;
local $Data::Dumper::Terse = 1;
our @ISA = qw(Exporter);
our @EXPORT = qw(
    crash 
    deb 
    ver 
    mod_toy 
    auto_dump 
    set_globals 
);

our %color = (
        'error'    =>    'white on_red',
        'red'      =>    'red',
        'green'    =>    'green',
        'cyan'     =>    'cyan',
        'reset'    =>    'reset',
        'yellow'   =>    'yellow',
        'bold'     =>    'bold',
);

my @valid_settings = qw(no_color timestamp);
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
};

BEGIN {
	# Check dependencies?

}

sub cmd {
    my ($cmd) = @_;

    # cmd
    #   $command
    #   $description
    #   @input_exists/_notnull/_fasta/_fastq
    #   @output_exists/_notnull/_fasta/_fastq
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
    print STDERR _color('yellow'), "VARIABLE <$name>:\n";
	print STDERR Dumper $ref;
    print STDERR _color('reset'), "";
}

sub crash {
	my ($err, $glob) = @_;
    # ERROR:
	#  message*     string        error message for the user
	#  title        string, opt   title (default FATAL ERROR)
	#  dumpvar      ref

    # 

	my ($package, $filename, $line) = caller;
	
	# DEFAULTS
	$err->{title} = $err->{title} // 'FATAL ERROR';
	$err->{code}  = $err->{code}  // 1;

	# RED_ON

	print STDERR _color('error'), " *** " , $err->{title} , " *** \n";
	print STDERR " $filename -> $package\[line:$line\] -> ", (caller(0))[3], _color('reset'), "\n";


	if (defined $err->{dumpvar}) {
	 
		say _color('yellow'), " Additional info:\n ", Dumper  $err->{dumpvar};
		print STDERR _color('reset'), "";
	}

	say _color('bold'), $err->{message}, _color('reset');
	exit $err->{code};
}

sub deb {

}

sub ver {

}

sub mod_toy {

}





1;
