use 5.012;
use Test::More;
use FindBin qw($Bin);
use_ok('Proch::N50');
my $last_ver = $Proch::N50::VERSION;
my $changes_file = "$Bin/../Changes";
open my $out, '>', "$Bin/Changes.clean";

if (-e "$changes_file") {
	my $version_found = 0;
	open my $F, '<:encoding(UTF-8)', $changes_file || die $!;
	my $c = 0;
	while (my $line = readline($F) ) {
		chomp($line);
		$c++;

		$version_found++ if ($line=~/^${last_ver}\t/);

		my $clean_line = $line;
		$clean_line =~s/[^'"~;\@A-Za-z0-9\*,\.\!\?\-_ \t()\[\]{}\\\/:]+//g;
		say {$out} $clean_line;
		print STDERR "[ORIGI $line]\n[CLEAN $clean_line]\n" if (length($line)!=length($clean_line));
		ok(length($line) == length($clean_line), 
			"Line #$c has not weird chars: " . length($line) . ' == ' . length($clean_line)
		);
	}
	ok($version_found == 1, "Last version ${last_ver} was found only once: $version_found");
	done_testing();

} else {
	print STDERR "<$changes_file> not found\n";
}
