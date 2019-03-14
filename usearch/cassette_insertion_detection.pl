#!/usr/bin/env perl

# If a dependency is found in ScriptDir/tools/ that copy will be used!
my $dependencies = {
 
	'seqkit' => {
			binary => 'seqkit',
			test   => 'seqkit stats --help',
			check  => 'output in machine-friendly tabular format',
		},
	'samtools' => {
			binary => 'samtools',
			test   => 'samtools --version',
			check  => 'samtools 1.[3-9]',
			message => 'samtools 1.3--1.9 should be available',
	},
	'blastall' => {
			binary => 'blastall',
			test   => 'blastall',
			check  => 'blastall 2.2',
			message => 'blastall v2.2+ should be available',
	},
	'flash' => {
			binary => 'flash',
			test   => 'flash --help',
			check  => 'Usage: flash',
			message => 'flash should be available',
	},
	'bwa' => {
			binary => 'bwa',
			test   => 'bwa mem',
			check  => 'bwa',
			message => 'bwa should be available',
			ignore  => 1,
	},
};


use v5.16;
require bioProch;
use File::Basename;
use Term::ANSIColor;
#local $Term::ANSIColor::AUTORESET = 1;
use Storable;
use Getopt::Long;
use File::Spec;
use Data::Dumper; 
$Data::Dumper::Terse = 1;
use Time::Piece;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep clock_gettime clock_getres clock_nanosleep utime);
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Storable qw(nstore store_fd nstore_fd freeze thaw dclone);

our $script_dir;
 
my  $opt_contigs_file;
my  $opt_r1_file;
my  $opt_r2_file;
my  $opt_output_dir;
my  ($opt_reference, $opt_target);


my  $opt_min_overlap_ratio = 0.50;
my  $opt_min_overlap = 30;
my  $opt_max_overlap = 250;
my  $opt_scanning_wnd = 2000;

my  $opt_debug;
my  $opt_verbose;
my  $opt_rewrite = 0;
my  $opt_force_recalculate;
my  $opt_nocolor;

sub usage {
	say <<END;

 -----------------------------------------------------------------------
  Insertion Detection Pipeline
 -----------------------------------------------------------------------

   -1, --reads-1   FILE
   -2, --reads-2   FILE
            Input reads in FASTQ format, first and second pair

   -c, --contigs  FILE
            File with de novo assembly output contigs

   -r, --reference FILE
            File with hybrid reference

   -t, --target STRING
            Insertion cassette name in the reference

   -o, --output-dir DIR
            Output directory. Default: $opt_output_dir

   --repeat
            Force recalculation of all steps, even if cached


   --min-overlap INT
             Minimum overlap between paired ends in bp (def: $opt_min_overlap)

   --max-overlap INT
             Maximum overlap between paired ends in bp (def: $opt_max_overlap)

   --min-overlap-ratio FLOAT
             Minimum number of merged reads (def: $opt_min_overlap_ratio)      
 
 -----------------------------------------------------------------------   				
END
exit;
}
my $GetOptions = GetOptions(
	'c|contigs=s'        => \$opt_contigs_file,
	'1|reads-1=s'        => \$opt_r1_file,
	'2|reads-2=s'        => \$opt_r2_file,
	'o|output-dir=s'     => \$opt_output_dir,
	'r|reference=s'      => \$opt_reference,
	't|target=s'         => \$opt_target,
	'd|debug'            => \$opt_debug,
	'v|verbose'          => \$opt_verbose,
 
 	'min-overlap=i'      => \$opt_min_overlap,
 	'max-overlap=i'      => \$opt_max_overlap,
 	'min-overlap-ratio=f'=> \$opt_min_overlap_ratio,

	'rw'                 => \$opt_rewrite,
	'repeat'             => \$opt_force_recalculate,
	'nocolor'            => \$opt_nocolor,
);

our $dep = init($dependencies);
deb_dump($dep);

my $merge_file= qq($opt_output_dir/reads.extendedFrags.fastq);
my $ctg_stats = count_seqs($opt_contigs_file, {format => 'FASTA', N50 => 1, die_on_error => 1});
my $r1_stats  = count_seqs($opt_r1_file, {format => 'FASTQ', min_seqs => 10000, die_on_error => 1});
my $r2_stats  = count_seqs($opt_r2_file, {format => 'FASTQ', min_seqs => 10000, die_on_error => 1});
my $reference = count_seqs($opt_reference, {format => 'FASTA', min_seqs => 1, die_on_error => 1});
deb_dump($r1_stats);
deb_dump($r2_stats);
deb_dump($ctg_stats, 'with_N50');

