#!/usr/bin/env perl
#ABSTRACT - Check quality of merged paired ends

use 5.012;
use warnings;
use Getopt::Long;
use FASTX::Reader;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Local::Align qw(align);
use Data::Dumper;
use Term::ANSIColor;
use File::Basename;
use utf8;

my $opt_visualqual = 1;
binmode STDOUT, ":utf8";
my $usage=<<END;
   USAGE:
     compare_merge.pl -1 R1.fq [-2 R2.fq] Merged1.fq Merged2.fq ...

   Note: quality will be compared with the _first_ merged file

END

my ($opt_for, $opt_rev, $opt_debug, $opt_max_reads);

my $_opt = GetOptions(
	'm|max-reads=i'  => \$opt_max_reads,
	'1|forward=s'    => \$opt_for,
	'2|reverse=s'    => \$opt_rev,
	'd|debug'        => \$opt_debug,
);

if (not defined $opt_for and not defined $ARGV[0]) {
	say $usage;
	exit;
}

if (not defined $opt_rev) {
	$opt_rev = $opt_for;
	if ($opt_for=~/_R1/) {
		$opt_rev =~s/_R1/_R2/;
	} elsif ($opt_for=~/_1\./) {
		$opt_rev =~s/_1\./_2\./;
	}

	if ($opt_for eq $opt_rev) {
		die "Unable to automagically find reverse file, specify it via -2, --reverse\n";
	}
}
die " Unable to locate forward file <$opt_for>.\n" unless (-e "$opt_for");
die " Unable to locate reverse file <$opt_rev>.\n" unless (-e "$opt_rev");
say STDERR " * Loading $opt_for, $opt_rev" if ($opt_debug);
my $reads = get_paired_reads($opt_for, $opt_rev);

foreach my $f (@ARGV) {
	say STDERR " * Preloading $f" if ($opt_debug);
	add_read_names($reads, $f);
}

my %stats;
my $c = 0;
say STDERR "\r Done.\n";

