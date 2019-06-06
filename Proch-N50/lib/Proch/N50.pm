package Proch::N50;
#ABSTRACT: a small module to calculate N50 (total size, and total number of sequences) for a FASTA or FASTQ file. It's easy to install, with minimal dependencies.

use 5.014;
use warnings;

$Proch::N50::VERSION = '0.11';

use JSON::PP;
use FASTX::Reader;
use File::Basename;
use Exporter qw(import);
our @EXPORT = qw(getStats getN50 jsonStats);

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
  #    "N50" : 65,
  # }
  # Directly ask for the JSON object only:
  my $json = jsonStats($filepath);
  print $json; 

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

=head2 Module (N50.pm)

=over 4

=item L<JSON::PP> (core module, required)

=back

=head2 Implementation (n50.pl)

=over 4

=item L<Term::ANSIColor> 

=back

=over 4

=item L<JSON>

(optional) when using C<--format JSON>

=back

=over 4

=item L<Text::ASCIITable>

(optional) when using C<--format screen>. This might be substituted by a different module in the future.

=back

=cut

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
# uncoverable condition right
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

    $answer->{N50}      = $n50 + 0;
    $answer->{min}      = $min + 0;
    $answer->{max}      = $max + 0;
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

     # N50 definition: https://en.wikipedia.org/wiki/N50_statistic
     # Was '>=' in my original implementation of N50. Now complies with 'seqkit'
     # N50 Calculation
        return ($s, $min, $max) if ( $tlen > ( $total / 2 ) );
    }

}

sub getN50 {

    # Invokes the full getStats returning N50 or 0 in case of error;
    my ($file) = @_;
    my $stats = getStats($file);

# Verify status and return
# uncoverable branch false
    if ( $stats->{status} ) {
        return $stats->{N50};
    } else {
        return 0;
    }
}

sub jsonStats {
  my ($file) = @_;
  my $stats = getStats($file,  'JSON');

# Return JSON object if getStats() was able to reduce one
# uncoverable branch false
  if (defined $stats->{json}) {
    return $stats->{json}
  } else {
    # Return undef otherwise
    return undef;
  }
}

# NOW READFQ IS PROVIDED BY: 'FASTX::Reader'

# sub _readfq {
#     # _readfq(): Heng Li's FASTA/FASTQ parser
#     # Parameters:
#     # * FileHandle
#     # * Auxiliary array ref
#     my ( $fh, $aux ) = @_;
#     @$aux = [ undef, 0 ] if ( !(@$aux) );
#
#     # Parse FASTA/Q
#     return if ( $aux->[1] );
#     if ( !defined( $aux->[0] ) ) {
#         while (<$fh>) {
#             chomp;
#             # Sequence header > or @
#             if ( substr( $_, 0, 1 ) eq '>' || substr( $_, 0, 1 ) eq '@' ) {
#                 $aux->[0] = $_;
#                 last;
#             }
#         }
#         if ( !defined( $aux->[0] ) ) {
#             $aux->[1] = 1;
#             return;
#         }
#     }
#
#     my $name = '';
#     if ( defined $_ ) {
#         $name = /^.(\S+)/ ? $1 : '';
#     }
#
#     my $seq = '';
#     my $c;
#     $aux->[0] = undef;
#     while (<$fh>) {
#         chomp;
#         $c = substr( $_, 0, 1 );
#         last if ( $c eq '>' || $c eq '@' || $c eq '+' );
#         $seq .= $_;
#     }
#     $aux->[0] = $_;
#     $aux->[1] = 1 if ( !defined( $aux->[0] ) );
#     return ( $name, $seq ) if ( $c ne '+' );
#     my $qual = '';
#     while (<$fh>) {
#         chomp;
#         $qual .= $_;
#         if ( length($qual) >= length($seq) ) {
#             $aux->[0] = undef;
#             return ( $name, $seq, $qual );
#         }
#     }
#     $aux->[1] = 1;
#     return ( $name, $seq );
# }


1;
