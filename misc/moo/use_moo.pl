#!/usr/bin/env perl 
use 5.016;
use BioThing;
use Data::Dumper;
my $commander = BioThing->new(
		name => 'List files', 
		command => qq(ls -lha),
		code => '2',
	);
 

say Dumper $commander;
my $opt = {title => 'test'};
my $output = $commander->run($opt);