use 5.012;
use Term::Size::ReadKey;
 
my ($columns, $rows) = Term::Size::ReadKey::chars *STDOUT{IO};
my ($x, $y) = Term::Size::ReadKey::pixels;

my $title = "Screen Frame v. 1.0";
say "+", "-" x ($columns - 2), "+";
say "|",
	" " x ( ($columns - 2 - length($title)) / 2), 
	$title,
	" " x ( ($columns - 2 - length($title)) / 2), 
	"|";
say "+", "-" x ($columns - 2), "+";

for (my $i = 1; $i <= ($rows - 5); $i++) {
 say "|", " " x ($columns - 2), "|";
}
say "+", "-" x ($columns - 2), "+";

