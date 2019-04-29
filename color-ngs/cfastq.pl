#!/usr/bin/env perl
use v5.14;
use Pod::Usage;
use Getopt::Long;
use File::Basename;
use Term::ANSIColor;
use utf8;
our $THIS_SCRIPT_NAME = basename($0);
use sigtrap 'handler' => \&sig_handler, qw(INT TERM KILL QUIT);

sub sig_handler {
   my $sig_name = shift;
   print color('reset');
   exit;
}



our $THIS_SCRIPT_VERSION = 1.00;
our $THIS_SCRIPT_AUTHOR  = 'Andrea Telatin <andrea@telatin.com>';

our ($opt_debug, $opt_visualqual, $opt_help, $opt_qual_scale,$opt_verbose, $opt_nocolor, $opt_nocolor_seq, $opt_nocolor_qual,$opt_quality_numbers);
our $opt_qual_verylow      = 10;
our $opt_qual_low          = 22;
our $opt_qual_borderline   = 30;
our $opt_qual_good         = 39;

my $result = GetOptions(
	'd|debug'             => \$opt_debug,
	'v|verbose'           => \$opt_verbose,
	'h|help'              => \$opt_help,
	'n|quality_numbers'   => \$opt_quality_numbers,
	'nc|nocolor'          => \$opt_nocolor,
	'ns|nocolorseq'       => \$opt_nocolor_seq,
	'nq|nocolorqual'      => \$opt_nocolor_qual,
  'vq|visualqual'       => \$opt_visualqual,

	's|qual_scale=s'      => \$opt_qual_scale,
	'l|qual_verylow=f'    => \$opt_qual_verylow,
	'm|qual_low=f'        => \$opt_qual_low,
	'b|qual_borderline=f' => \$opt_qual_borderline,
	'g|qual_good_above=f' => \$opt_qual_good,
);

if (defined $opt_qual_scale) {
	my @qual_scale = split /,/, $opt_qual_scale;
	if ($qual_scale[3]) {
		($opt_qual_verylow, $opt_qual_low, $opt_qual_borderline, $opt_qual_good)
		 = @qual_scale;

	} else {
		die " ERROR: -s, --qual_scale INT,INT,INT,INT: you provided $opt_qual_scale\n";
	}
}

pod2usage({
	-exitval => 0,
	-verbose => 2}) if $opt_help;

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
if ($opt_visualqual) {
  binmode STDOUT, ":utf8";
}
if ($opt_nocolor) {
	foreach my $key (keys %colors) {
		$colors{$key} = '';
	}
}

# ARGV is a list of files. '-' will be intended as STDIN

if ($opt_debug) {
	my $keep_opt = $opt_quality_numbers;

	print "QUALITY: ", colorqual(q(!"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~))."\n";

	print "QUALITY: ", colorqual(q(!"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~))."\n";
	$opt_quality_numbers = $keep_opt;

}
push(@ARGV, '-') if (!defined$ARGV[0]);
foreach my $file (@ARGV) {

	print STDERR "# Reading: $file\n" if ($opt_verbose);
	if ($file ne '-') {
		die " FATAL ERROR: {$file} is not an existing file\n" if (!-e "$file");
		open STDIN, '<', "$file" || die " FATAL ERROR:\n Unable to read <$file>: $!\n";
	}
	my @aux = undef;
	while (my ($name, $seq, $comment, $quality) = readfq(\*STDIN, \@aux)) {

		my $color_seq = $seq;
		my $color_qual = $quality;

		$color_seq = colorseq($seq) unless ($opt_nocolor_seq);
		$color_qual = colorqual($quality) unless ($opt_nocolor_qual);

		if ($quality) {
			my ($average_quality, $qualities_ref) = parse_qual($quality);
			print "$colors{blue}\@";
			print "$colors{seqname}$name $colors{comment}$comment$colors{reset}\n";

			print $color_seq."\n";
			print "$colors{reset}$colors{blue}+$colors{reset}\n";
			print $color_qual."\n";
		} else {
			print "$colors{blue}\>";
			print "$colors{seqname}$name $colors{comment}$comment\n";
			print $color_seq."\n";
		}
    }

}
print color('reset') unless ($opt_nocolor);

sub colorqual {

	my $qual = shift;

	my ($avg, $qual_string, $arr) = parse_qual($qual);

	if ($opt_quality_numbers) {
		return join(',', @{$arr});
	} else {
		return $qual_string;
	}

}
sub colorseq{
	my $string = shift;
	my $output;
	for (my $i = 0; $i <= length($string); $i++) {
		my $c = substr($string, $i, 1);

		if ('A' eq uc($c)) {
			$output .= $colors{'baseA'}.$c;
		} elsif  ('C' eq uc($c)) {
			$output .= $colors{'baseC'}.$c;
		} elsif  ('G' eq uc($c)) {
			$output .= $colors{'baseG'}.$c;
		} elsif  ('T' eq uc($c)) {
			$output .= $colors{'baseT'}.$c;
		} elsif  ('N' eq uc($c)) {
			$output .= $colors{'baseN'}.$c;
		} else {
			$output .= $c;
		}

	}
	return $output;
}
sub parse_qual {
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

#our $opt_qual_verylow      = 19;
#our $opt_qual_low          = 26;
#our $opt_qual_borderline   = 30;
#our $opt_qual_good         = 35;
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


sub readfq {
    my ($fh, $aux) = @_;
    @$aux = [undef, 0] if (!(@$aux));
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
    my $name = /^.(\S+)/? $1 : '';
    my $comm = /^.\S+\s+(.*)/? $1 : '';
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
    return ($name, $seq) if ($c ne '+');
    my $qual = '';
    while (<$fh>) {
        chomp;
        $qual .= $_;
        if (length($qual) >= length($seq)) {
            $aux->[0] = undef;
            return ($name, $seq, $comm, $qual);
        }
    }
    $aux->[1] = 1;
    return ($name, $seq, $comm);
}
