package ReadFq;
$ReadFq::VERSION = '0.001';

# A simple module to parse FASTA and FASTQ files, based on 
# Heng Li subroutine https://github.com/lh3/readfq
# (this readfq implementation differs from the original as it's also retaining the sequence comment)

use 5.014;
use Digest::MD5::File;
use Moose; 
use Data::Dumper;

use Carp qw(confess);


# A first test of OOP with Moo
 
has filename => (
    is => 'ro',  
    required => 1, 
    isa => 'Str',
);

has debug => (
    is => 'ro',
);

 
 
has fh => (
    is => 'ro',
    builder => '_build_fh',
);

has aux => (
    is => 'ro',
    isa => 'ArrayRef',
    builder => '_build_aux',
);

sub _build_fh {
    my ($self) = @_;

    open my $fh, '<', $self->{filename} or confess("[ReadFq] Unable to read file: " . $self->{filename});
    return $fh;
}


sub _build_aux {
    my ($self) = @_; 
    my @aux = undef;

    return \@aux;
}

sub _get_filehandle {
    open our $filehandle, '<', $_[0];
    return $filehandle;
}



sub get {
    my ($self, $opt) = @_;
    say Dumper $self;
    my $seq = undef;
    my ($name, $comment, $sequence, $quality) = _Read_FastX_with_comments($self->{fh},  $self->{aux});
    $seq->{name} = $name;
    $seq->{comment} = $comment if (defined $comment);
    $seq->{seq} = $sequence;
    $seq->{qual} = $quality if (defined $quality);
    if (defined $name) {
        return $seq;
    } else {
        return;
    }
}


sub _Read_FastX_with_comments {
    my ( $fh, $aux ) = @_;
    @$aux = [ undef, 0 ] if ( !@$aux );
    return if ( $aux->[1] );
    if ( !defined( $aux->[0] ) ) {
        while ( readline($fh) )  {
            chomp;
            if ( substr( $_, 0, 1 ) eq '>' || substr( $_, 0, 1 ) eq '@' ) {
                $aux->[0] = $_;
                last;
            }
        }
        if ( !defined( $aux->[0] ) ) {
            $aux->[1] = 1;
            return;
        }
    }
    my ( $name, $comm ) =
        /^.(\S+)(?:\s+)(.+)/ ? ( $1, $2 )
      : /^.(\S+)/            ? ( $1, '' )
      :                        ( '', '' );
    my $seq = '';
    my $c;
    $aux->[0] = undef;
    while (<$fh>) {
        chomp;
        $c = substr( $_, 0, 1 );
        last if ( $c eq '>' || $c eq '@' || $c eq '+' );
        $seq .= $_;
    }
    $aux->[0] = $_;
    $aux->[1] = 1 if ( !defined( $aux->[0] ) );
    return ( $name, $comm, $seq ) if ( $c ne '+' );
    my $qual = '';
    while (<$fh>) {
        chomp;
        $qual .= $_;
        if ( length($qual) >= length($seq) ) {
            $aux->[0] = undef;
            return ( $name, $comm, $seq, $qual );
        }
    }
    $aux->[1] = 1;
    return ( $name, $seq );
}



 
1;