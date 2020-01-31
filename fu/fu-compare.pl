#!/usr/bin/env perl 

use 5.012;
use warnings;
use Getopt::Long;
use FindBin qw($RealBin);
if (-d "$RealBin/lib/FASTX/Reader.pm") {
	use lib "$RealBin/lib";
}
use FASTX::Reader;
use File::Basename;
use Data::Dumper;
sub loadseqs($);
my $BASENAME = basename($0);


my ($file1, $file2) = @ARGV;

usage() unless (defined $file2);

my %s1 = loadseqs "$file1";
my %s2 = loadseqs "$file2";


for my $seq1 (keys %s1) {
	my $matches = 0;
	for my $seq2 (keys %s2) {
		if ($seq1 =~/$seq2/) {
			$matches++;
			say "$s1{$seq1}\t$s2{$seq2}\tOK";
		} elsif ($seq2 =~/$seq1/) {
			$matches++;
			say "$s2{$seq2}\t$s1{$seq1}\tOK";
		} 
	}
	say "$s1{$seq1}\t..\tKO" unless ($matches);
}
sub loadseqs($) {
	my ($filename) = @_;
	my %seqs = ();
	my $READER = FASTX::Reader->new({ filename => "$filename" });
	while (my $s = $READER->getRead() ) {
		$seqs{ $s->{seq} } = $s->{name};
	}
	return %seqs;
}

sub usage {
	say<<END;
 $BASENAME File1.fa File2.fa

END
 exit;
}