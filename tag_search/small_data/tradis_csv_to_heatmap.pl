#!/usr/bin/env perl

use v5.14;
use Getopt::Long;
use File::Slurp;
use Text::CSV;
use File::Basename;
my $opt_version = undef;
my $opt_debug   = undef;
my $opt_min_q   = 0.01;
my $opt_key     = 'cpm';
my $opt_min_check = 1;
my $opt_grep;
my $opt_strip;
my $opt_nogrep;
my $opt_keep_ext;
my @FILES;
my %COUNTERS;
my $csv_parser = Text::CSV->new(
   {
	     sep_char => ',',
	     binary => 1,
	     eol => $/
   }
);

my $GetOptions = GetOptions(
  'version'          => \$opt_version,
  'debug'            => \$opt_debug,

  'q|min-q=f'        => \$opt_min_q,    # minimum Q value in at least 1 sample
  'z|min-sample=i'  => \$opt_min_check,
  'k|key=s'          => \$opt_key,

  'g|grep=s'         => \$opt_grep,     # Skip files not containing this string
  'v|anti-grep=s'    => \$opt_nogrep,   # Skip files  containing this string
  's|strip=s'        => \$opt_strip,    # Strip this string from file names
  'k|keep-ext'       => \$opt_keep_ext,
);

die " FATAL ERROR: -k,--key error: valid values are 'cpm', 'logfc' or 'q'\n"
  if ($opt_key !~/^(cpm|logfc|q)$/);

my %matrix = ();
foreach my $input_file (@ARGV) {
  $COUNTERS{'files_total'}++;
  deb(" - $input_file");

  open(my $data, '<', $input_file)
    or die "Could not open '$input_file' $!\n";

  if ( (defined $opt_grep and $input_file!~/$opt_grep/) or (defined $opt_nogrep and $input_file=~/$opt_nogrep/ ) ) {
    deb("\t - skipping");
    next;
  }
  $COUNTERS{'files_added'}++;
  my $input = basename($input_file);
  $input=~s/$opt_strip// if (defined $opt_strip);
  $input=~s/^([^\.]+)/\1/ if (! defined $opt_keep_ext);
  deb("\t - $input");
  push(@FILES, $input);
  my $c = 0;
  while (my $row = $csv_parser->getline ($data)) {
    $c++;
    next if ($c == 1);
    my $gene_name = $row->[1];
    my $log_fc    = $row->[3];
    my $log_cpm   = $row->[4];
    my $p_value   = $row->[5];
    my $q_value   = $row->[6];
    $matrix{$gene_name}{$input}{'cpm'} = $log_cpm;
    $matrix{$gene_name}{$input}{'logfc'} = $log_fc;
    $matrix{$gene_name}{$input}{'q'}   = $q_value;
    $COUNTERS{$input}+=$log_cpm;
  }
}


print "#\t";
foreach my $file (sort @FILES) {
  my $sep = "\t";
  $sep = "\n" if ($file eq $FILES[$#FILES]);
  print $file,$sep;
}


foreach my $gene (sort keys %matrix) {
  my $line = "$gene\t";
  my $check;
  $COUNTERS{'genes_total'}++;
  foreach my $file (sort @FILES) {
    my $sep = "\t";
    $sep = "\n" if ($file eq $FILES[$#FILES]);
    my $val = 0 + $matrix{$gene}{$file}{$opt_key};
    $check++ if ($matrix{$gene}{$file}{'q'} < $opt_min_q);
    $line .= "$val$sep";
  }
  if ($check >= $opt_min_check) {
    print $line;
    $COUNTERS{'genes_passed'}++;
  }

}

foreach my $key (sort keys %COUNTERS) {
  say STDERR "$key\t$COUNTERS{$key}";
}


sub deb {
  return if ! $opt_debug;
  say STDERR $_[0];
}

sub help {
  print STDERR <<END;

  Usage:
  tradis_csv_to_heatmap.pl [options] CSV_FILE1 CSV_FILE2 ...

  Options:
    -q, --min-q
                  Q-value must be lower than this in at least
                  'z' samples
    -z, --min-sample
                  Minimum number of samples that must have q-value
                  lower than -q
    -k, --key
                  Create a matrix based on key.
                  Values are: 'cpm' (default), 'logfc', 'q'
END
}
