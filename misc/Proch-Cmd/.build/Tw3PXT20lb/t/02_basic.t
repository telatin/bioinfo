use strict;
use warnings;
use Proch::Cmd;
use Test::More tests => 1;

my $command = Proch::Cmd->new(
	command => 'ls -d /tmp',
);

my $output = $command->simplerun();

ok($output->{output} eq "/tmp\n", "Output is correct");

