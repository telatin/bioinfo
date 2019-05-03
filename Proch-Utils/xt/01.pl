use 5.012;
use autodie;
use Term::ANSIColor;
use Data::Dumper;
use FindBin qw($Bin);
use lib "$Bin/../lib/";
use Proch::Utils;

say 'Testing colors:';
say Proch::Utils::get('colors');

say 'Get answer?';
Proch::Utils::get_interactive_answer({
  'question'    => 'Hello?',
  'type'        => 'bool',
  'colors'      => 1,
  'feedback'    => 1,
});


Proch::Utils::crash('Error!', { title => 'crash'});
