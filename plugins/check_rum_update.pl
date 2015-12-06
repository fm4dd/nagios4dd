#!/usr/bin/env perl

use strict;
use Getopt::Long;

my ($file, $run_rum);
my $critical = 0;
my ($filelist, @updatelist, $num_upg, $num_new, $num_del, $num_noupg);

GetOptions ('file=s' => \$file,
	'run-rum' => \$run_rum,
	'help' => sub { &usage() } );

# python 2.5.1 throws this nasty error message on STERR:
#/usr/lib64/python2.5/urllib2.py:662: RuntimeWarning: urllib can't handle https proxies, your https_proxy setting will not work
#we really want to supress it
if($ENV{https_proxy}) { delete $ENV{https_proxy}; }

if (defined($run_rum)) {
	open STDIN, "/usr/bin/rum lu |" or die "UNKNOWN - rum lu: $!\n";
} elsif (defined($file)) {
	open STDIN, "< $file" or die "UNKNOWN - $file : $!\n";
}

my $ret;

# process each line returned by rum here:
while (<>) {
  next if(/^$/);

  # exit if there is no update: # rum lu
  #
  #--- No updates found ---
  #

  if(/^--- No updates found ---/) {
	print ("OK - system is up to date\n");
        exit (0);
  }

  # if there are any updates, we get the list.
  # example output looks like this: # rum lu
  #
  # Repository       | Name        | Current Version | Updated Version
  # -----------------+-------------+-----------------+-----------------
  # opensuse-updates | ipsec-tools | 0.6.5-104       | 0.6.5-104.3.i586

  if (/^Repository       | Name        | Current Version | Updated Version/) {
     
    # debug: print "We got updates...\n";

    while (<>) {
      next if(/^$/);
      next if(/^--.*/);
      chop($_);
      (@updatelist) = split('\|', $_);
      $filelist .= $updatelist[1]."Version".$updatelist[3];
      $num_upg ++;
    }
  }
}

if (! defined($num_upg)) {
	print ("UNKNOWN - could not parse \"rum lu\" output\n");
	exit (3);
}

if ($num_upg > 0) {
	print ("WARNING - $num_upg update(s) available:$filelist\n");
	exit (1);
}

exit(-1);

# ===========

sub usage() {
	printf("
Nagios SNMP check for SUSE SLES10 package updates

Author: Frank Migge <support\@frank4dd.com>
        after check-yum-upgrade.pl written by
        Michal Ludvig <michal\@logix.cz> (c) 2006

Usage: check_rum_upgrade.pl [options]

  --help          Guess what's it for ;-)
  --file=<file>   File with output from previous \"rum lu\"
  --run-rum       Run \"rum lu \" directly. 

Option --run-rum has precedence over --file, i.e. no file is
read if rum-get is run internally. If none of these options 
is given use standard input by default (e.g. to read from
external command through a pipe).

The SNMP timeout needs to be increased bceaus ethe script
rarely finishes in the standard 1 sec. -> check_snmp_extend.sh 

Return value (according to Nagios expectations):
  * If no updates are found, returns OK.
  * If there are any updates, return WARNING.
");
	exit (1);
}
