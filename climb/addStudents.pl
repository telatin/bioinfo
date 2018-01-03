#!/usr/bin/perl
# A script to create multiple users in a server for teaching sessions

use strict;
our $prefix = 'climb.user';		#Username prefix (plus number)
our $passwd = 'PasswordForStudentx';	#User password (plus number)

our $HOMEPATH = '/home/';		# Where to store user directories
our $tutorialdir = 'tutorial';		# Writeable directory in each student home
# Check admin privileges
my $testsudo = 'ls /root';
`$testsudo 2>/dev/null`;
if ($?) {
	die "Please, sudo before\n";
}

# List home directories
my $listbsb = "ls $HOMEPATH | grep ". $prefix . ".. | sort";
my @users = `$listbsb`;

my $maxId = 0;

# CHECK CURRENT USERS (in the format $prefix$number
foreach my $user (@users) {
	chomp($user);
	$user =~/$prefix(\d+)/;
	my $number = $1;
	if ($number < 1) {
		die " User '$user' has not a valid number ($number) after $prefix.\n".
		" Did you add it manually?\n";
	}
	print STDERR "User #$number '$user': FOUND\n";
	
	# Perform routine tasks
	fix("$prefix$number", "$passwd$number");
	$maxId = $number if ($number > $maxId);
}

die "Nothing to do. Type as parameter the NUMBER of new users to create\n" if (!$ARGV[0]);

print STDERR "\n == CREATING NEW USERS\n";

$maxId++;
for (my $id = $maxId; $id <= ($maxId + $ARGV[0]); $id++) {
	my $number = sprintf("%03d", $number);
	print STDERR " Adding user \#$number\n";
	my $p = $passwd . $number;
	my $u = $prefix . $number;
	my $addUserCmd = qq(perl -e 'print "$p\n$p\n\n\n\n\n\n"' | adduser $u);
	run($addUserCmd);
	fix($u, $p);
}


sub fix {
	# perform routine tasks in a user directory
	my ($username, $password) = @_;
	
	# Reset the password, just in case...
	my $resetpasswd = qq(echo "$username:$password" | sudo chpasswd);
	run($resetpasswd);

	# Add username to group "ubuntu" and create writeable subdirectory in his home
        my $cmd = qq(usermod -a -G ubuntu $username &&
                chmod 775 $HOMEPATH/$username &&
                mkdir -p $HOMEPATH/$username/$tutorialdir &&
                chmod 777  $HOMEPATH/$username/$tutorialdir);

        run($cmd);

	# Create a directory in the public web folder and a link in the home (~/web)
        run(qq(mkdir -p /mnt/galaxy/home/researcher/public_html/$username/ &&
	        ln -s /mnt/galaxy/home/researcher/public_html/$username/ $HOMEPATH/$username/web/) )
        if (!-e "/home/$username/");

}


sub run {
	my $command = shift @_;
	my $output = `$command`;
	if ($?) {
		die "Unable to perform action:\n#$command\n";
	}
	return $output;
}
