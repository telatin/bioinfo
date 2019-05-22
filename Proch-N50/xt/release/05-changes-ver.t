use 5.012;
use Test::More;
use FindBin qw($Bin);
use_ok('Proch::N50');

my $last_ver = $Proch::N50::VERSION;
my $changes_file = "$Bin/../Changes";

if (-e "$changes_file") {
	my $version_found = 0;
	open my $F, '<', $changes_file || die $!;
	while (my $line = readline($F) ) {
		$version_found++ if ($line=~/^${last_ver}\t/);
	}
	ok($version_found == 1, "Last version ${last_ver} was found only once");
}
say done_testing();
