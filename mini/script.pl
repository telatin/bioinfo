use 5.012;
use FindBin qw($Bin);
use lib "$Bin/Demo/lib";
use Local::Module;

say "Version: ", $Local::Module::VERSION;

Local::Module->new();

