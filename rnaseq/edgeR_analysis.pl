#!/usr/bin/env perl
use v5.16; 
use Getopt::Long;
use File::Basename;
use Term::ANSIColor  qw(:constants);
use Data::Dumper;
use Cwd 'abs_path';
our $r_script = '
# edgeR analysis for {{TableFile}}
# condition: {{ConditionName}}
library("edgeR")

RawTable <- read.delim("{{TableFile}}",row.names="{{GeneKey}}")

colnames(RawTable) <- c({{SampleLabels}})
GroupVector <- factor(c({{ConditionsList}}))
ColorVector <-  c({{ColorsList}})
EdgeRObject <- DGEList(counts=RawTable,group=GroupVector)
EdgeRObject <- calcNormFactors(EdgeRObject)
DesignObject <- model.matrix(~GroupVector)
EdgeRObject <- estimateDisp(EdgeRObject, DesignObject)

Fit  <- glmQLFit(EdgeRObject, DesignObject)
Qlf  <- glmQLFTest(Fit, coef=2)
Tags <- topTags(Qlf, n=100)

pdf("{{Output_File}}.mds.pdf")
plotMDS(EdgeRObject, col=ColorVector)
dev.off()

write.table(Tags, file="{{Output_File}}.toptags.txt", row.names=TRUE, col.names=TRUE)
write.table(EdgeRObject$samples, file="{{Output_File}}.norm_factors.txt", row.names=TRUE, col.names=TRUE)
';

our %color_name = (
	'1'   => '"blue"',
	'2'   => '"red"',
	'3'   => '"green"',
	'4'   => '"darkcyan"',
);
local $Term::ANSIColor::AUTORESET = 1;
my $opt_sample_description_title = 'SampleName';
my (
		$opt_table_file,
		$opt_metadata_file,
		$opt_debug,
		$opt_debug_sub,
		$opt_outdir,
);

my $opt = GetOptions(
	't|table-file=s'	=> \$opt_table_file,
	'm|metadata-file=s' => \$opt_metadata_file,
	'v|verbose'         => \$opt_debug,
	'd|debug'           => \$opt_debug_sub,
	'o|outdir=s'        => \$opt_outdir,
);


check_R_or_die();

die " FATAL ERROR:\n Missing output directory (-o, --outdir)\n" unless (defined $opt_outdir);
die " FATAL ERROR:\n Missing metadata TSV file (-m, --metadata-files)\n" unless (defined $opt_metadata_file);
die " FATAL ERROR:\n Missing table of counts, matrix (-t, --table-files)\n" unless (defined $opt_table_file);

if (-d "$opt_outdir") {
	say STDERR "Output directory found: $opt_outdir" if ($opt_debug);
} else {
	`mkdir -p "$opt_outdir"`;
	if ($?) {
		die " FATAL ERROR:\n Unable to create output directory $opt_outdir ($?)\n";
	} else {
		say STDERR "Output directory not found, created ($?): $opt_outdir\n";
	}
}

`cp "$opt_metadata_file" "$opt_outdir"`;
`cp "$opt_table_file" "$opt_outdir"`;
die " FATAL ERROR\n Unable to copy $opt_table_file into $opt_outdir\n" if ($?);

my ($metadata_ref, $header_ref ) = parse_metadata($opt_metadata_file);
	#metadata_ref 		-> hash{SampleID}->{Condition}
	#header_ref			array of columns like SampleName Condition1 Condition2
	#conditions_ref		hash{condition_name} = @conditions

my $metadata_samples = keys %{$metadata_ref};
my ($sample_ref, $GeneKey) = check_matrix($opt_table_file, $metadata_ref);

 
my $conditions_ref = get_conditions($metadata_ref);

if ($opt_debug_sub) {
	say STDERR BOLD CYAN "\n## Structures ";
	say STDERR CYAN   "\nMetadata:";
	say STDERR Dumper $metadata_ref;

	say STDERR CYAN   "\nHeader_ref:";
	say STDERR Dumper $header_ref;

	say STDERR CYAN   "\nSample_ref:";
	say STDERR Dumper $sample_ref;

	say STDERR CYAN   "\nConditions_ref:";
	say STDERR Dumper $conditions_ref;


} 