run({
	command 	=> qq(grep '>$opt_target' "$opt_reference"),
	description => "Checking that target <$opt_target> is present in <$opt_reference>",
	nocache     => 1,
});

run({
	command   	=> qq($dep->{bwa}->{binary} index "$opt_reference"),
	description => "Indexing reference ($opt_reference) for bwa",
	skip_if     => "$opt_reference.bwt"
});

run({
	command   	=> qq($dep->{flash}->{binary} -m $opt_min_overlap -M $opt_max_overlap -o "$opt_output_dir"/reads "$opt_r1_file" "$opt_r2_file"),
	description => "Merging paired ends with FLASH",
	outfile     => $merge_file,
});
my $min_merge_seqs = $opt_min_overlap_ratio * $r1_stats->{seq_number};
my $merge_stats = count_seqs($merge_file, {format => 'FASTQ', min_seqs => $min_merge_seqs, die_on_error => 1});


ver(qq($merge_stats->{seq_number}/$r1_stats->{seq_number} sequenced merged));

run({
	command 	=> qq($dep->{bwa}->{binary} mem "$opt_reference" "$opt_r1_file" "$opt_r2_file" > "$opt_output_dir/mapping.sam"),
	description => "Aligning reads on reference",
	outfile     => "$opt_output_dir/mapping.sam",
});

open(my $sam, '<', "$opt_output_dir/mapping.sam") || crash("Unable to load SAM file: $opt_output_dir/mapping.sam");

my $mapping;
my $chromosomes;

while (my $line = readline($sam)) {
	chomp($line);
	my ($first_field, $flag, $target, undef, undef, $cigar, $ref, $pos) = split /\t/, $line;
	if ($first_field =~/^@/ ) {
		if ($line=~/^\@SQ\s+SN:(.+?)\s+LN:(\d+)/) {
			deb("Header length: $1 -> $2");
			$chromosomes->{$1} = $2;
		} 
		next;
	}
	$mapping->{_count_alignments}++;
	if ($target eq "$opt_target" and $ref ne "=") {
		$mapping->{_count_alignments_on_target}++;
		#In italia esiste il divieto di reformatio in peius, che rende le liti temerarie frequenti e soffoca il procedimento della giustizia affossandola di appelli pressoché automatici ad ogni sentenza.
		$mapping->{$ref}->{$pos}++;
	}
}

say STDERR "Total alignments:  ", $mapping->{_count_alignments};
say STDERR "Target alignments: ", $mapping->{_count_alignments_on_target};
for my $ref_chromosome (keys %{ $mapping }) {
	next if ($ref_chromosome =~/^_/);
	say STDERR "$ref_chromosome\t", $chromosomes->{$ref_chromosome};
	for my $pos (sort {$a <=> $b} keys %{ $mapping->{$ref_chromosome} } ) {
		say STDERR "\t$pos\t$mapping->{$ref_chromosome}->{$pos}";
	}
}
say ">>>";

for my $ref_chromosome (keys %{ $mapping }) {
	next if ($ref_chromosome =~/^_/);
	my $chr_len = $chromosomes->{$ref_chromosome};
	
	my @sorted = sort {$a <=> $b} keys %{ $mapping->{$ref_chromosome} };
	say "$ref_chromosome\t$chr_len [ $sorted[0] .. $sorted[-1] ]";
	for (my $start_pos = $sorted[0]; $start_pos <= $sorted[-1]; $start_pos++) {
		my $counter = 0;
		
		for (my $i = $start_pos; $i < ($start_pos + $opt_scanning_wnd); $i++) {
			$counter += $mapping->{$ref_chromosome}->{$i};
		}
		say ">$start_pos\t$counter" if ($counter);
	}

}

