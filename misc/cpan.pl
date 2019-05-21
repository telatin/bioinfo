#!/usr/bin/env perl
use MetaCPAN::Client;
use Data::Dumper;
use Data::Printer;
#my $all_releases = $mcpan->all('releases', { fields => "version,author" })
my $recent =
    MetaCPAN::Client->new->recent(3);
 
while ( my $rel = $recent->next ) {
    my %output = (
        NAME    => $rel->name,
        AUTHOR  => $rel->author,
        DATE    => $rel->date,
        VERSION => $rel->version,
    );
    my $rating =    MetaCPAN::Client->new->rating({ distribution => $rel->name, });

    p %output;
    p $rating->next;
}