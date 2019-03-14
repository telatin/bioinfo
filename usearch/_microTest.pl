#!/usr/bin/env perl

use v5.16;
use bioProch;
use File::Basename;
use Term::ANSIColor;
use Storable;
use Getopt::Long;
use File::Spec;
use Data::Dumper; 
$Data::Dumper::Terse = 1;
use Time::Piece;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep clock_gettime clock_getres clock_nanosleep utime);
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Storable qw(nstore store_fd nstore_fd freeze thaw dclone);

say "Testing";

our $settings = {
	debug => 1,
	no_color => 0,
	session => 'Testing_Session',
};

set_globals($settings);

auto_dump(\$settings);


if ($ARGV[0]) {
	my @aux = undef;
	my ($name, $seq, $comment);
	my $counter = 0;
	open I, "$ARGV[0]"|| die;
	while ( ($name,$comment, $seq ) = readfq2(\*I, \@aux)) {
		$counter++
	}
	say "$counter sequences parsed in <$ARGV[0]>";

	
	my ($name, $seq, $comment);
	my $counter = 0;
	open I, "$ARGV[0]"|| die;
	while ( ($name,$comment, $seq ) = readfq($ARGV[0])) {
		$counter++
	}
	my $counter = 0;
	say "$counter sequences parsed in <$ARGV[0]>";
	while ( ($name,$comment, $seq ) = readfq($ARGV[0])) {
		say $name;
		$counter++
	}
	say "$counter sequences parsed in <$ARGV[0]>";


} else {
	crash({
		message => 'You dindt provide a FASTA/Q file to parse, you moron',
		title   => 'MISSING ARGUMENT',
		#dumpvar => \$settings,
	});

}