#!/usr/bin/env perl

# If a dependency is found in ScriptDir/tools/ that copy will be used!
my $dependencies = {
	'u10' => {
			binary => 'usearch_10',
			test   => 'usearch_10',
			check  => 'usearch v10',
			message=> 'Please, place USEARCH v10 binary named "usearch_10" in your path or in the /tools subdirectory of this script'
		},
	'seqkit' => {
			binary => 'seqkit',
			test   => 'seqkit stats --help',
			check  => 'output in machine-friendly tabular format',
		},

};

use v5.16;
use File::Basename;
use Getopt::Long;
use File::Spec;
use Data::Dumper; 

our $script_dir;
my  $opt_right_primerlen = 20;
my  $opt_left_primerlen = 20;
my  $opt_fortag = '_R1';
my  $opt_revtag = '_R2';
my  $opt_input_dir;
my  $opt_output_dir = './u16_output/';
my  $opt_debug;
my  $opt_verbose;
my  $opt_sample_size = 10000;


sub usage {
	say STDERR<<END;

 -----------------------------------------------------------------------
  micro16S pipeline
 -----------------------------------------------------------------------

   -i, --input-dir DIR
                   Input directory containing paired end FASTQ
                   files 

   --fortag STRING and  --revtag STRING
   				Separator indicating reads strand. Default _R1, _R2
 
   -o, --output-dir DIR
   				Output directory. Default: $opt_output_dir

 -----------------------------------------------------------------------   				
END
}
my $GetOptions = GetOptions(
	'i|input-dir=s'      => \$opt_input_dir,
	'o|output-dir=s'     => \$opt_output_dir,
	'd|debug'            => \$opt_debug,
	'v|verbose'          => \$opt_verbose,
	'fortag=s'           => \$opt_fortag,
	'revtag=s'           => \$opt_revtag,
	'trim-left=i'        => \$opt_left_primerlen,
	'trim-right=i'       => \$opt_right_primerlen,
);

our $dep = init($dependencies);
say Dumper $dep if ($opt_debug);

makedir($opt_output_dir);

opendir(DIR, $opt_input_dir) or die "FATAL ERROR: Couldn't open input directory <$opt_input_dir>.\n";
my %reads = ();

# Scan all the .fastq/.fq file in directory, eventually unzip them
# LOAD %reads{basename}{Strand}

while (my $filename = readdir(DIR) ) {
	if ($filename =~/^(.+?).gz$/) {
		run({
			'description' => "Decompressing <$filename>",
			'command'     => qq(gunzip "$opt_input_dir/$filename"),
			'can_fail'    => 0,
		});

	} elsif ($filename !~/q$/) {
		deb("Skipping $filename: not a FASTQ file");
		next;
	}

	my ($basename) = split /$opt_fortag|$opt_revtag/, $filename;
	my $strand = $opt_fortag;
	$strand = $opt_revtag if ($filename =~/$opt_revtag/);
	
	if (defined $reads{$basename}{$strand}) {
		die "FATAL ERROR: There is already a sample labelled <$basename> [$strand]!\n $reads{$basename}{$strand} is conflicting with $filename"
	} else {
		$reads{$basename}{$strand} = $filename;
	}
	say STDERR "Adding $basename ($strand)" if ($opt_debug);
}

# Check reads
ver("Input files:");
foreach my $b (sort keys %reads) {
	if (defined $reads{$b}{$opt_fortag} and defined $reads{$b}{$opt_revtag}) {
		say STDERR " - $b" if ($opt_verbose);
	} else {
		 
		die "FATAL ERROR: Sample '$b' is missing one of the pair ends: only $reads{$b}{$opt_fortag}$reads{$b}{$opt_revtag} found";
	}

	my $merged = "$opt_output_dir/${b}_merged.fastq";
	run({
		'command' => qq($dep->{u10}->{binary} -fastq_mergepairs "$opt_input_dir/$reads{$b}{$opt_fortag}" -fastqout "$merged" -relabel $b. > "$merged.log" 2>&1),
		'description' => qq(Joining pairs for $b),
	});
	
}

