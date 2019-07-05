use 5.012;
use warnings;
use Carp qw(confess);
package Local::Module;
$Local::Module::VERSION = 2;


sub new {
    my ($class, $args) = @_;
    my $self = {
        debug   => $args->{debug}, 
    };
    my $object = bless $self, $class;

    confess "Unable to create fake object";
    return $object;
}

1;
