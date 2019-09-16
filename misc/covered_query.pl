#!/usr/bin/env perl

use 5.012;
use warnings;
use Bio::DB::Sam;
use Data::Dumper;

my $opt_sam = $ARGV[0];

my $sam = Bio::DB::Sam->new(-bam  =>"$opt_sam",
#                            -fasta=>"$opt_ref",
                            );


my $header = $sam->header;
my $target_names = $header->target_name;

my $covered;

for my $target ( @{ $target_names } ) {
 
	my @alignments = $sam->get_features_by_location(-seq_id => "$target");

	for my $a (@alignments) {
	 
	   my $start  = $a->start;
	   my $end    = $a->end;
	   my $strand = $a->strand;
	   my $cigar  = $a->cigar_str;
	   my $paired = $a->get_tag_values('PAIRED');
	 
	 
	   my $ref_dna   = $a->dna;        # reference sequence bases
	   for (my $i = $start; $i<=$end; $i++) {
		$covered->{$target}->{$i}++;
	   }
	}

}


for my $target (keys %{ $covered }) {
	#my $len = $sam->target_len($target);
	my $len = 49000;
	my $c = 0;
	my $t = 0;
	for my $pos (sort { $a <=> $b } keys %{ $covered->{$target} }) {
		$c++;
		$t += ${  $covered->{$target}  }{$pos};
	}
	my $f = $len ? sprintf("%.2f", $c*100/$len) : 'n/a';
	my $cov = $len ? sprintf("%.4f", $t / $len) :  '?';
	say "$opt_sam\t$target\t$c/$len\t$f%\t${cov}X";
}