foreach my $read (sort { $reads->{$a}->{id} <=> $reads->{$b}->{id} } keys %{ $reads }) {
	$c++;
	my $merged = 0;
	my $mergers = '';
	foreach my $f (@ARGV) {
		if (defined $reads->{$read}->{$f}) {
			$mergers .= basename($f).',';
			$merged++;
		}
	}
	$stats{'merged'}{$merged}++;

	my $rev = Local::Align->rc( $reads->{$read}->{R2}->{seq} );
	my $for = $reads->{$read}->{R1}->{seq};
	
	my ($top, $middle, $bottom, $score) = align($for, $rev);
	my $overlap = length($for) + length($rev) - length($top);
	my $fract   = sprintf("%.2f", $score/$overlap);

	say color('blue on_white'), qq($c:\@$read\tid=$reads->{$read}->{id}"), color('reset'), color('bold'),qq(\tmerged=$merged\tscore=$fract\t$mergers);

	my @names;
	my @qual;
	my @seqs;
	
	

	foreach my $f (@ARGV){

	  next if (!defined $reads->{$read}->{$f});
	  push(@names, basename($f));
	  push(@seqs,  $reads->{$read}->{$f}->{seq});
	  push(@qual, $reads->{$read}->{$f}->{qual});

	  #say color('yellow'), ">$f ";

 	  #my ($top1, $middle1, $bottom1, $score1) = align($for, $reads->{$read}->{$f}->{seq});
	  #my ($top2, $middle2, $bottom2, $score2) = align($reads->{$read}->{$f}->{seq}, $rev);
		# Top_ 		aligned R1
		# Bottom2_ 	aligned R2
	 # print join("\n", "> $top1", "  $middle1", "* $bottom1", "  $middle2", "< $bottom2", "\n") if ($fract > 0);

	}
	my $last_index = $#names;
	next if ($last_index < 1);

	#my ($top, $middle, $bottom, $score) = align($for, $rev);
	print join("\n", "   $top", "   $middle", "   $bottom",  "\n") if ($fract > 0);
	say color('green'), "   $seqs[0]";

	say color('cyan'), substr($names[0], 0, 2), ' ', $qual[0];
	for (my $i = 1; $i <= $last_index; $i++) {
		if ($seqs[0] ne $seqs[$i] and ($names[$i] ne 'R1.fq')) {
		  print "WARNING: $names[0] and $names[$i] are different:\n";
		  my ($top, $middle, $bottom, $score) = align($seqs[0], $seqs[$i]);
		  print join("\n", "$top", "$middle", "$bottom",  "\n") if ($fract > 0);
		} else {
		  print substr($names[$i], 0, 2), ' ';
		  for (my $c = 0; $c < length($qual[$i]); $c++) {
			my $char    = substr($qual[$i], $c, 1);
			my $topchar = substr($qual[0], $c, 1);
			my $color;
			if ($char eq $topchar) {
				$color = 'white on_black';

			} elsif (ord($char) > ord($topchar) ) {
				$color = 'black on_green';
			} else {
				$color = 'white on_red';
			}
			print color($color), "$char";
		  }
		  print "\n";
		}
		
	}
}

say Dumper \%stats;

sub get_paired_reads {
	my ($f, $r) =  @_;
	my %hash;
	my $reader = FASTX::Reader->new({ filename => "$f" });
	my $revder = FASTX::Reader->new({ filename => "$r" });
	my $counter = 0;
	while (my $read = $reader->getFastqRead()) {
		my $rev = $revder->getFastqRead();
		die "Sequence name mismatch in R1/R2: ", $read->{name}, ' != ', $rev->{name}, "\n" if ($read->{name} ne $rev->{name} );
		$counter++;
		$hash{ $read->{name} }{id} = $counter;
		
		$hash{ $read->{name} }{R1}->{seq} = $read->{seq};
		$hash{ $read->{name} }{R1}->{qual} = $read->{qual};
		$hash{ $read->{name} }{R2}->{seq} = $rev->{seq};
		$hash{ $read->{name} }{R2}->{qual} = $rev->{qual};
		
		last if (defined $opt_max_reads and $counter > $opt_max_reads);
	}
	say STDERR "$reader->{counter} reads in $f" if ($opt_debug);
	return \%hash;
}

sub add_read_names {
	my ($ref, $filename) = @_;
	my $reader = FASTX::Reader->new({ filename => "$filename" });
	while (my $read = $reader->getFastqRead()) {
		if ( defined $ref->{ $read->{name} } ) {
			$ref->{ $read->{name} }->{$filename}->{seq}  = $read->{seq};
			$ref->{ $read->{name} }->{$filename}->{qual} = $read->{qual};
		}	
	}
}




sub parse_qual {

	our %colors = (
	'reset'  => color('reset'),
	'red'    => color('reset').color('red'),
	'blue'   => color('reset').color('blue'),
	'green'  => color('reset').color('green'),
	'yellow' => color('reset').color('yellow'),

	'baseA'  => color('reset').color('green'),
	'baseC'  => color('reset').color('blue'),
	'baseG'  => color('reset').color('white'),
	'baseT'  => color('reset').color('red'),
	'baseN'  => color('reset').color('black on_blue'),

	'seqname'=> color('reset').color('bold white'),
	'comment'=> color('reset').color('yellow'),


	'opt_qual_verylow'     => color('reset').color('black on_red'),
	'opt_qual_low'         => color('reset').color('red'),
	'opt_qual_borderline'  => color('reset').color('yellow'),
	'qual_default'         => color('reset').color('green'),
	'opt_qual_good'        => color('reset').color('bold green'),
	);
	my $string = shift;
	my $average_quality;
	my @qualities = ();
	my $quality_string = '';

	my $len = length($string);

	for (my $i=0; $i < $len; $i++) {
		my $q = substr($string, $i, 1);
		my $Q = ord($q) - 33;
		$average_quality+=$Q;
		my $col = $colors{qual_default};

	our $opt_qual_verylow      = 19;
	our $opt_qual_low          = 26;
	our $opt_qual_borderline   = 30;
	our $opt_qual_good         = 35;
 		if ($Q <= $opt_qual_verylow) {
 			$col =  $colors{opt_qual_verylow};

 		} elsif ($Q < $opt_qual_low) {
 			$col = $colors{opt_qual_low};

 		} elsif ($Q < $opt_qual_borderline) {
			$col = $colors{opt_qual_borderline};
 		} elsif ($Q < $opt_qual_good) {
 			$col = $colors{qual_default}
 		} else {
			$col = $colors{opt_qual_good};
 		}


		push(@qualities, "$col$Q$colors{reset}");
        if ($opt_visualqual) {
          $q = char_to_ascii($q);
        }
        $quality_string .= "$col$q$colors{reset}";
	}

	if ($len) {
    	$average_quality/=$len;
    	return ($average_quality, $quality_string, \@qualities);
	}
}

sub char_to_ascii {
    my $char = $_[0];
    return 0 if length($char) > 1;
    $char =~ tr~!"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKL~▁▁▁▁▁▁▁▁▂▂▂▂▂▃▃▃▃▃▄▄▄▄▄▅▅▅▅▅▆▆▆▆▆▇▇▇▇▇██████~;
    return $char;
}
