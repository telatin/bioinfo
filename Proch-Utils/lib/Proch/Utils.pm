package Proch::Utils;
# ABSTRACT: Common subroutines for enhanced CLI scripts
use strict;
use warnings;
use Term::ANSIColor;
use Carp qw(confess cluck);
=head1 NAME

B<Proch::N50> - a small module to calculate N50 (total size, and total number of
sequences) for a FASTA or FASTQ file. It's small and without dependencies.

=head1 SYNOPSIS

  use Proch::Utils;


=head1 METHODS

=head2 crash('message', $options)

Alternative version of 'die', that logs the error before quitting
  {
    title    => 'Error title',
  }

=head2 get_interactive_answer($question_data)

This function returns a value
  {
    question    => STR, question for the user,
    type        => STR, bool|str|int|float
    colors      => BOOL, print in colors
    feedback    => BOOL, print the recorded answer
    valid_re    => STR, pattern to validate the answer
  }


=head1 Dependencies

=over 4

=item L<JSON>

=back

=over 4

=item L<Term::ANSIColor>

=back

=head1 AUTHOR

Andrea Telatin <andrea@telatin.com>, Quadram Institute Bioscience

=head1 COPYRIGHT AND LICENSE

This free software under MIT licence. No warranty, explicit or implicit, is provided.

=cut

$Proch::Utils::VERSION = '0.0';
if ($^O eq 'MSWin32') {
  die "This module is not supporting MSWin32. It's tested under Linux (ubuntu) and macOS\n";
}
our %DEFAULT_GLOBAL_SETTINGS = (
  'colors' => 1,
);
our %SETTINGS = %DEFAULT_GLOBAL_SETTINGS;

sub set {
  my ($key, $value) = @_;
  $SETTINGS{$key} = $value;
}

sub get {
  my ($key, $local_settings) = @_;
  if (defined $local_settings->{$key}) {
    return $local_settings->{$key};
  } elsif (defined $SETTINGS{$key}) {
    return $SETTINGS{$key};
  } elsif (defined $DEFAULT_GLOBAL_SETTINGS{$key} ){
    return $DEFAULT_GLOBAL_SETTINGS{$key};
  }
  return undef;

}

sub c {
  my ($color, $opt) = @_;
  if ( get('colors', $opt) ) {
    return color($color);
  } else {
    return '';
  }
}

sub crash {
  my $opt = pop(@_);
  my ($message) = @_;

  print STDERR c('red bold'), $opt->{title} ? $opt->{title} : 'FATAL ERROR', c('reset'), "\n";
  print STDERR c('bold'),     $message,                                      c('reset'), "\n";
  confess();
}

sub get_interactive_answer {
    # NOTE! "ENTER" is never a valid answer!

    #   get_interactive_answer({
    #       question, STR, the question to be printed
    #       type,     STR, str(default), int, float, bool (y/n) or file (path)
    #       feedback, BOOL, print the received answer
    #       colors,   BOOL, use Term::ANSIColor to enhance the aspect
    #       valid_re, STR,  pattern used to validate the answer (optional)
    #   })
    my $opt = $_[0];

    $opt->{type} = 'str' unless defined $opt->{type};
    $opt->{valid_re} = '' unless defined $opt->{valid_re};

    my $type_validator = '.?';
    my $question_hint  = '';
    if ($opt->{type} eq 'int') {
      $type_validator = '^[0-9]+$';
      $question_hint  = '[integer]';
    } elsif ($opt->{type} eq 'float') {
      $type_validator = '^[0-9]+\.?[0-9]*$';
      $question_hint  = '[float]';
    } elsif ($opt->{type} eq 'bool') {
      $question_hint  = '[y/n]';
      $type_validator = '^(y|n|yes|no)$';   # Very broad: begin with Y(es)  or N(o)
    } elsif ($opt->{type} eq 'file') {
      $question_hint  = '[filepath]';
    }

  if ($opt->{colors}) {
    say STDERR color('bold'), '-> ', $opt->{question}, color('reset') , ' ' , $question_hint;
  } else {
    say STDERR                '-> ', $opt->{question},                  ' ' , $question_hint;
  }



  while (my $answer = <STDIN>) {
    chomp($answer);
    if ($answer !~/$opt->{valid_re}/ or $answer !~/$type_validator/i) {
      # Regex check failed
      print STDERR " Sorry, <$answer> is not a valid answer.\nTry again:";
    } elsif  ($opt->{type} eq 'file' and ! -e "$answer") {
        print STDERR " Sorry, file <$answer> was not found!\nTry again:";
      }else {
      # Type check

      # PROCESS ANSWER
      if ($opt->{feedback}) {
        if ($opt->{colors}) {
          say STDERR color('green'), "Recorded answer: [$answer]", color('reset');
        } else {
          say STDERR  "Recorded answer: [$answer]";
        }
      }


      return $answer;
    }
  }
}
1;
