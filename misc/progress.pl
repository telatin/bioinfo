use Term::ProgressBar::Simple;
# create some things to loop over
my @things = (1,2,3,4,5,6,7,8,9,10,1,2,3,4,5,6,7,8);
my $number_of_things = scalar @things;
 
# create the progress bar object
my $progress = Term::ProgressBar::Simple->new( $number_of_things );
 
# loop
foreach my $thing (@things) {
    sleep 1; 
    # increment the progress bar object to tell it a step has been taken.
    $progress++;
}
 
# See also use of '$progress += $number' later in pod
