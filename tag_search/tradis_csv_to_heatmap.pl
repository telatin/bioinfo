#!/usr/bin/env perl

use v5.14;
use Getopt::Long;
use File::Slurp;
use Text::CSV;
use File::Basename;
my $opt_version = undef;
my $opt_debug   = undef;
my $opt_min_q   = 0.05;
my $opt_min_check = 1;
my $opt_grep;
my $opt_strip;
my $opt_nogrep;
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
  'v|version'    => \$opt_version,
  'd|debug'      => \$opt_debug,
  'g|grep=s'     => \$opt_grep,     # Skip files not containing this string
  'n|no-grep=s'  => \$opt_nogrep,   # Skip files  containing this string
  's|strip=s'    => \$opt_strip,    # Strip this string from file names
  'q|minq=f'     => \$opt_min_q,    # minimum Q value in at least 1 sample
  'z|minsampl=i' => \$opt_min_check,
);

my %matrix = ();
foreach my $input_file (@ARGV) {
  $COUNTERS{'files_total'}++;
  open(my $data, '<', $input_file) or die "Could not open '$input_file' $!\n";
  deb(" - $input_file");
  if ( (defined $opt_grep and $input_file!~/$opt_grep/) or (defined $opt_nogrep and $input_file=~/$opt_nogrep/ ) ) {
    deb("\tskipping");
    next;
  }
  $COUNTERS{'files_added'}++;
  my $input = basename($input_file);
  $input=~s/$opt_strip// if (defined $opt_strip);
  deb("\t$input");
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
    $matrix{$gene_name}{$input}{'q'}   = $q_value;
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
    my $val = 0 + $matrix{$gene}{$file}{'cpm'};
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
