use strict;
use warnings;
use Proch::N50;
use Test::More;
use FindBin qw($Bin);

my $file = "$Bin/../data/sim2.fa";
my $script = "$Bin/../bin/n50";

if (-e "$file" and -e "$script") {
	my $output = `perl "$script" "$file" 2>/dev/null`;
	ok($? == 0, '"n50" script executed');
	chomp($output);
	ok($output == 493,  "N50==493 as expected: got $output");

	# TSV FORMAT
	$output = undef;

	$output = `perl "$script" --format tsv "$file" 2>/dev/null`;
	ok($? == 0, '"n50" script executed');
	chomp($output);

	my @data = split /\t/, $output;
	ok($#data == 10,  "Tabular output produced");
	ok($data[0] =~/^#/, "Header produced");
	ok($data[7] == 7_530, "Total size is 7,530: $data[7]");


	# THOUSAND SEPARATOR
	$output = undef;

	$output = `perl "$script" --format tsv -q "$file" 2>/dev/null`;
	ok($? == 0, '"n50" script executed');
	chomp($output);

	@data = split /\t/, $output;
	ok($#data == 10,  "Tabular output produced");
	ok($data[0] =~/^#/, "Header produced");
	ok($data[7] eq "7,530", "Total size is 7,530 with thousand separator: $data[7]");
}

done_testing();
