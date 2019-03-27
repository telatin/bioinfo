package ReadFastx;
$ReadFq::VERSION = '0.001';
 
use 5.014;
 
use Moose; 
use Data::Dumper;

use Carp qw(confess);


# A first test of OOP with Moo
 
has filename => (
    is => 'ro',  
    required => 1, 
    isa => 'Str',
);

has format => (
    is => 'ro',
    default => 'fastq',
    isa => 'Str',
);
 
 
has fh => (
    is => 'ro',
    isa => 'FileHandle',
    builder => '_build_fh',
);

 

sub _build_fh {
    my ($self) = @_;

    unless ( $self->{filename} ) {
        say 'Reading ', $self->{filename};
        say Dumper $self;
    }

    open my $fh, '<', $self->{filename} or confess("[ReadFq] Unable to read file: " . $self->{filename});
    return $fh;
}
 



sub get {
    my ($self, $opt) = @_;
    my $line = 'x';

    if ( ! defined $self->{fh} ) {
        say Dumper $self;
        return '|xxxx|';
    }

    $line = readline($self->{fh});
    chomp($line);
    return "|".$line . '|';
}


sub _read_fastq {

}

sub _read_fasta {

} 


 
1;