use strict;
use warnings;
use Proch::Cmd;
use Test::More;
use Data::Dumper;





SKIP: {
    skip "wrong version", 1 if ( $^O eq 'MSWin32');
		my $bad_command = Proch::Cmd->new(
			command => "pwd_not_exists",
			description => 'bad command',
			die_on_error => 0,
		);
		my $no_output = $bad_command->simplerun();
		print STDERR Dumper $no_output;
		ok($no_output->{exit_code} != 0,      "Output [pwd_not_exists] returned  error");
		ok(!defined $no_output->{output}, "Output [pwd_not_exists] returned no output");



		my $command = Proch::Cmd->new(
			command => "pwd",
		);
		my $output = $command->simplerun();

    ok($output->{exit_code} == 0,     "Output [pwd] returned no error");
		ok(length($output->{output}) > 0, "Output [pwd] returned some output");

};

done_testing();
