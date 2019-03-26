use strict;
use warnings;
package Proch::Cmd;
$Proch::Cmd::VERSION = 0.001;
# ABSTRACT: Execute shell commands controlling inputs and outputs

use 5.014;
use Moose; 
use Data::Dumper;
use Carp qw(confess);

has debug => ( is => 'rw', isa => 'Bool');

has command => (
    is => 'ro',  
    required => 1, 
    isa => 'Str',
);

has logfile => (
	is => 'ro',
	isa => 'Str',
);


1;
