#!/usr/bin/env perl
use warnings;
use v5.14;
use LWP::Simple;

our $status_url = 'https://bryn.climb.ac.uk/status';
my  $status_html = get($status_url);
my  $any = '.*?';

my  $regex = 	"<h2>([ [A-Za-z]+)<.h2>$any".
	     	"<td>Virtual machines running<.td>$any<td>(\\d+)</td>$any".
		"vCPU utilisation$any<.td>$any".
		"(\\d+) / (\\d+)$any".
		"<td>RAM utilisation$any<.td>$any".
		"<td>(\\d+) / (\\d+)$any<.tr>";

while ($status_html=~/$regex/sg) {
	my $vm_ratio  = "0.00%";
	$vm_ratio     = sprintf("%.1f", 100*$3/$4) if ($4);
	my $ram_ratio = "0.00%";
	$ram_ratio    = sprintf("%.1f", 100*$5/$6) if ($6);

	print "\n";
	print "# $1\n";
	print "VMs:\t$2\n";
	print "vCPU:\t$vm_ratio\t$3/$4\n";
	print "RAM:\t$ram_ratio\t$5/$6\n";
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

