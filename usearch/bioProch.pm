#!/usr/bin/env perl

package bioProch;

require Exporter;
use v5.16;
use Carp;
use Term::ANSIColor;
use Data::Dumper;
	$Data::Dumper::Terse = 1;
our @ISA = qw(Exporter);
our @EXPORT = qw(crash deb ver mod_toy auto_dump set_globals readfq readfq2);

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
sub set_globals {
	my $global_settings = shift @_;
	$SETTINGS = $global_settings;

	$SETTINGS->{timestamp} = `date`;
	chomp($SETTINGS->{timestamp});

	return 1;
}
sub _color {
	my $requested_color = shift @_;

	my %color = (
		'error'    =>    'white on_red',
		'red'      =>    'red',
		'green'    =>    'green',
		'cyan'     =>    'cyan',
		'reset'    =>    'reset',
		'yellow'   =>    'yellow',
		'bold'     =>    'bold',
	);

	if ($SETTINGS->{no_color} == 1) {
		return '';
	} elsif (defined $color{$requested_color} ) {
		return color($color{$requested_color});
	} else {
		return color('reset');
	}
	

}

sub auto_dump {
	my ($ref, $name) = @_;

	say STDERR Dumper $ref;
}

sub crash {
	my ($err, $glob) = @_;
	# message*     string        error message for the user
	# title        string, opt   title (default FATAL ERROR)
	# dumpvar      ref

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


sub readfq {
    my ($filename) = @_;

    if (! $SETTINGS->{readfq_file}->{$filename}) {
    	
    	$SETTINGS->{readfq_file}->{$filename} = 1;
    	@aux = undef;
    	open I, '<', $filename || die;
    	print <I>;
    }  
    my $aux = \@aux;
    my $fh = \*I;
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
    my ($name, $comm) = /^.(\S+)(?:\s+)(.+)/ ? ($1, $2) : 
                        /^.(\S+)/ ? ($1, '') : ('', '');
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
    return ($name, $comm, $seq) if ($c ne '+');
    my $qual = '';
    while (<$fh>) {
        chomp;
        $qual .= $_;
        if (length($qual) >= length($seq)) {
            $aux->[0] = undef;
            return ($name, $comm, $seq, $qual);
        }
    }
    $aux->[1] = 1;
    return ($name, $seq);
}



sub readfq2 {
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
    my ($name, $comm) = /^.(\S+)(?:\s+)(.+)/ ? ($1, $2) : 
                        /^.(\S+)/ ? ($1, '') : ('', '');
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
    return ($name, $comm, $seq) if ($c ne '+');
    my $qual = '';
    while (<$fh>) {
        chomp;
        $qual .= $_;
        if (length($qual) >= length($seq)) {
            $aux->[0] = undef;
            return ($name, $comm, $seq, $qual);
        }
    }
    $aux->[1] = 1;
    return ($name, $seq);
}
1;