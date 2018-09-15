#!/usr/bin/env perl

use v5.14;
use Getopt::Long;
use File::Slurp;
use Text::CSV;
use Data::Dumper;
use File::Basename;

my $opt_version = undef;
my $opt_debug   = undef;
my $opt_min_q   = 0.001;
my $opt_key     = 'cpm';
my $opt_fc_ths;
my $opt_pass;
my $opt_min_sum;
my $opt_min_check = 1;
my $opt_grep;
my $opt_strip;
my $opt_nogrep;
my $opt_keep_ext;
my @FILES;
my %COUNTERS;
my $opt_inspect;

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
  'z|min-sample=i'   => \$opt_min_check,
  'key=s'            => \$opt_key,

  'g|grep=s'         => \$opt_grep,     # Skip files not containing this string
  'v|anti-grep=s'    => \$opt_nogrep,   # Skip files  containing this string
  's|strip=s'        => \$opt_strip,    # Strip this string from file names
  'k|keep-ext'       => \$opt_keep_ext,
  'i=s'              => \$opt_inspect,

  'fcths=f'          => \$opt_fc_ths,
  'minsum=f'         => \$opt_min_sum,
  'pass'             => \$opt_pass,
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
    # 0 "BW25113_0464",
    # 1 "acrR",
    # 2 "transcriptional repressor",
    # 3 fc 1.87706038319424,
    # 4 cpm 9.33941478942147,
    # 5 pv 3.1789673862008e-06,
    # 6 qv 0.0012016496719839
    my $gene_name = $row->[1];
    my $log_fc    = $row->[3];
    my $log_cpm   = $row->[4];
    my $p_value   = $row->[5];
    my $q_value   = $row->[6];
    $matrix{$gene_name}{$input}{'cpm'} = $log_cpm;
    $matrix{$gene_name}{$input}{'logfc'} = $log_fc;
    $matrix{$gene_name}{$input}{'q'}   = $q_value;
    $COUNTERS{"cpm_$input"}+=$log_cpm;
    $COUNTERS{"qpositive_$input"}++ if ($q_value <= $opt_min_q);

    die "FATAL ERROR: Unexpected q_value={$q_value} at gene $gene_name in $input\n"
      if ($q_value < 0);
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
  my $check = 0;
  my $check_val = 0;
  my $gene_sum = 0;
  $COUNTERS{'genes_total'}++;
  foreach my $file (sort @FILES) {
    my $str = '';
    my $sep = "\t";
    $sep = "\n" if ($file eq $FILES[$#FILES]);
    my $val = 0 + $matrix{$gene}{$file}{$opt_key};
    $val = fc_change($val) if (defined $opt_fc_ths);

    if ($opt_pass) {
      $val = 0;
      $val = 1000 if (defined $matrix{$gene}{$file}{'q'} and $matrix{$gene}{$file}{'q'} <= $opt_min_q);
    }

    $gene_sum += $val;
    if (defined $matrix{$gene}{$file}{'q'} and $matrix{$gene}{$file}{'q'} <= $opt_min_q) {
      $check++;
      $str = '<OK>';
    }
    $line .= "$val$sep";

    if ($opt_debug and $gene=~/$opt_inspect/) {
      print STDERR Dumper $matrix{$gene}{$file};
      print STDERR "[$gene:$opt_inspect:$file > <<$val>>]\n";
      print STDERR "[q $str $matrix{$gene}{$file}{'q'} <= $opt_min_q; $opt_key $matrix{$gene}{$file}{$opt_key}]\n";
    }
  }
  if ($check >= $opt_min_check ) {
    next if (defined $opt_min_sum and $gene_sum <= $opt_min_sum);
    print $line;
    $COUNTERS{'genes_passed'}++;
    $COUNTERS{"passed_$check"}++;
  }
  if ($opt_debug and $gene=~/$opt_inspect/) {
    print STDERR "==Total $gene hits: $check\n";
  }

}

foreach my $key (sort keys %COUNTERS) {
  say STDERR "$key\t$COUNTERS{$key}";
}


sub fc_change {
  my $value = shift;
  if ( $value <= -1 * abs($opt_fc_ths) )  {
    return -1;
  } elsif ($value >= abs($opt_fc_ths) ) {
    return +1;
  } elsif ($value < abs($opt_fc_ths) or  $value > -1 * abs($opt_fc_ths) ){
    return 0;
  }
  return 1000;
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
