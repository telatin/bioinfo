#!/usr/bin/env perl

use v5.16;
use File::Basename;
use File::Spec;
use lib File::Spec->rel2abs(dirname($0));

use ProchPipes;

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
	message => "everything is so miserable",
	dumpvar => \$settings,
});