print STDERR BOLD GREEN "\n## Conditions\n";
foreach my $condition (keys %{$conditions_ref} ){
	my $SampleLabels = '';
	my @conditions_array = ();
	my %condition_id = ();
	my $condition_counter = 0;
	
	next if ($condition=~/samplename/i);
	
	print  STDERR "Condition: ",GREEN "$condition\n";
	foreach my $sample_matrix (sort {$a <=> $b} keys %{$sample_ref}) {
		my $cond_name = $metadata_ref->{$sample_ref->{$sample_matrix}}->{$condition};
		if (! defined $condition_id{$cond_name} ) {
			$condition_counter++;
			$condition_id{$cond_name} = $condition_counter;
		
		}
	 	my $sample_name;
		if (defined $metadata_ref->{ $sample_ref->{$sample_matrix} }->{$opt_sample_description_title}) {
			$sample_name = $metadata_ref->{ $sample_ref->{$sample_matrix} }->{$opt_sample_description_title};
		} else {
			$sample_name = $sample_ref->{$sample_matrix};
			
		}
		$SampleLabels .= "\"$sample_name\",";
		if ($opt_debug) {
			#                  1..n            SampleName                     1,2..                      WT,TG...
			print STDERR "$sample_matrix: $sample_ref->{$sample_matrix}\t$condition_id{$cond_name}\t$cond_name\t$sample_name\n";
			push(@conditions_array, $condition_id{$cond_name});
		}

	}
	if ($condition_counter == 1) {
		say STDERR RED "Skipping:", RESET, " Condition \"$condition\" as there are no sub-comparisons\n";
		next;
	}
	

	my $TableFile = abs_path($opt_table_file);
	my $ConditionsList = join(',', @conditions_array);
	my $ColorVector = '';
	foreach my $c (@conditions_array) {
		$ColorVector .= $color_name{$c}.',';
	}
	chop($ColorVector);
	chop($SampleLabels);
	my $Output_File = abs_path($opt_outdir). '/' . $condition;	
 	
	my %hash = (
			'TableFile'       => $TableFile,
			'GeneKey'         => $GeneKey,
			'ConditionsList'  => $ConditionsList,
			'SampleLabels'    => $SampleLabels,
			'Output_File'     => $Output_File,
			'ConditionName'   => $condition,
			'ColorsList'     => $ColorVector,
	);

	my $script = fill_template($r_script, \%hash);
	say YELLOW $script if ($opt_debug_sub);
	open my $out, '>', "$opt_outdir/$condition.R" || die " FATAL ERROR:\n Unable to write script to $opt_outdir/$condition.R";
	print {$out} $script;
	close $out;
	my $cmd = qq(R CMD BATCH "$opt_outdir/$condition.R" "$opt_outdir/$condition.Rout.txt");
	`$cmd`;
	die " FATAL ERROR:\n Execution of command returned $?:\n#$cmd\n" if $?;
}
 



sub fill_template {
	my ($script, $hash_ref) = @_;
	while ($script =~/\{\{([_-\w]+)\}\}/g ) {
		my $Placeholder = $1;
		say RESET "$Placeholder\t", CYAN, ${$hash_ref}{$Placeholder} if ($opt_debug_sub);
		die " Placeholder $Placeholder is unsatisfied.\n" unless (${$hash_ref}{$Placeholder});
		$script =~s/\{\{$Placeholder\}\}/${$hash_ref}{$Placeholder}/g;

	}
	return $script;
}

sub get_conditions {
	my $ref = shift @_;
	my %cond;
	foreach my $sample (keys %{$ref}) {
		
		foreach my $item (keys %{ $ref->{$sample} } )  {
			
			$cond{$item}{$ref->{$sample}->{$item}}++;
		}
	}
	return \%cond;
}

sub check_matrix {
	my ($file, $metadata) = @_;
	my $gene_key = ''; 

	print STDERR CYAN "\tcheck_matrix($file,...) at line " , __LINE__ ,"\n" if ($opt_debug_sub);
	if (! -e "$file") {
		die " FATAL ERROR:\n Unable to find matrix table file <$file>\n";
	}
	my $fh;
	if  (! open $fh, '<', "$file" ) {
		 die " FATAL ERROR:\n Unable to read matrix table: <$file>\n";
	}		

	my %matrix_samples;
	my $c = 0;
	while (my $line = readline($fh) ) { 
		$c++;
		if ($c == 1) {
			#check header
			chomp($line);
			my ($key, @samples) = split /\t/, $line;
			$gene_key = $key;
			my $check_columns;
			my $col_num = 0;
			foreach my $sample (@samples) {
				$col_num++;
				$check_columns++ if $metadata->{$sample};
				$matrix_samples{$col_num} = $sample;
				
			}
			my $total = $#samples + 1;

			print "Valid matrix columns: $check_columns/$metadata_samples\n" if $opt_debug;
			warn "Matrix columns with sample names ($check_columns) differs from total matrix columns ($total)\n" unless ($total == $check_columns);
			warn "Matrix columns with sample names ($check_columns) differs from total metadata samples ($metadata_samples)\n" unless ($metadata_samples == $check_columns);
		} else {
			#
			my @columns = split /\t/, $line;
			my $col_num = $#columns + 1;
			#warn " FATAL ERROR: Matrix columns mismatch at line $c:\n" if ($col_num != $metadata_samples+1);

		}

	}
	print STDERR "Parsed table file: ", GREEN "$c lines\n";	
	return (\%matrix_samples, $gene_key);
}


