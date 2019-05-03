use 5.012;
use autodie;
use Term::ANSIColor;
use Data::Dumper;
use FindBin qw($Bin);
use lib "$Bin/../lib/";
use Proch::Utils;

say 'Testing colors:';
say Proch::Utils::get('colors');

my $title = 'CUSTOM TITLE';
Proch::Utils::crash("This script should die, title being $title", { title => $title});
