use 5.012;
use autodie;
use ReadFastx;
use Term::ANSIColor; 
use Carp qw(confess);
use Data::Dumper;
my $fn1 = 'reads.fa';
my $fn2 = 'reads.fq';

say color('yellow'),'-' x 110, color('reset');

say "FN1 $fn1";
say "FN2 $fn2";
#my $s1         = ReadFastx->new(filename => "$fn1", format => 'fasta');
my $seq_data_2 = ReadFastx->new(filename => "$fn2", format => 'fastq') if (defined $fn2);
say color('cyan'), Dumper $seq_data_2;
say color('green'), $seq_data_2->get(), color('reset');