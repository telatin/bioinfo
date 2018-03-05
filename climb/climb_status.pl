#!/usr/bin/env perl
use warnings;
use v5.14;
use LWP::Simple;
use Term::ANSIColor;
our $status_url = 'https://bryn.climb.ac.uk/status';
our $disabled_string = 'Launching new instances disabled';
my  $status_html = get($status_url);
my  $any = '.*?';

my  $regex = 	"<h2>([ [A-Za-z]+)<.h2>".
		"($any)<table$any".
	     	"<td>Virtual machines running<.td>$any<td>(\\d+)</td>$any".
		"vCPU utilisation$any<.td>$any".
		"(\\d+) / (\\d+)$any".
		"<td>RAM utilisation$any<.td>$any".
		"<td>(\\d+) / (\\d+)$any<.tr>";

print "# $status_url\n";

while ($status_html=~/$regex/sg) {
	my $datacenter = $1;
	my $vm_ratio  = "0.00%";
	$vm_ratio     = sprintf("%.1f", 100*$4/$5) if ($5);
	my $ram_ratio = "0.00%";
	$ram_ratio    = sprintf("%.1f", 100*$6/$7) if ($7);
	print "\n";

	print color('bold'), "# $1\n", color('reset');

	print "VMs:\t$3\n" if (defined $3);
	print "vCPU:\t$vm_ratio\t$4/$5\n" if (defined $4 and defined $5);
	print "RAM:\t$ram_ratio\t$6/$7\n" if (defined $6 and defined $7);
	if ($2=~/$disabled_string/) {
		print color('red');
		print "\n >>> WARNING: NEW INSTANCES DISABLED in $datacenter \n";
		print color('reset');
	}


}

# EXAMPLE RECORD
# DATE: 14 02 2018 <3
#
#   <h2>University of Warwick</h2>
#
#       <p>Stats last updated Feb. 14, 2018, 9 a.m.</p>
#        <table class="table table-responsive">
#         <tr>
#          <th>Statistic</th>
#          <th>Value</th>
#         </tr>
#         <tr>
#          <td>Virtual machines running</td>
#          <td>201</td>
#         </tr>
#         <tr>
#          <td>vCPU utilisation (used / total)</td>
#          <td>1446 / 1280</td>
#         </tr>
#         <tr>
#          <td>RAM utilisation (used / total in MB)</td>
#          <td>8341958 / 10479600</td>
#         </tr>
#        </table>

