#!/usr/bin/env perl
use 5.018;
use JSON;
use LWP::Simple;
use Getopt::Long;
use Data::Dumper;
use Term::ANSIColor;

my ($opt_verbose, $opt_version, $opt_last);

my $parse_opt = GetOptions(
	'v|version=s' => \$opt_version,
	'verbose'     => \$opt_verbose,
	'l|last'      => \$opt_last,
);

my $module_name = shift(@ARGV);
my %status;

if (defined $module_name) {
	if ($module_name !~/::/) {
		print STDERR "[WARNING] Required argument module_name is not in the Module::Name format\n";
	}
	my $json = get_test_json($module_name);
	my $test = decode_json($json);
	foreach my $t (@{ $test }) {
	    next if (defined $opt_version and $t->{version} ne $opt_version);
	    $status{ $t->{version} }{ $t->{status} }++;
	}
	foreach my $version ( sort { $b <=> $a }  keys %status ) {
		foreach my $s ( sort keys %{ $status{$version} }) {
			my $color = 'yellow';
			$color = 'green' if ($s eq 'PASS');
			$color = 'red'   if ($s eq 'FAIL');		
			
			say STDERR color($color), "$module_name $version\t$s\t$status{$version}{$s}", color('reset');
		}
		my $pass = sprintf("%.2f", 100*$status{$version}{'PASS'}/($status{$version}{'PASS'}+$status{$version}{'FAIL'}));
		my $color = 'red';
		if ($pass > 90) {
			$color = 'green';
		} elsif ($pass > 80) {
			$color = 'orange';
		} 
		my $ver_string = $version;
		$ver_string=~s/\s/%20/g;
		my $ok = $status{$version}{'PASS'};
		say STDERR  color('cyan'), "Ver. $version -> $pass%", color('reset');
		print '[![Testing](https://img.shields.io/badge/', "Ver%20$ver_string-$pass%25-$color.svg)]\n";
		last if ($opt_last);
	}
} else {
	die "Required positional arugment: Module::Name\n";
}

sub get_test_json {
	my $base_uri = 'http://www.cpantesters.org/distro/';
	#http://www.cpantesters.org/distro/P/Proch-N50.json
	my ($mod) = @_;
	my $mod_dash = $mod;
	$mod_dash =~s/::/-/g;
	my $head_letter = uc(substr($mod, 0, 1));
	my $remote_uri = "${base_uri}${head_letter}/${mod_dash}.json";
	my $json = get($remote_uri);
	unless (defined $json) {
	    die "FATAL ERROR:\nUnable to retrieve remote URI <$remote_uri>.\n";
	}
	return $json;
}

# {
#          'guid' => '00020834-b19f-3f77-b713-d32bba55d77f',
#          'id' => '20834',
#          'osvers' => '2.8',
#          'distribution' => 'Test-More',
#          'osname' => 'openbsd',
#          'distversion' => 'Test-More-0.01',
#          'status' => 'PASS',
#          'platform' => 'sparc-openbsd',
#          'ostext' => 'OpenBSD',
#          'cssperl' => 'rel',
#          'version' => '0.01',
#          'fulldate' => '200104021536',
#          'dist' => 'Test-More',
#          'perl' => '5.6.0',
#          'state' => 'pass',
#          'csspatch' => 'unp'
#        };
