my $table = [ [ 'id', 'Format', 'Size', 'N50'],
              [    1, 'FASTA', 12000,  52],
              [    2, 'FASTA', 142024,  519],
              [    3, 'FASTQ', 953233, 299 ],
              [    4, 'FASTA', 483561, 2019], ];
 
use Term::TablePrint qw( print_table );
 
print_table( $table );
 
# or OO style:
 
use Term::TablePrint;
 
my $pt = Term::TablePrint->new();
$pt->print_table( $table );
