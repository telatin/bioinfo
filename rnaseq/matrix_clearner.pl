#!/usr/bin/env perl 

use v5.12;
use Getopt::Long;
use File::Basename;
my $opt_comment_char = '#';
my $opt_key = 'Geneid';
my $opt_separator = '_';
my $opt_field = 1;
my (
   $opt_input_file, 
   $opt_keep_comments,
   $opt_help,
);
my @opt_strip_strings = ();


my $opt = GetOptions(
	'i|input-file=s'    => \$opt_input_file,
	'k|keep-comments'   => \$opt_keep_comments,
	'c|comment-char=s'  => \$opt_comment_char,

	'f|field=i'         => \$opt_field,
	's|separator=s'     => \$opt_separator,

	'r|remove=s'        => \@opt_strip_strings,
	'help'              => \$opt_help
);

 
print_help() if ($opt_help or !defined($opt_input_file));
open my $fh, '<', $opt_input_file || die " FATAL ERROR:\n Unable to read <$opt_input_file>.\n";
$opt_field--;

while (my $line = readline($fh)) {
	chomp($line);
	my @fields = split /\s+/, $line;

	splice @fields, 1, 5;

	if ($line=~/^($opt_key)/) {
		my %counter = ();
		for (my $i = 1; $i <= $#fields; $i++) {
			
			$fields[$i] = strip_sample_name($fields[$i]);
			$counter{$fields[$i]}++;
			die " FATAL ERROR: Ambiguous names in columns after striping. ".
			"\n".
			" --field=",++$opt_field," --separator=$opt_separator\n".
			"\nEXAMPLE:\n", $fields[++$i], "\n"
				if ($counter{$fields[$i]} > 1);
		}
	} 

	if (substr($line, 0, 1) eq $opt_comment_char and !$opt_keep_comments) {
		next;
	}
	say join("\t", @fields);

}
sub strip_sample_name {
	my $string = shift @_;
	$string =~s/(\.fq|\.fastq|\.bam)//g;
	$string = basename($string);
	for my $remove_this (@opt_strip_strings) {
		$string =~s/$remove_this//g;
	}
	my @string_slices = split /$opt_separator/, $string;

	return $string_slices[$opt_field];
}
sub print_help {

  print STDERR <<END;
  -----------------------------------------------------------
  matrix_cleaner.pl -i INPUTFILE
  -----------------------------------------------------------

  A script to clean raw counts matrices for RNA Seq analyis
  for easier import in R.

  Input file is a matrix produced by featureCounts.

  The script: 
   - removes unwanted columns (keeps GeneID and counts)
   - strips .bam from header 
   - strips directory path from header

   - split header on _ and keeps field number 1
     (--field NUMBER --separator STRING to change) 

END

exit;

}