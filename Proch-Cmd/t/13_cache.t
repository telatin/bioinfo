use strict;
use warnings;
use Proch::Cmd;
use Test::More;
use Data::Dumper;
# Previous test should have worked

my $command = Proch::Cmd->new(
	command => "pwd",
);



SKIP: {

    skip "wrong version", 2 if ( $^O ne 'linux' and $^O ne 'darwin' );
    my $output = $command->simplerun();
    print Dumper $output;
    ok($output->{exit_code} != 0, "CMD [...] returned error");
    ok(length($output->{output}) == 0, "CMD returned no output");
};

done_testing();
