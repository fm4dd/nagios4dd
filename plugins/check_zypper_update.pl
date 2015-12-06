#!/usr/bin/env perl
#####################################################################
# check_zypper_update.pl v1.1             http://nagios.fm4dd.com/
#
# Runs the Novell SLES online updater 'zypper' to check for new
# patches and brings the result into Nagios-submittable format.
#
# 20100317 Frank4DD, build after check-yum-update.pl by Michal Ludvig
# 20100318 Frank4DD, updated to support different zypper output on SLES11
#
# SLES10 output example:
# # zypper lu
# Restoring system sources...
# Parsing metadata for SLES10-SP3-Updates...
# Parsing metadata for SLES10-SP3-Pool...
# Parsing metadata for SUSE Linux Enterprise Server 10 SP3...
# Parsing RPM database...
# Catalog            | Name                   | Version | Category    | Status
# -------------------+------------------------+---------+-------------+-------
# SLES10-SP3-Updates | slesp3-cron            | 6865-0  | security    | Needed
# SLES10-SP3-Updates | slesp3-ethtool         | 6789-0  | recommended | Needed
# # zypper -r lu
# Restoring system sources...
# Parsing metadata for SLES10-SP3-Updates...
# Parsing metadata for SLES10-SP3-Pool...
# Parsing metadata for SUSE Linux Enterprise Server 10 SP3...
# Parsing RPM database...
# S | Catalog            | Bundle | Name            | Version          | Arch  
# --+--------------------+--------+-----------------+------------------+-------
# v | SLES10-SP3-Updates |        | cron            | 4.1-45.31.1      | x86_64
# v | SLES10-SP3-Updates |        | ethtool         | 3-15.15.1        | x86_64
# 
# SLES11 output example:
# # zypper -r lu
# Loading repository data...
# Reading installed packages...
# No updates found.
#####################################################################
use strict;
use Getopt::Long;

my $zypper="/usr/bin/zypper -r"; # -r makes the output rug compatible
my ($file, $debug);
my $critical = 0;
my ($filelist, @updatelist, $num_upg, $num_new, $num_del, $num_noupg, $ret);

GetOptions ('file=s'  => \$file,
            'debug' => \$debug,
            'help'    => sub { &usage() } );

if (defined($file)) {
  open STDIN, "< $file" or die "UNKNOWN - $file : $!\n";
} else {
  open STDIN, "$zypper lu 2>/dev/null |" or die "UNKNOWN - $zypper lu: $!\n";
}

# process each line returned by zypper here:
$num_upg = 0;
while (<>) {
  if (defined($debug)) { print "zypper: $_"; }

  # skip over the header line 
  next if(/^S | Catalog *| Bundle *| Name *| Version *| Arch/);
  # skip over the separator line 
  next if(/^--.*/);
  # skip over the empty lines 
  next if(/^$/);

  # On SLES11, the zypper output changed :-(
  next if(/^Loading/);
  next if(/^Reading/);
  if($_ =~ /No updates found/) {
    print ("OK - system is up to date\n");
    exit (0);
  }

  # Strip newline and parse the data lines
  chop($_);
  if($_ =~ /\|/) { # if we have a line with separators left
    (@updatelist) = split('\|', $_);
    # add patch name and version to the patchlist
    if (defined($debug)) { print "update: $updatelist[3]\n"; }
    if (defined($debug)) { print "version: $updatelist[4]\n"; }
    $filelist .= $updatelist[3]."Version".$updatelist[4];
    if (defined($debug)) { print "filelst: $filelist\n"; }
    $num_upg ++;
    if (defined($debug)) { print "upgrnum: $num_upg\n"; }
  }
}

# Check if the header line was parsed correctly
if ($num_upg == 0) {
  print ("OK - system is up to date\n");
  exit (0);
}

# this is the expected result list
if (($num_upg > 0) && (! $filelist == "")) {
	print ("WARNING - $num_upg update(s) available: $filelist\n");
	exit (1);
} else {
  print ("UNKNOWN - could not parse \"zypper lu\" output\n");
  exit (3);
}

# if the program comes here, we got lost ...
exit(-1);

# =========== end of main =============

sub usage() {

  printf("
Nagios SNMP check for SUSE SLES10/11 package updates

Author: Frank4DD <support\@frank4dd.com>
        after check-yum-upgrade.pl written by
        Michal Ludvig <michal\@logix.cz> (c) 2006

Usage: check_zypper_upgrade.pl [options]

  --help          showing the plugin options
  --file=<file>   process file with output from a previous \"zypper lu\"
  --debug	  show debug output  of \"zypper lu \"

Return value (according to Nagios expectations):
  * If no updates are found, returns OK.
  * If there are any updates, return WARNING.
  ");
  exit (1);
}
