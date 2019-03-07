set -euo pipefail 
ROTATE=$(perl fasta_grep.pl -i test_fasta_grep.fa -p CACCA --rotate)
ROTATE_RC=$(perl fasta_grep.pl -i test_fasta_grep.fa -p TGGTG --rotate)
ROTATE_CUT=$(perl fasta_grep.pl -i test_fasta_grep.fa -p CACCA --rotate --enzyme BamHI --enzyme EcoRI)
CUT=$(perl fasta_grep.pl -i test_fasta_grep.fa  --enzyme BamHI --enzyme EcoRI)


if [[ $ROTATE =~ "CACCAnTTTTTTTTTTTTggatccNNNNNNNNNNNNNNNNNNNNgaattcTTTTTTTTTTTTTTTTTTTTgaTTTTTTTn" ]]; then
	echo "OK 1/3: Rotation"
else
	echo "ERROR ROTATE: $ROTATE" 
fi
if [[ $ROTATE_CUT =~ "plasmid=60;insert=20;" ]]; then
	echo OK 2/3: Rotate + Restrict
else
	echo "ERROR ROTATE_CUT [expecting plasmid=60;insert=20;]: $ROTATE"
fi

if [[ $ROTATE_CUT =~ "plasmid=60;insert=20;" ]]; then
	echo OK 3/3: Restrict
else
	echo "ERROR CUT [expecting plasmid=60;insert=20;]: $ROTATE"
fi

