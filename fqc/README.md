# Count FASTQ lines

Unless format check is needed, counting the lines of a FASTQ file is a fast proxy to estimate/count the number of reads.

### fqc

A *wc-like* program that counts the lines of a text files, printing the results already divided by four. 

Can read from STDIN.

```
./fqc file1.fq [file2.fq ...]
```

### fqc.pl

A Perl program working like *fqc*, but also supporting GZipped files.

### Benchmark
| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `./fqc  ../tag_search/100ktest/tags_all.fastq ../tag_search/100ktest/tags_long.fastq *q ` | 10.6 ± 0.5 | 9.7 | 13.3 | 1.00 |
| `./fqc.pl  ../tag_search/100ktest/tags_all.fastq ../tag_search/100ktest/tags_long.fastq *q ` | 22.7 ± 0.6 | 21.5 | 24.2 | 2.14 ± 0.11 |
| `seqkit stats  ../tag_search/100ktest/tags_all.fastq ../tag_search/100ktest/tags_long.fastq *q ` | 71.2 ± 1.9 | 67.4 | 76.5 | 6.73 ± 0.36 |
| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `./fqc.pl  ./usearch/reads/*gz ` | 15.9 ± 0.7 | 14.3 | 18.1 | 1.00 |
| `seqkit stats  ./usearch/reads/*gz ` | 34.1 ± 1.2 | 31.9 | 38.2 | 2.15 ± 0.12 |
