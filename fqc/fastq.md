| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `./fqc  ../tag_search/100ktest/tags_all.fastq ../tag_search/100ktest/tags_long.fastq *q ` | 10.6 ± 0.5 | 9.7 | 13.3 | 1.00 |
| `./fqc.pl  ../tag_search/100ktest/tags_all.fastq ../tag_search/100ktest/tags_long.fastq *q ` | 22.7 ± 0.6 | 21.5 | 24.2 | 2.14 ± 0.11 |
| `seqkit stats  ../tag_search/100ktest/tags_all.fastq ../tag_search/100ktest/tags_long.fastq *q ` | 71.2 ± 1.9 | 67.4 | 76.5 | 6.73 ± 0.36 |
