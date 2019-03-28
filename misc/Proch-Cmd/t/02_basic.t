use strict;
use warnings;
use Proch::Cmd;
use Test::More tests => 1;

my $command = Proch::Cmd->new(
	command => 'whoami | wc -l',
);

my $output = $command->simplerun();

ok($output->{output} eq "1\n", "Output [whoami| wc -l] is 1: correct");