sub parse_metadata {

	my ($file) = @_;

	print STDERR CYAN "\tparse_metadata($file) at line " , __LINE__ ,"\n" if ($opt_debug_sub);
	if (! -e "$file") {
		die " FATAL ERROR:\n Unable to find metadata file <$file>\n";
	}
	my $fh;
	if  (! open $fh, '<', "$file" ) {
		 die " FATAL ERROR:\n Unable to read metadata: <$file>\n";
	}

	#	SampleID	SampleName	Genotype	Time
	#	LIB21427	Time0_WT1	WildType	T0
	#	LIB21428	Time0_WT2	WildType	T0
	#	LIB21429	Time0_WT3	WildType	T0

	my @header = ();
	my %metadata = ();
	my %categories = ();
	my @counted_fields = ();
	my $line_counter = 0;
	while (my $line = readline($fh) ) {
		$line_counter++;
		chomp($line);
		my @fields = split /\t/, $line;
		next if ($line=~/^#/);
		next if ($line=~/^\s*$/);

		# Check header
		if ($fields[0] eq 'SampleID') {

			@header = @fields;
			#print  "Metadata_Header: ",GREEN, join(", ",@header), RESET "\n" if ($opt_debug);
			shift @header;

		} else {

			die " FATAL ERROR: Data found at line $line_counter before header!\n$line\n" unless ( $header[0] );

			my $key = shift @fields;
			my %hash = ();
			@hash{@header} = @fields;
 			
			$metadata{"$key"} = \%hash;


			#print Dumper \%hash;
			#print RED "\n", $metadata{$key}->{Time},"\n";
		}
		die " FATAL ERROR:\n Expecting at least 3 fields: SampleID SampleName Condition1\n",
			"Got (line $line_counter):\n[$line]\n" if ($#fields < 2);

		push(@counted_fields, $#fields);

	}
	my $k = scalar keys %metadata;
	
	print STDERR "Metadata file parsed: ", GREEN, "$k samples\n", RESET, "Labels: ", GREEN join(", ",@header), "\n" if ($opt_debug);

	return (\%metadata, \@header);

}


sub check_R_or_die {
	print STDERR CYAN "\tcheck_R_or_die() at line " , __LINE__ ,"\n" if ($opt_debug_sub);
	# I R on path?
	my $cmd = 'which R';
	my ($status, $output) = run_command($cmd);
	if (!$status) {
		print STDERR "R found: $output" if ($opt_debug);
	} else {
		die " FATAL ERROR:\n Unable to locate R in path: `$cmd` returned $status\n";
	}

	$cmd = 'R --version';
	my ($status, $output ) = run_command($cmd);

	if ($output=~/version (3[\.\d]+)/) {
		print STDERR "R version 3 found: $1\n" if ($opt_debug);
	} else {
		die " FATAL ERROR:\n R version 3.x is expected. Found: \n[$output]\n\n";
	}
}

sub run_command {
	my ($command, $message_title, $die_on_error)  = @_;
	print STDERR CYAN "\trun_command($command)\n" if ($opt_debug_sub);
	state $c = 0;
	$c++;
	if ($message_title) {
		print STDERR " [$c] $message_title ";
	}

	my $output = `$command`;

	if ($message_title) {
		print STDERR " [done]\n";
	}


	# DIE ON ERROR?
	if ($?) {
		die " FATAL ERROR:\n The command executed failed (error $?). Command:\n# $command\n\n" 
			if ($die_on_error);
	}

	print STDERR CYAN "\t\t->$?,", substr($output, 0, 20),"..\n" if ($opt_debug_sub);
	return ($?, $output);
}

__END__
# Comments...
SampleID	SampleName	Genotype	Time
LIB21427	T0_WT1	WT	T0
LIB21428	T0_WT2	WT	T0
LIB21429	T0_WT3	WT	T0


# Install package?
#list.of.packages <- c("edgeR")
#new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
#if(length(new.packages)) install.packages(new.packages)
#source("https://bioconductor.org/biocLite.R")
#biocLite("edgeR")


RawTableSubset <- subset(x, select=c("LIB26189", "LIB26190", "LIB26191",
                         "LIB26192", "LIB26193", "LIB26194"))
g1    <- factor( c(1,1,1,2,2,2)   )
y1 <- DGEList(counts=s1,group=g1)
y1 <- calcNormFactors(y1)


design <- model.matrix(~g1)
y1 <- estimateDisp(y1,design)

fit1  <- glmQLFit(y1,design)
qlf1  <- glmQLFTest(fit1,coef=2)
tags1 <- topTags(qlf1, n=100)
plotMDS(y1)
View(tags1)

# 7d Wt/Tg
s2 <- subset(x, select=c("LIB26195", "LIB26196", "LIB26197",
                         "LIB26199", "LIB26200", "LIB27458"
))
g1    <- factor( c(1,1,1,2,2,2)   )

y2 <- DGEList(counts=s2,group=g1)
y2 <- calcNormFactors(y2)
design <- model.matrix(~g1)
y2 <- estimateDisp(y2,design)

fit2  <- glmQLFit(y2,design)
qlf2  <- glmQLFTest(fit2,coef=2)
tags2 <- topTags(qlf2, n=100)
plotMDS(y2)
View(tags2)