use 5.012;
use Term::Size::ReadKey;
 
my ($columns, $rows) = Term::Size::ReadKey::chars *STDOUT{IO};
my ($x, $y) = Term::Size::ReadKey::pixels;

say "+", "-" x ($columns - 2), "+";
for (my $i = 1; $i <= ($rows - 3); $i++) {
 say "|", " " x ($columns - 2), "|";
}
say "+", "-" x ($columns - 2), "+";
