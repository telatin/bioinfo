package BioThing;
use Moo;
use MooX::Options;
use Data::Dumper;
use 5.014;
use Carp qw(confess);

# A first test of OOP with Moo

has name => (is => 'ro');
has command => (is => 'rw');
has code  => (
    is  => 'rw',
    isa => sub {
       confess "'$_[0]' is not an integer!"
          if $_[0] !~ /^\d+$/;
    },
);

sub run {
	my ($self, $o) = @_;
	say $o->{title} if (defined $o->{title});
	my $cmd = $self->command;
	my $output = `$cmd`;
	return $output;
}
1;