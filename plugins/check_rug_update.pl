#!/usr/bin/env perl
#####################################################################
# check_rug_update.pl v1.1                  http://nagios.fm4dd.com/
#
# Runs the SUSE Zenworks online updater 'rug' to check for new
# patches and brings the result into Nagios-submittable format.
#
# 20081002 Frank4DD, build after check-yum-update.pl by Michal Ludvig
#####################################################################
use strict;
use Getopt::Long;

my ($file, $run_rug);
my $critical = 0;
my ($filelist, @updatelist, $num_upg, $num_new, $num_del, $num_noupg, $num_rugs);

GetOptions ('file=s'  => \$file,
            'run-rug' => \$run_rug,
            'help|?'    => sub { &usage() } );

if (defined($run_rug)) {
        # Novells zmd is buggy. Often, rug commands start to 'hang'
        # forever. This in turn let's the SNMP daemon 'hang' and other
        # SNMP requests fail. We check for this condition by counting
        # the current number of rug processes (3 because ps counts too).
        $num_rugs = `ps -ef |grep rug | wc -l`;
        if ( $num_rugs <= 3 ) {
	  open STDIN, "/usr/bin/rug lu |" or die "UNKNOWN - rug lu: $!\n";
        }
        else {
          # print "rug running: \n".`ps -ef |grep rug`;
          $num_rugs=$num_rugs-3;
          print ("UNKNOWN - $num_rugs rug found running, possibly a update download is in progress.\n");
          exit(1);
        }
} elsif (defined($file)) {
	open STDIN, "< $file" or die "UNKNOWN - $file : $!\n";
}

my $ret;

# process each line returned by rug here:
while (<>) {
  # skip over the empty lines
  next if(/^$/);

  # exit if there is no update
  if(/^No updates are available./) {
	print ("OK - system is up to date\n");
        exit (0);
  }

  # if there are updates, rug gives us the list like this
  #
  # S | Catalog           | Bundle | Name    | Version   | Arch
  # --+-------------------+--------+---------+-----------+-------
  # v | SLES10-SP2-Online |        | SPident | 0.9-74.24 | noarch

  # check for header line
  if (/^S | Catalog           | Bundle | Name    | Version   | Arch/) {
     
    # debug: print "We got updates...\n";

    while (<>) {
      # skip over the separator line 
      next if(/^--.*/);
      # skip over the empty lines
      next if(/^$/);

      # Strip newline and parse the data lines
      chop($_);
      (@updatelist) = split('\|', $_);

      # add patch name and version to the patchlist
      $filelist .= $updatelist[3]."Version".$updatelist[4];
      $num_upg ++;
    }
  }
}

# Check if the header line was parsed correctly
if (! defined($num_upg)) {
	print ("UNKNOWN - could not parse \"rug lu\" output\n");
	exit (3);
}

# this is the expected result list
if ($num_upg > 0) {
	print ("WARNING - $num_upg update(s) available:$filelist\n");
	exit (1);
}

# if the program comes here, we got lost ...
exit(-1);

# =========== end of main =============

sub usage() {

  printf("
Nagios SNMP check for SUSE SLES10 package updates

Author: Frank Migge <support\@frank4dd.com>
        after check-yum-upgrade.pl written by
        Michal Ludvig <michal\@logix.cz> (c) 2006

Usage: check_rug_upgrade.pl [options]

  --help          Guess what's it for ;-)
  --file=<file>   process file with output from a previous \"rug lu\"
  --run-rug       Run \"rug lu \" directly, the intended way

Option --run-rug has precedence over --file, i.e. no file is
read and \'rug lu\' is run internally. If none of these options 
are given we use standard input as default (e.g. to read from
a external command through a pipe).

Return value (according to Nagios expectations):
  * If no updates are found, returns OK.
  * If there are any updates, return WARNING.
  ");
  exit (1);
}
