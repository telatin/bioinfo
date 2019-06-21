#!/usr/bin/env perl

use 5.012;
use warnings;
use Getopt::Long;
use File::Basename;
use Carp qw(confess);

my $has_reader = eval {
	require FASTX::Reader;
	FASTX::Reader->import();
	1;
};
my $this_script_name = basename($0);

my $opt_bin_dir = dirname($0);
my $opt_output;
my $opt_bash;
my $opt_debug;
my $opt_force;
my $opt_R1 = '_R1';
my $opt_R2 = '_R2';
my $opt_ext = '.fq';

my $_opt = GetOptions(
	'o|out=s'     => \$opt_output,
	'b|bindir=s'  => \$opt_bin_dir,
	'sh'          => \$opt_bash,
	'd|debug'     => \$opt_debug,
	'f|force'     => \$opt_force,
) || usage("Unrecognized parameters/syntax error");

if ($opt_bash or not $has_reader) {
	make_bash_scripts() || confess("Script execution requires bash scripts that were not found and couldn't be regenerated in $opt_bin_dir");
} elsif (not $has_reader) {
	debug('Setting [bash] processor: FASTX::Reader not found');
	$opt_bash = 1;
}

if (not $opt_bash) {
	debug('Setting [FASTX::Reader] processor');
}

if (defined $ARGV[1]) {
	# Probable INTERLEAVE mode

	# Check Input
	if ( (not -e "$ARGV[0]") or (not -e "$ARGV[1]") ) {
		usage();
		die "FATAL ERROR [INPUT]:\nInterleaving failed as R1:<$ARGV[0]> or R2:<$ARGV[1]> were not found\n";
	}

	# Check output: full name
	if (defined $opt_output) {
		if (-e "$opt_output" and not "$opt_force") {
			die "FATAL ERROR:\nOutput file <$opt_output> was found. Use -f,--force to overwrite\n";
		}
	} else {

	}

} elsif (defined $ARGV[0]) {
	# Probable DEINTERLEAVE mode

	# Check Input
	if ( (not -e "$ARGV[1]") ) {
		usage();
		die "FATAL ERROR [INPUT]:\nInterleaving failed as interleaved fastq file <$ARGV[0]> was not found\n";
	}

	# Check output (basename)
	if (defined $opt_output) {
		if (-e "$opt_output" and not "$opt_force") {
			die "FATAL ERROR:\nOutput file <$opt_output> was found. Use -f,--force to overwrite\n";
		}	
	} else {

	}

} else {
	# Not enough arguments / Too many args
	usage();
}

sub usage {
say STDERR<<END;
	To interleave:
		$this_script_name [options] -o output.fq File_R1.fq File_R2.fq

	To deinterleave:
		$this_script_name [options] -o output_prefix File.fq


	Use --help for full documentation.
END

	if ($_[0]) {
		print STDERR "[FATAL ERROR]\n";
		die($_[0]);
	}

}

sub make_bash_scripts {
	my $out = undef;
	my $script = undef;


	while (my $line = <DATA>) {
		chomp($line);
		if ($line =~/^##(.+)/) {
			$script = $1;
			if (-e "$opt_bin_dir/$script") {
				debug("$script found. Skipping re-generation.");
			} else {
				debug("Preparing <$opt_bin_dir/$script> file");
				open $out, '>', "$opt_bin_dir/$script" || confess("Unable to write file <$opt_bin_dir/$script>. You can supply a different writeable directory with -b,--bindir");
			}
			
		} else {
			say ${out} "$line";
		}

	}

	if (-e "$opt_bin_dir/interleave.sh" and -e "$opt_bin_dir/deinterleave.sh") {
		return 1;
	} else {
		debug("$opt_bin_dir/interleave.sh or $opt_bin_dir/deinterleave.sh were not created");
		return 0;
	}
}

sub debug {
	if ($opt_debug) {
		say STDERR "[debug] $_[0]";
	}
}

=pod

=head1 NAME

interleave.pl - A program to interleave and deinterleave FASTQ files

=head1 USAGE

To interleave:
  interleave.pl [options] -o output.fq File_R1.fq File_R2.fq

To deinterleave:
  interleave.pl$this_script_name [options] -o output_prefix File.fq

=head1 OPTIONS

=over 4

=back

=head1 AUTHOR / BUGS / LICENCE

This is a free software developed by Andrea Telatin (andrea^telatin.com) and released
with the same licence as Perl5. Report bugs to the author.

=cut

__DATA__
##deinterleave.sh
#!/bin/bash
# Usage: deinterleave_fastq.sh < interleaved.fastq f.fastq r.fastq [compress]
# 
# Deinterleaves a FASTQ file of paired reads into two FASTQ
# files specified on the command line. Optionally GZip compresses the output
# FASTQ files using pigz if the 3rd command line argument is the word "compress"
# 
# Can deinterleave 100 million paired reads (200 million total
# reads; a 43Gbyte file), in memory (/dev/shm), in 4m15s (255s)
# 
# Latest code: https://gist.github.com/3521724
# Also see my interleaving script: https://gist.github.com/4544979
# 
# Inspired by Torsten Seemann's blog post:
# http://thegenomefactory.blogspot.com.au/2012/05/cool-use-of-unix-paste-with-ngs.html

# Set up some defaults
GZIP_OUTPUT=0
PIGZ_COMPRESSION_THREADS=10

# If the third argument is the word "compress" then we'll compress the output using pigz
if [[ $3 == "compress" ]]; then
  GZIP_OUTPUT=1
fi

if [[ ${GZIP_OUTPUT} == 0 ]]; then
  paste - - - - - - - -  | tee >(cut -f 1-4 | tr "\t" "\n" > $1) | cut -f 5-8 | tr "\t" "\n" > $2
else
  paste - - - - - - - -  | tee >(cut -f 1-4 | tr "\t" "\n" | pigz --best --processes ${PIGZ_COMPRESSION_THREADS} > $1) | cut -f 5-8 | tr "\t" "\n" | pigz --best --processes ${PIGZ_COMPRESSION_THREADS} > $2
fi

##interleave.sh
#!/bin/bash
# Usage: interleave_fastq.sh f.fastq r.fastq > interleaved.fastq
# 
# Interleaves the reads of two FASTQ files specified on the
# command line and outputs a single FASTQ file of STDOUT.
# 
# Can interleave 100 million paired reads (200 million total
# reads; a 2 x 22Gbyte files), in memory (/dev/shm), in 6m54s (414s)
# 
# Latest code: https://gist.github.com/4544979
# Also see my deinterleaving script: https://gist.github.com/3521724

paste $1 $2 | paste - - - - | awk -v OFS="\n" -v FS="\t" '{print($1,$3,$5,$7,$2,$4,$6,$8)}'