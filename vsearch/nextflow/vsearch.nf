
params.reads = "$baseDir/reads/*_R{1,2}*.fastq.gz"
params.ref = "$baseDir/ref/ref.fa"
params.gold = "$baseDir/ref/silva.gold.fa"
params.outdir = "results"
params.singleEnd = ''

params.merge_minoverlap = 200
params.merge_maxdiffs   = 25

params.derep_minlen     = 300
params.derep_maxlen     = 480

params.min_uniques      = 2


log.info """\
  V S E A R C H - N F   P I P E L I N E
 =======================================
 database     : ${params.ref}
 reads        : ${params.reads}
 outdir       : ${params.outdir}
 """

if (params.readPaths) {
    if (params.singleEnd) {
 
        Channel
            .from(params.readPaths)
            .map { row -> [ row[0], [ file(row[1][0], checkIfExists: true) ] ] }
            .ifEmpty { exit 1, "params.readPaths was empty - no input files supplied" }
            .into { read_pairs_ch; read_pairs2_ch;  }
    } else {
 
        Channel
            .from(params.readPaths)
            .map { row -> [ row[0], [ file(row[1][0], checkIfExists: true), file(row[1][1], checkIfExists: true) ] ] }
            .ifEmpty { exit 1, "params.readPaths was empty - no input files supplied" }
            .into { read_pairs_ch; read_pairs2_ch;  }
    }
} else {
 
    Channel
        .fromFilePairs( params.reads, size: params.singleEnd ? 1 : 2 )
        .ifEmpty { exit 1, "Cannot find any reads matching: ${params.reads}\nNB: Path needs to be enclosed in quotes!\nNB: Path requires at least one * wildcard!\nIf this is single-end data, please specify --singleEnd on the command line." }
        .into { read_pairs_ch; read_pairs2_ch;  }
}

 


process mergepairs {
    tag "$pair_id"

    input:
    set val(name), file(reads)  from read_pairs_ch

    output:
    set val(name), file("*.mrg.fq") into mrg_ch

    script:
    """
    vsearch --fastq_mergepairs ${reads[0]}  \
        --threads ${task.cpus} \
        --reverse ${reads[1]} \
        --fastq_minovlen ${params.merge_minoverlap} \
        --fastq_maxdiffs ${params.merge_maxdiffs} \
        --fastqout ${name}.mrg.fq \
        --fastq_eeout
    """
}

process dereplicate {
    
    input:
    set val(name), file(merged)  from mrg_ch
   
    output:
    file("*.fasta") into derep_ch
    file("*.uc")    into derepuc_ch

    script:


    """
    echo FILTER
    vsearch --fastq_filter ${merged} \
        --fastq_maxee 0.5 \
        --fastq_minlen ${params.derep_minlen} \
        --fastq_maxlen ${params.derep_maxlen} \
        --fastq_maxns 0 \
        --fastaout ${name}.filt.fa \
        --fasta_width 0

     
    echo DEREP
    vsearch --derep_fulllength ${name}.filt.fa \
        --strand plus \
        --output ${name}.fasta \
        --sizeout \
        --uc ${name}.uc \
        --relabel ${name}. \
        --fasta_width 0

    """
}


process all_derep {
    input:
    file input_files from derep_ch.collect()

    output:
    file "derep.fasta" into combined_ch
    file "all.fasta"   into combined_raw_ch
    file "all.derep.uc"   into combined_uc_ch

    script:
    """
    echo Dereplicate across samples and remove singletons

    cat $input_files > all.fasta
    vsearch --derep_fulllength all.fasta \
        --minuniquesize ${params.min_uniques} \
        --sizein \
        --sizeout \
        --fasta_width 0 \
        --uc all.derep.uc \
        --output derep.fasta
    """
}

process all_clust {
    input:
    file derep  from combined_ch

    output:
    file "preclustered.fasta" into prec_ch
    file "preclustered.uc"    into prec_uc_ch

    script:
    """
    echo Precluster at 98% before chimera detection
    vsearch --cluster_size ${derep} \
        --threads ${task.cpus} \
        --id 0.98 \
        --strand plus \
        --sizein \
        --sizeout \
        --fasta_width 0 \
        --uc preclustered.uc \
        --centroids preclustered.fasta
    """
}
process all_chimer {
    input:
    file preclustered  from prec_ch

    output:
    file "nonchimeras.fasta" into nonchim_ch

    script:
    """
    echo De novo chimera detection
    vsearch --uchime_denovo ${preclustered} \
        --sizein \
        --sizeout \
        --fasta_width 0 \
        --nonchimeras  nonchimeras.fasta
    """
}
 

process all_chim_ref {
    input:
    file nonchimeras   from nonchim_ch
    file preclustered  from prec_ch
    file preclust_uc   from prec_uc_ch
    file all_fasta     from combined_raw_ch
    file all_uc        from combined_uc_ch

    output:
    file "combined_clean.fasta" into combined_clean_ch

    """
    echo Reference chimera detection

    vsearch --uchime_ref ${nonchimeras} \
        --threads ${task.cpus} \
        --db ${params.gold} \
        --sizein \
        --sizeout \
        --fasta_width 0 \
        --nonchimeras ref_nonchimeras.fasta
    
    echo "PATH=$PATH"
    echo -n "WHICH="
     which map.pl

    echo -n "Extract all non-chimeric, non-singleton sequences, dereplicated: "
     map.pl ${preclustered} ${preclust_uc} ref_nonchimeras.fasta > nonchimeric_derep.fasta
    echo DONE
   
    echo -n "Extract all non-chimeric, non-singleton sequences in each sample: "
     map.pl ${all_fasta} ${all_uc} nonchimeric_derep.fasta > combined_clean.fasta
    echo DONE

    """
}

process cluster_otus {
    publishDir params.outdir

    input:
    file combined_fasta from combined_clean_ch

    output:
    file "otus.fasta" into otus_ch
    file "otutab.txt" into otutab_ch

    script:
    """
    echo Cluster at 97% and relabel with OTU_n, generate OTU table

    vsearch --cluster_size ${combined_fasta} \
    --threads ${task.cpus} \
    --id 0.97 \
    --strand plus \
    --sizein \
    --sizeout \
    --fasta_width 0 \
    --uc all.clustered.uc \
    --relabel OTU_ \
    --centroids otus.fasta \
    --otutabout otutab.txt

    """
}

workflow.onComplete {
	log.info ( workflow.success ? 
        "\nDone! The results are saved in --> $params.outdir/\n" : 
        "Oops .. something went wrong" )
}
