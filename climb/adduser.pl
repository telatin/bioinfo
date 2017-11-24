#!/usr/bin/perl

use strict;
our $prefix = 'bsb';
our $passwd = 'Quadram';

my $testsudo = 'ls /root';
`$testsudo 2>/dev/null`;

if ($?) {
	die "Please, sudo before\n";
}

my $listbsb = "ls /home/ | grep ". $prefix . ".. | sort";
my @users = `$listbsb`;

my $number = 0;
foreach my $user (@users) {
	chomp($user);
	$user =~/$prefix(\d+)/;
	$number = $1;
	if ($number < 1) {
		die " User '$user' has not a valid number ($number) after $prefix.\n".
		" Did you add it manually?\n";
	}
	print STDERR "User #$number '$user': FOUND\n";
	my $resetpasswd = qq(echo "$prefix$number:$passwd$number" | sudo chpasswd);
	`$resetpasswd`;
	if ($?) {
		die " Unable to reset password for $user:\n#$resetpasswd\n";
	} else {
		print STDERR "Resetting password:\n#$resetpasswd\n";
	}

	my $cmd = qq(usermod -a -G ubuntu $prefix$number && 
	chmod 775 /home/$prefix$number && 
	mkdir -p /home/$prefix$number/denovo && 
	chmod 777  /home/$prefix$number/denovo);
	run($cmd);
	run(qq(mkdir -p /mnt/galaxy/home/researcher/public_html/$prefix$number/ && 
	ln -s /mnt/galaxy/home/researcher/public_html/$prefix$number/ /home/$prefix$number/web/) )
	if (!-e "/home/$prefix$number/");
}

die "Nothing to do\n" if (!$ARGV[0]);

print STDERR "\n == CREATING NEW USER\n";
$number++;
$number = sprintf("%02d", $number);
print "$number\n";
my $p = $passwd . $number;
my $u = $prefix . $number;
my $command = qq(perl -e 'print "$p\n$p\n\n\n\n\n\n"' | adduser $u);
run($command);

sub run {
	my $command = shift @_;
	my $output = `$command`;
	if ($?) {
		die "Unable to perform action:\n#$command\n";
	}
	return $output;
}
