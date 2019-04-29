# Color NGS
## A small selection of not-so-useful script to add some colors to bioinformatics files


### cfastq.pl
A script to add colors to FASTA/FASTQ files.
```
 USAGE:
 cfastq.pl File1.fastq File2.fastq ...
 cat File.fasta | cfastq.pl

  --nocolorseq        Don't color the sequence
  --nocolorqual       Don't color quality
  --nocolor           Don't color anything (why?)
  
  --visualqual        Replace quality char with ASCII art bars

  -s, --qual_scale    INT,INT,INT,INT 
                      Set quality thresholds for colors

  -n, --quality_numbers
                      Display integers rather than chars 

  -d, --debug         Debug mode
  -v, --verbose       Print more information
```