sub run {
	# Expects an object
	#     S command            the shell command
	#     S description        fancy description
	#     S outfile            die if outfile is empty / doesn't exist
	#     - nocache            dont load pre-calculated files even if found
	#     - keep_stderr        redirect stderr to stdout (default: to dev null)
	#     - no_redirect        dont redirect stderr (the command will do)
	#     S savelog            save STDERR to this file path
	#     - can_fail           dont die on exit status > 0
	#     - no_messages        suppress verbose messages: internal command
	#     S skip_if            skip if this file is found even if no cache (e.g. done outside this pipeline)

	my $start_time = [gettimeofday];
	my $start_date = localtime->strftime('%m/%d/%Y %H:%M');
	my $run_ref = $_[0];
	my %output = ();
	my $md5 = md5_hex("$run_ref->{command} . $run_ref->{description}");

	# Check a command was to be run
	unless ($run_ref->{command}){
		deb_dump($run_ref);
		die "No command received $run_ref->{description}\n";
	}

	# Caching
	$run_ref->{md5} = "$opt_output_dir/.$md5";
	$run_ref->{executed} = $start_date;

	if (-e  "$run_ref->{md5}"  and ! $opt_force_recalculate and !$run_ref->{nocache} ) {
		ver(" - Skipping $run_ref->{description}: output was cached before") unless ($run_ref->{no_messages});
		$run_ref = retrieve("$run_ref->{md5}");
		$run_ref->{loaded_from_cache} = 1;
		deb_dump($run_ref);

		return $run_ref;
	}
	$run_ref->{description} = substr($run_ref->{command}, 0, 12) . '...' if (! $run_ref->{description});
	

	if (defined $run_ref->{skip_if} and -s "$run_ref->{skip_if}") {
		ver(" - Skipping $run_ref->{description}: requested file found") unless ($run_ref->{no_messages});
		$run_ref->{skipped} = 1;
		return $run_ref;
	}
	# Save program output?
	my $savelog = ' 2> /dev/null ';

	$savelog = ' 2>&1  ' if ($run_ref->{keep_stderr});
	$savelog = '' if ($run_ref->{no_redirect});
	$savelog = qq( > "$run_ref->{savelog}" 2>&1 ) if (defined $run_ref->{savelog});




	#        ~~~~~~~~~~~~ EXECUTION ~~~~~~~~~~~~  
	#        ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	my $output_text = `$run_ref->{command} $savelog`;
	$run_ref->{output} = $output_text;
	$run_ref->{exitcode} = $?;

	# Check status (dont die if {can_fail} is set)
	if ($?) {
		deb(" - Execution failed: $?");
		if (! $run_ref->{can_fail}) {
			say STDERR color('red'), Dumper $run_ref, color('reset');

			die " FATAL ERROR:\n Program failed and returned $?.\n Program: $run_ref->{description}\n Command: $run_ref->{command}";
		} else {
			ver("Command failed, but it's tolerated [$run_ref->{description}]") unless ($run_ref->{no_messages});
		}
	}

	# Check output file
	if (defined $run_ref->{outfile}) {
		die "FATAL ERROR: Output file null ($run_ref->{outfile})" if (-z "$run_ref->{outfile}");
	}

	# Count SEQUENCES in selected output file
	if (defined $run_ref->{count_seqs}) {
		my $count = count_seqs($run_ref->{count_seqs});
		$run_ref->{tot_seqs} = $count->{seq_number};
		$run_ref->{tot_bp}   = $count->{sum_len};
		$run_ref->{seq_min_len}   = $count->{min_len};
		$run_ref->{seq_max_len}   = $count->{max_len};
		$run_ref->{seq_avg_len}   = $count->{avg_len};
		if (defined $run_ref->{min_seqs} and $count->{seq_number} < $run_ref->{min_seqs}) {
			deb("Test fails: min sequences ($run_ref->{min_seqs}) not met ($count->{seq_number} in $run_ref->{count_seqs})");
			die "FATAL ERROR: File <$run_ref->{count_seqs} has only $count->{seq_number} sequences, after executing $run_ref->{description}\n";
		}
	}
	
	my $elapsed_time = tv_interval ( $start_time, [gettimeofday]);
	$run_ref->{elapsed} = $elapsed_time;
	
	die "Unexpected error: no defined exitcode\n" unless defined $run_ref->{exitcode};
	
	if (! defined $run_ref->{nocache}) {
		deb("Caching result $run_ref->{elapsed}");
		nstore $run_ref, "$run_ref->{md5}" || die " FATAL ERROR:\n Unable to write log information to '$run_ref->{md5}'.\n";
	} 

	if ($opt_debug) {
		deb_dump($run_ref);
	} elsif ($opt_verbose) {
		ver(" - $run_ref->{description}") unless ($run_ref->{no_messages});;
	}
	ver("    Done ($elapsed_time s)", 'blue') unless ($run_ref->{no_messages});
	return $run_ref;
}
sub init {
	my ($dep_ref) = @_;
	my $this_binary = $0;
	$script_dir = File::Spec->rel2abs(dirname($0));
	deb("Script_dir: $script_dir");

	if (! defined $opt_output_dir) {
		die "FATAL ERROR: Missing output directory (-o)\n";
	}

	if (! -d "$opt_output_dir") {
		makedir("$opt_output_dir");
	}
	if (! defined $opt_r1_file) {
		die "FATAL ERROR: Missing input FASTQ files (-1 and possibly -2)\n";
	} 
	if (! defined $opt_r2_file) {
		$opt_r2_file = $opt_r1_file;
		$opt_r2_file =~s/_R1/_R2/;
	}

	if (! -e "$opt_r1_file" or ! -e "$opt_r2_file") {
		die "FATAL ERROR:  Unable to find input FASTQ files (-1 and -2): $opt_r1_file or $opt_r2_file\n";
	}

	
	foreach my $key ( keys %{ $dep_ref } ) {
		if (-e "$script_dir/tools/${ $dep_ref }{$key}->{binary}") {
			${ $dep_ref }{$key}->{binary} = "$script_dir/tools/${ $dep_ref }{$key}->{binary}";
		}
		
		
		my $check = run({
			'command'     => qq(${ $dep_ref}{$key}->{test} 2>&1),
			'description' => qq(Checking dependency: <${ $dep_ref }{$key}->{"binary"}>),
			'can_fail'    => 1,
			'nocache'     => 1,
		});

		if ($check->{output} !~/$dep_ref->{$key}->{check}/ and ! defined ${$dep_ref}{$key}->{ignore}) {
			die "FATAL ERROR: \n Unable to find dependency <$key>\n";
		}

	}

	return $dep_ref;
}
 