my $all_merged   = "$opt_output_dir/all_reads_raw.fastq";
my $all_stripped = "$opt_output_dir/all_reads_strp.fastq";
my $all_filtered = "$opt_output_dir/all_reads_filt.fasta";
my $all_unique   = "$opt_output_dir/all_reads_uniq.fasta";
my $all_otus     = "$opt_output_dir/OTUs.fasta";
my $all_zotus    = "$opt_output_dir/ASVs.fasta";
run({
	'command'     => qq(cat "$opt_output_dir"/*_merged.fastq > "$all_merged"),
	'description' => 'Combining all reads',
	'outfile'     => $all_merged,
});


# Strip primers (V4F is 19, V4R is 20)
run({
	'command' => qq($dep->{u10}->{binary} -fastx_truncate "$all_merged" -stripleft $opt_left_primerlen -stripright $opt_right_primerlen -fastqout "$all_stripped"),
	'description' => "Stripping primers ($opt_left_primerlen left, $opt_right_primerlen right)",
	'outfile'     => $all_stripped,
	'savelog'     => "$all_stripped.log",
});


# Quality filter
run({
	'command' => qq($dep->{u10}->{binary} -fastq_filter "$all_stripped" -fastq_maxee 1.0 -fastaout "$all_filtered" -relabel Filt),
	'description' => "Quality filter",
	'outfile'     => $all_filtered,
	'savelog'     => "$all_filtered.log",
});

# Find unique read sequences and abundances
run({
	'command' => qq($dep->{u10}->{binary}  -fastx_uniques "$all_filtered" -sizeout -relabel Uniq -fastaout "$all_unique"),
	'description' => "Quality filter",
	'outfile'     => $all_unique,
	'savelog'     => "$all_unique.log",
});



# Make 97% OTUs and filter chimeras
run({
	'command' => qq($dep->{u10}->{binary}  -cluster_otus "$all_unique" -otus "$all_otus" -relabel Otu),
	'description' => "Make 97% OTUs and filter chimeras",
	'outfile'     => "$all_otus",
	'savelog'     => "$all_otus.log",
});


# Denoise: predict biological sequences and filter chimeras
run({
	'command' => qq($dep->{u10}->{binary}  -unoise3 "$all_unique" -zotus "$all_zotus"),
	'description' => "Make 97% OTUs and filter chimeras",
	'outfile'     => $all_zotus,
	'savelog'     => "$all_zotus.log",
});

run({
	'command' => qq(sed -i 's/Zotu/OTU/' $all_zotus),
	'description' => "Renaming ASV OTUs",
	'outfile'     => $all_zotus,

});





for my $otus ($all_otus, $all_zotus) {
	my $tag = 'OTUs';
	$tag = 'ASVs' if ($otus =~/asv/i);
	
	my $otutabraw = qq("$opt_output_dir"/${tag}_tab.raw);
	my $otutab    = qq("$opt_output_dir"/${tag}_tab.txt);
	my $alpha     = qq("$opt_output_dir"/${tag}_alpha.txt);
	my $tree      = qq("$opt_output_dir"/${tag}.tree);
	my $beta_dir  = qq("$opt_output_dir"/${tag}_beta);
	# Make OTU table
	run({
		'command' => qq($dep->{u10}->{binary}   -otutab "$all_merged" -otus "$otus" -otutabout "$otutabraw"),
		'description' => "Make $tag table",
		'outfile'     => $otutabraw,
		'savelog'     => "$otutabraw.log",
	});


	# Normalize to 5k reads / sample
	run({
		'command' => qq($dep->{u10}->{binary}  -otutab_norm "$otutabraw" -sample_size $opt_sample_size -output "$otutab"),
		'description' => "Make $tag table",
		'outfile'     => $otutab,
		'savelog'     => "$otutab.log",
	});
	


	# Alpha diversity
	run({
		'command' => qq($dep->{u10}->{binary}  -alpha_div "$otutab" -output "$alpha"),
		'description' => "Alpha diversity",
		'outfile'     => $alpha,
		'savelog'     => "$alpha.log",
	});
 
	# Make OTU tree
	run({
		'command' => qq($dep->{u10}->{binary}  -cluster_agg "$otus" -treeout "$tree"),
		'description' => "Make OTU tree",
		'outfile'     => $tree,
		'savelog'     => "$tree.log",
	});

	# Beta diversity

	makedir("$beta_dir");
	run({
		'command' => qq($dep->{u10}->{binary}  -beta_div "$otutab" -tree "$tree" -filename_prefix "$beta_dir/"),
		'description' => "Beta diversity for $tag",
		'savelog'     => "$beta_dir/log.txt",
	});
	# # Rarefaction
	# $usearch -alpha_div_rare otutab.txt -output rare.txt

	# # Predict taxonomy
	# $usearch -sintax otus.fa -db ../data/rdp_16s_v16.fa -strand both \
 #  	-tabbedout sintax.txt -sintax_cutoff 0.8

	# # Taxonomy summary reports
	# $usearch -sintax_summary sintax.txt -otutabin otutab.txt -rank g -output genus_summary.txt
	# $usearch -sintax_summary sintax.txt -otutabin otutab.txt -rank p -output phylum_summary.txt

	# # Find OTUs that match mock sequences
	# $usearch -uparse_ref otus.fa -db ../data/mock_refseqs.fa -strand plus \
 #  	-uparseout uparse_ref.txt -threads 1
}

run({
	'command' => qq(gzip "$opt_output_dir"/all*.fast*),
	'description' => "Compress intermediate files",
});
sub run {
	my $run_ref = $_[0];
	my %output = ();

	if ($opt_debug) {
		say STDERR Dumper $run_ref;
	} elsif ($opt_verbose) {
		say STDERR " - $run_ref->{description}";
	}
	my $savelog;
	$savelog = qq( > "$run_ref->{savelog}" 2>&1 ) if (defined $run_ref->{savelog});

	my $output_text = `$run_ref->{command} $savelog`;

	# Check status (dont die if {can_fail} is set)
	if ($?) {
		deb(" - Execution failed: $?");
		if (! $run_ref->{can_fail}) {
			die " FATAL ERROR:\n Program failed and returned $?.\n Program: $run_ref->{description}\n Command: $run_ref->{command}";
		}
	}

	# Check output file
	if (defined $run_ref->{outfile}) {
		die "FATAL ERROR: Output file null ($run_ref->{outfile})" if (-z "$run_ref->{outfile}");
	}
}
sub init {
	my ($dep_ref) = @_;
	my $this_binary = $0;
	$script_dir = File::Spec->rel2abs(dirname($0));
	deb("Script_dir: $script_dir");
	if (! defined $opt_input_dir) {
		die "FATAL ERROR: Missing input directory (-i INPUT_DIR) with the FASTQ files\n";
	} elsif (! -d "$opt_input_dir") {
		die "FATAL ERROR: Input directory (-i INPUT_DIR) not found: <$opt_input_dir>\n";
	}

	
	foreach my $key ( keys %{ $dep_ref } ) {
		if (-e "$script_dir/tools/${ $dep_ref }{$key}->{binary}") {
			${ $dep_ref }{$key}->{binary} = "$script_dir/tools/${ $dep_ref }{$key}->{binary}";
		}
		my $cmd = qq(${ $dep_ref }{$key}->{"test"} |& grep "${ $dep_ref }{$key}->{"check"}");
		run({
			'command' => $cmd,
			'description' => qq(Checking dependency: <${ $dep_ref }{$key}->{"binary"}>),
			'can_fail'    => 0,
		});

		ver(" - ${$dep_ref}{$key}->{binary}");

	}

	return $dep_ref;
}
 

sub crash {
	die $_[0];
}
sub deb {
	say STDERR "$_[0]" if ($opt_debug);
}

sub ver {
	say STDERR "$_[0]" if ($opt_debug or $opt_verbose);	
}
sub makedir {
	my $dirname = shift @_;
	if (-d "$dirname") {
		say STDERR "Output directory found: $dirname" if $opt_debug;
	} else {
		my $check = run({
			'command'    => qq(mkdir -p "$dirname"),
			'can_fail'   => 0,
		});

	}
}
__END__
#!/bin/bash

if [ x$usearch == x ] ; then
	echo Must set \$usearch >> /dev/stderr
	exit 1
fi

rm -rf ../out
mkdir -p ../out
cd ../out

# Merge paired reads
# Add sample name to read label (-relabel option)
# Pool samples together in raw.fq (Linux cat command)
for Sample in Mock Soil Human Mouse
do
	$usearch -fastq_mergepairs ../data/${Sample}*_R1.fq \
	  -fastqout $Sample.merged.fq -relabel $Sample.
	cat $Sample.merged.fq >> all.merged.fq
done

# Strip primers (V4F is 19, V4R is 20)
$usearch -fastx_truncate all.merged.fq -stripleft 19 -stripright 20 \
  -fastqout stripped.fq

# Quality filter
$usearch -fastq_filter stripped.fq -fastq_maxee 1.0 \
  -fastaout filtered.fa -relabel Filt

# Find unique read sequences and abundances
$usearch -fastx_uniques filtered.fa -sizeout -relabel Uniq -fastaout uniques.fa

# Make 97% OTUs and filter chimeras
$usearch -cluster_otus uniques.fa -otus otus.fa -relabel Otu

# Denoise: predict biological sequences and filter chimeras
$usearch -unoise3 uniques.fa -zotus zotus.fa

##################################################
# Downstream analysis of OTU sequences & OTU table
# Can do this for both OTUs and ZOTUs, here do
# just OTUs to keep it simple.
##################################################


