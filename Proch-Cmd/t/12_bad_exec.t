use strict;
use warnings;
use Proch::Cmd;
use Test::More;

my $command = Proch::Cmd->new(
	command => "this_command_should_faithfully_not_exist",
	die_on_error => 0,
);



SKIP: {

    skip "wrong version", 2 if ( $^O eq 'MSWin32' );
    my $output = $command->simplerun();

    ok($output->{exit_code} != 0, "CMD [...] returned error");
    ok(! defined $output->{output}, "CMD returned no output");
};

done_testing();
