use strict;
use warnings;
use Proch::Cmd;
use Test::More;

my $command = Proch::Cmd->new(
	command => "pwd",
);



SKIP: {
    skip "wrong version", 2 if ( $^O ne 'linux' and $^O ne 'darwin' );
    my $output = $command->simplerun();

    ok($output->{exit_code} == 0, "Output [pwd] returned no error");
    ok(length($output->{output}) > 0, "Output of [pwd] is a string");
};

done_testing();
