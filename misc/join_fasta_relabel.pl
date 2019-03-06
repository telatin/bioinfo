#!/usr/bin/env perl -w

# A script to join multiple fasta files in a single one, prepending to each sequence
# name a prefix based on the filename. Some options to customize it are provided:
#  --basename to strip the relative/absolute path provided to the program
#  --split to keep the first part of the filename before a string (e.g. "_")
#  --joinpathchar to substitute the "/" in the path with a different char

use v5.16;
use Getopt::Long;
use Data::Dumper;
use File::Basename;
our $VERSION = '0.10';


my $opt_prefix_separator = '.';
my $opt_split = '.';
my (
		$opt_slash,
		$opt_basename,
		$opt_verbose,
		$opt_help,
);
my @opt_enzymes = ();

my $GetOptions = GetOptions(
 	'b|basename'      => \$opt_basename,
 	'c|joinpathchar=s'  => \$opt_slash,
 	'p|prefixseparator' => \$opt_prefix_separator,
 	's|split=s'         => \$opt_split,
	'v|verbose'         => \$opt_verbose,
	'h|help'            => \$opt_help,
);


for my $opt_input_file (@ARGV) {
	my @aux = undef;
	my ($name, $seq, $comment);
	
	my $input_basename = basename($opt_input_file);
	say STDERR "Opening <$input_basename>..." if ($opt_verbose);
	open I, '<', "$opt_input_file" || die "FATAL ERROR: Unable to reads <$opt_input_file>.\n";

	my $prefix = $opt_input_file;
	if ($opt_basename) {
		$prefix = $input_basename;
	}
	$prefix =~s|/|$opt_slash|g if ($opt_slash and !$opt_basename);

	if (length($opt_split)) {
		my @splits = split /$opt_split/, $prefix;
		$prefix = $splits[0] if (length $splits[0]);
		
	}

	while ( ($name,$comment, $seq ) = readfq(\*I, \@aux)) {
		say ">${prefix}${opt_prefix_separator}${name} ${comment}";
		say $seq;

	}	
	close I;
}



sub usage {
	my $line = '-' x 60;
	say STDERR<<END;

    JOIN FASTA RELABEL v. $VERSION
    ${line}

    -b, --basename
         Use the file name and not the user supplied path to it

    -s, --split STRING [default: .]
    	 Use as prefix the first part of the string before the
    	 supplied string 

    -p, --prefixseparator STRING [default: .]
         Separate prefix and sequence name with this string

    -c, --joinpathchar CHAR 
    	 If not using 'basename', then substitute the "/" of paths
    	 with a different character


    This program joins a set of FASTA file prepending their filename
    at the beginning of the sequence name

END
	exit;
}
 
sub readfq {
    my ($fh, $aux) = @_;
    @$aux = [undef, 0] if (!@$aux);
    return if ($aux->[1]);
    if (!defined($aux->[0])) {
        while (<$fh>) {
            chomp;
            if (substr($_, 0, 1) eq '>' || substr($_, 0, 1) eq '@') {
                $aux->[0] = $_;
                last;
            }
        }
        if (!defined($aux->[0])) {
            $aux->[1] = 1;
            return;
        }
    }
    my ($name, $comm) = /^.(\S+)(?:\s+)(.+)/ ? ($1, $2) : 
                        /^.(\S+)/ ? ($1, '') : ('', '');
    my $seq = '';
    my $c;
    $aux->[0] = undef;
    while (<$fh>) {
        chomp;
        $c = substr($_, 0, 1);
        last if ($c eq '>' || $c eq '@' || $c eq '+');
        $seq .= $_;
    }
    $aux->[0] = $_;
    $aux->[1] = 1 if (!defined($aux->[0]));
    return ($name, $comm, $seq) if ($c ne '+');
    my $qual = '';
    while (<$fh>) {
        chomp;
        $qual .= $_;
        if (length($qual) >= length($seq)) {
            $aux->[0] = undef;
            return ($name, $comm, $seq, $qual);
        }
    }
    $aux->[1] = 1;
    return ($name, $seq);
}

 
