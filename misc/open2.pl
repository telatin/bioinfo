use 5.014;
use IPC::Open2;
use Term::ANSIColor;

local (*Reader, *Writer);
my $pid = open2(\*Reader, \*Writer, "bc -l");
my $sum = 2;
for (1 .. 5) {
 print STDERR color('green'), "$_:\t$sum * $sum\n", color('reset');
 print Writer "$sum * $sum\n";
 chomp($sum = <Reader>);
 print STDERR color('yellow'), "$_:\tnow sum = $sum\n\n", color('reset');
}
close Writer;
close Reader;
waitpid($pid, 0);
print "sum is $sum\n";
