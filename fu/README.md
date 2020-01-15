# Fastx Utilities

Scripts to extract information from FASTA/FASTQ files 


### fu-extract.pl

From one (or more) FASTA files, extract sequences using a pattern or
a list from a text file

```
	Usage:
	fu-extract.pl [options] InputFile.fa [...]

	-p, --pattern   STRING
	-m, --minlen    INT
	-x, --maxlen    INT
	-l, --list      FILE
	-c, --column    INT (default: 1)
	-s, --separator CHAR (default: "	")
	-h, --header    CHAR (defatul: "#")

	Note that "-p" and "-l" are exclusive

	example:
	fu-extract.pl -p 'BamHI' test.fa

	fu-extract.pl -l list.txt test.fa

```