use strict;
use warnings;
use Test::More;
my $has_module = eval 'use Test::GreaterVersion; 1;';
print STDERR "Test::GreaterVersion found: OK\n" if ($has_module);
plan skip_all => 'Test::GreaterVersion required for this test' if $@;
has_greater_version_than_cpan('Proch::Utils');
done_testing();
