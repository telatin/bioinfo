FASTQ=' ../tag_search/100ktest/tags_all.fastq ../tag_search/100ktest/tags_long.fastq *q '
GZ=' ./usearch/reads/*gz '
hyperfine --warmup 4 -m 25 --export-markdown fastq.md "./fqc $FASTQ" "./fqc.pl $FASTQ" "seqkit stats $FASTQ"
hyperfine --warmup 4 -m 25 --export-markdown gz.md "./fqc.pl $GZ" "seqkit stats $GZ"
