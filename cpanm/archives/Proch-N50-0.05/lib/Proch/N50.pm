#ABSTRACT: Lightweight module to calculate N50 statistics from a FASTA or FASTQ file

use 5.016;
use warnings;

package Proch::N50;
$Proch::N50::VERSION = '0.05';
use JSON::PP;
use FASTX::Reader;
use File::Basename;
use Exporter qw(import);
our @EXPORT = qw(getStats getN50 jsonStats);


sub getStats {
    # Parses a FASTA/FASTQ file and returns stats
    # Parameters:
    # * filename (Str)
    # * Also return JSON string (Bool)

    my ( $file, $wantJSON ) = @_;
    my $answer;
    $answer->{status} = 1;
    $answer->{N50}    = undef;

    # Check file existence
    if ( !-e "$file" and $file ne '-' ) {
        $answer->{status}  = 0;
        $answer->{message} = "Unable to find <$file>";
    }

    

    # Return failed status if file not found or not readable
    if ( $answer->{status} == 0 ) {
        return $answer;
    }

    ##my @aux = undef;
    my $Reader;
    if ($file ne '-') {
       $Reader = FASTX::Reader->new({ filename => "$file" });
    } else {
       $Reader = FASTX::Reader->new({ filename => '{{STDIN}}' });
    }
    my %sizes;
    my ( $n, $slen ) = ( 0, 0 );

    # Parse FASTA/FASTQ file
    while ( my $seq = $Reader->getRead() ) {
        ++$n;
        my $size = length($seq->{seq});
        $slen += $size;
        $sizes{$size}++;
    }

    # Invokes core _n50fromHash() routine
    my ($n50, $min, $max) = _n50fromHash( \%sizes, $slen );

    my $basename = basename($file);

    $answer->{N50}      = $n50;
    $answer->{min}      = $min;
    $answer->{max}      = $max;
    $answer->{seqs}     = $n;
    $answer->{size}     = $slen;
    $answer->{filename} = $basename;
    $answer->{dirname}  = dirname($file);

    # If JSON is required return JSON
    if ( defined $wantJSON ) {

        my $json = JSON::PP->new->ascii->pretty->allow_nonref;
        my $pretty_printed = $json->encode( $answer );
        $answer->{json} = $pretty_printed;

    }
    return $answer;
}

sub _n50fromHash {
    # _n50fromHash(): calculate stats from hash of lengths
    #
    # Parameters:
    # * A hash of  key={contig_length} and value={no_contigs}
    # * Sum of all contigs sizes
    my ( $hash_ref, $total ) = @_;
    my $tlen = 0;
    my @sorted_keys = sort { $a <=> $b } keys %{$hash_ref};

    # Added in v. 0.039
    my $max =  $sorted_keys[-1];
    my $min =  $sorted_keys[0] ;

    foreach my $s ( @sorted_keys ) {
        $tlen += $s * ${$hash_ref}{$s};

     # Was '>=' in my original implementation of N50. Now complies with 'seqkit'
        return ($s, $min, $max) if ( $tlen > ( $total / 2 ) );
    }

}

sub getN50 {

    # Invokes the full getStats returning N50 or 0 in case of error;
    my ($file) = @_;
    my $stats = getStats($file);

    # Verify status and return
    if ( $stats->{status} ) {
        return $stats->{N50};
    } else {
        return 0;
    }
}

sub jsonStats {
  my ($file) = @_;
  my $stats = getStats($file,  'JSON');

  # Returns JSON object if it was possible to have ig
  if ($stats->{status} and $stats->{json}) {
    return $stats->{json}
  } else {
    # Returns 'undef' otherwise
    return undef;
  }
}
 

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Proch::N50 - Lightweight module to calculate N50 statistics from a FASTA or FASTQ file

=head1 VERSION

version 0.05

=head1 SYNOPSIS

  use Proch::N50 qw(getStats getN50);
  my $filepath = '/path/to/assembly.fasta';

  # Get N50 only: getN50(file) will return an integer
  print "N50 only:\t", getN50($filepath), "\n";

  # Full stats
  my $seq_stats = getStats($filepath);
  print Data::Dumper->Dump( [ $seq_stats ], [ qw(*FASTA_stats) ] );
  # Will print:
  # %FASTA_stats = (
  #               'N50' => 65,
  #               'min' => 4,
  #               'max' => 65,
  #               'dirname' => 'data',
  #               'size' => 130,
  #               'seqs' => 6,
  #               'filename' => 'small_test.fa',
  #               'status' => 1
  #             );

  # Get also a JSON object
  my $seq_stats_with_JSON = getStats($filepath, 'JSON');
  print $seq_stats_with_JSON->{json}, "\n";
  # Will print:
  # {
  #    "status" : 1,
  #    "seqs" : 6,
  #    <...>
  #    "filename" : "small_test.fa",
  #    "N50" : "65",
  # }

=head1 NAME

B<Proch::N50> - a small module to calculate N50 (total size, and total number of
sequences) for a FASTA or FASTQ file. It's small and without dependencies.

=head1 METHODS

=head2 getN50(filepath)

This function returns the N50 for a FASTA/FASTQ file given, or 0 in case of error(s).

=head2 getStats(filepath, alsoJSON)

Calculates N50 and basic stats for <filepath>. Returns also JSON if invoked
with a second parameter.
This function return a hash reporting:

=over 4

=item I<size> (int)

total number of bp in the files

=back

=over 4

=item I<N50> (int)

the actual N50

=back

=over 4

=item I<min> (int)

Minimum length observed in FASTA/Q file

=back

=over 4

=item I<max> (int)

Maximum length observed in FASTA/Q file

=back

=over 4

=item I<seqs> (int)

total number of sequences in the files

=back

=over 4

=item I<filename> (string)

file basename of the input file

=back

=over 4

=item I<dirname> (string)

name of the directory containing the input file

=back

=over 4

=item I<json> (string: JSON pretty printed)

(pretty printed) JSON string of the object (only if JSON is installed)

=back

=head2 jsonStats(filepath)

Returns the JSON string with basic stats (same as $result->{json} from I<getStats>(File, JSON)).
Requires JSON::PP installed.

=head2 _n50fromHash(hash, totalsize)

This is an internal helper subroutine that perform the actual N50 calculation, hence its addition
to the documentation.
Expects the reference to an hash of sizes C<$size{SIZE} = COUNT> and the total sum of sizes obtained
parsing the sequences file.
Returns N50, min and max lengths.

=head1 Dependencies

=over 4

=item L<JSON::PP> (core)

=back

=over 4

=item L<Term::ANSIColor> (optional)  for the n50.pl script

=back

=head1 AUTHOR

Andrea Telatin <andrea@telatin.com>, Quadram Institute Bioscience

=head1 COPYRIGHT AND LICENSE

This free software under MIT licence. No warranty, explicit or implicit, is provided.

=head1 AUTHOR

Andrea Telatin <andrea.telatin@quadram.ac.uk>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2019 by Andrea Telatin.

This is free software, licensed under:

  The MIT (X11) License

=cut
