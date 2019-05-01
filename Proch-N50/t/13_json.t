use strict;
use warnings;
use Proch::N50;
use Test::More tests => 3;
use FindBin qw($Bin);
eval 'use JSON';
plan skip_all => 'JSON required for this test' if $@;
my $file = "$Bin/../data/small_test.fa";

SKIP: {
	skip "missing input file" unless (-e "$file");
	my $stats = getStats($file, 'JSON');
	my $data = decode_json($stats->{json});
	ok($data->{N50} > 0, 'got an N50');
	ok($data->{N50} == 65, 'N50==65 as expected (in JSON)');
	ok($data->{seqs} == 6, 'NumSeqs==6 as expected (in JSON)');
}

# {
#    "seqs" : 6,
#    "status" : 1,
#    "filename" : "small_test.fa",
#    "N50" : "65",
#    "dirname" : "data",
#    "size" : 130
# }