sub crash {
	my ($error, $options) = @_;
	die $error;
}

sub deb_dump {
	my $ref = shift @_;
	unless ($opt_nocolor) {
		print STDERR color('cyan'), "";
	}
	say STDERR Dumper $ref if ($opt_debug);
	unless ($opt_nocolor) {
		print STDERR color('reset'), "";
	}	
}
sub deb {
	my ($message, $color) = @_;
	$color = 'cyan' unless ($color);
	unless ($opt_nocolor) {
		print STDERR color($color), "";
	}
	say STDERR ":: $message" if ($opt_debug);
	unless ($opt_nocolor) {
		print STDERR color('reset'), "";
	}
}

sub ver {
	my ($message, $color) = @_;
	$color = 'reset' unless ($color);
	unless ($opt_nocolor) {
		print STDERR color($color), "";
	}
	say STDERR "$message" if ($opt_debug or $opt_verbose);	

	unless ($opt_nocolor) {
		print STDERR color('reset'), "";
	}
}

sub count_seqs {
	my ($filename, $options) = @_;
	my $all = '';
	$all = ' --all ' if (defined $options->{N50});

	my $output;
	$output->{error} = '';

	if ( ! -e "$filename" ) {
		$output->{success} = 0;
		$output->{error} = "[count_reads] Unable to locate FASTA/FASTQ file <$filename>";
	} else {
		#0       1       2       3               4       5       6       7       8       9       10      11      12
		#file    format  type    num_seqs        sum_len min_len avg_len max_len
		#file    format  type    num_seqs        sum_len min_len avg_len max_len Q1      Q2      Q3      sum_gap N50     Q20(%)  Q30(%)
		my $file_stats = run({
			command 	=> qq(seqkit stats $all --tabular "$filename" | tail -n 1),
			description => "Counting sequence number of $filename with 'seqkit'",
			can_fail    => 0,
			no_messages => 1,
		});
		$output->{success} = 1;
		#$output->{cmd} = $file_stats;
		my @fields = split /\s+/, $file_stats->{output};

		$output->{format}     = $fields[1];
		$output->{seq_number} = $fields[3];
		$output->{sum_len}    = $fields[4];
		$output->{min_len}    = $fields[5];
		$output->{avg_len}    = $fields[6];
		$output->{max_len}    = $fields[7];
		if (defined $options->{N50}) {
			$output->{sum_gap} = $fields[11];
			$output->{N50} = $fields[12]; 
		}

		if (defined $options->{min_seqs} and $output->{seq_number} < $options->{min_seqs}) {
			$output->{success} = 0,
			$output->{error} = "Not enough sequences: $options->{min_seqs} requested, $output->{seq_number} found\n",
		}

		if (defined $options->{format} and $options->{format} ne $output->{format}) {
			$output->{success} = 0,
			$output->{error}   .= "Wrong format detected ($options->{format} was expected)\n"
		}

	}

	if (defined $options->{die_on_error} and $output->{success} == 0) {
		deb_dump($output);
		crash("When analyzing <$filename> errors occurred:\n$output->{error}");
	}

	return $output;
}
sub makedir {
	my $dirname = shift @_;
	if (-d "$dirname") {
		if ($opt_rewrite) {
			run({
				command     => qq(rm -rf "$dirname/*"),
				description => "Erasing directory (!): $dirname",
			});
		}
		say STDERR "Output directory found: $dirname" if $opt_debug;
	} else {
		my $check = run({
			'command'     => qq(mkdir -p "$dirname"),
			'can_fail'    => 0,
			'description' => "Creating directory <$dirname>",
			'no_messages' => 1,
		});

	}
}
__END__
 