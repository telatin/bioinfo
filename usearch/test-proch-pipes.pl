#!/usr/bin/env perl

use v5.16;
use File::Basename;
use File::Spec;
use Getopt::Long::Descriptive;
use lib File::Spec->rel2abs(dirname($0));

use ProchPipes;

# OPTIONS; USAGE [https://metacpan.org/pod/Getopt::Long::Descriptive]
my ($opt, $usage) = describe_options(
  'my-program %o <some-arg>',
  [ 'error|e=s', 
  		"your custom error message", 
  		{ default => 'This is a fatal error'} 
  ],
  [ 'port|p=i',   
  		"the port to connect to",   
  		{ default  => 79 } 
  ],
  [ 'max-iterations|M=f', 
  		"maximum number of iterations (positive)",
  		{ callbacks => { must_be_positive => sub { shift() > 0 } } } ],
  [],
  [ 'verbose|v',  
  		"print extra stuff"            
  ],
  [ 'help|h',       
  		"print usage message and exit", { shortcircuit => 1 } 
  ],
);
 

print($usage->text), exit if $opt->help;


our $settings = {
	no_color     => 0,
	debug        => 1,
	verbose      => 1,
	cache        => 0,
};

set_globals($settings);

deb("Debug message");
deb("Debug message");
deb("Debug message");
ver("Verbose message");

my $c1 = cmd({
	description    => "A first command",
	command        => qq(ls -l > /tmp/test.info 2> /tmp/test.err),
	check_out      => ["/tmp/test.info", "/tmp/test.err"],
	check_in       => [],
	die_on_error   => 1,
	cache          => 0,
	no_dump        => 1,
});
auto_dump($c1);

my $c2 =cmd({
	description    => "A second command",
	command        => qq(wc -l "/tmp/test.info"),
	check_out      => [],
	check_in       => ["/tmp/test.info"],
	die_on_error   => 1,
	cache          => 0,
	no_dump        => 1,
});

auto_dump($c2);

 


crash({
	title => "Final test: crash [=die]",
	message => $opt->error,
	dumpvar => \$settings,
});