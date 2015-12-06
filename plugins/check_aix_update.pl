#!/usr/bin/perl
# --------------------------------------------------------------------------- #
#  check_aix_update.pl 1.0  @2009 by Frank4dd http://nagios.fm4dd.com/        #
#                                                                             #
# This script uses IBM's suma command to check if updates are waiting to be   #
# applied and reports it through snmptrap to Nagios. It is run through ssh    #
# from nagios on a permanent, i.e. daily basis. Since the patch verification  #
# command 'suma' needs root privileges, this script needs to be run via sudo. #
# -> /etc/sudoers: user ALL=(ALL) ALL, NOPASSWD: /path/to/check_aix_update.pl  #
# This example allows to run the script without needing the root password.    #
# Review sudo rights with extreme care, since root access is critical.        #
# The command "suma" itself is written in perl, its location is /usr/suma.    #
#                                                                             #
# For better reference and insight, the script additionally identifies the    #
# AIX Version + the configured update service URL as Nagios performance data. #
#                                                                             #
# The nagios plugins come with ABSOLUTELY NO WARRANTY. You may redistribute   #
# copies of the plugins under the terms of the GNU General Public License.    #
#                                                                             #
# help : ./check_aix_update.pl -h                                              #
# --------------------------------------------------------------------------- #
use strict;
use Getopt::Long;
use File::Basename;

# --------------------------------------------------------------------------- #
# Global Constants and Variables                                              #
# --------------------------------------------------------------------------- #
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

my $Version='1.0';
my $Name=$0;

my $o_help=             undef;          # want some help ?
my $o_version=          undef;          # print version
my $o_debug=            2;              # Default debug level

my $aixversion=		"";
my $hostname=           "";
my @swlist=             {};
my @uplist=             {};
my $swcount=            0;
my $upcount=            0;
my $upvalid=            0;
my $http_proxy=         "";
my $update_url=         "";
my @updates=            {};

# --------------------------------------------------------------------------- #
# Function show_versioninfo() shows the plugin version                        #
# --------------------------------------------------------------------------- #
sub show_versioninfo { print "$Name version : $Version\n"; }

# --------------------------------------------------------------------------- #
# Function print_usage displays commandline parameters                        #
# --------------------------------------------------------------------------- #
sub print_usage {
  print "Usage: $Name [-V] [-h <help>] [-d <debuglevel>]\n";
}

# --------------------------------------------------------------------------- #
# Function help() displays the plugin help                                    #
# --------------------------------------------------------------------------- #
sub help {
  print "AIX patch update check monitor for Nagios, version ",$Version,"\n";
  print "GPL licence, (c)2009 Frank4DD\n\n";
  print_usage();
  print <<EOT;
-V, --version
   prints the plugin version number
-h, --help
   print this help message
-d, --debug=INTEGER
   debug level, verbose (Default: $o_debug)
  The script will return
    OK       if we are able to get a list of patches and no patch needs to be applied, we are up-to-date.
    WARNING  if we are able to get a list of patches and patches are waiting to be applied.
    UNKNOWN  if we cannot access the Update URL (check the global settings of 'suma' for protocol, proxy or URL).
  Performance Data will return the AIX OS version as reported by uname.

EOT
}

# --------------------------------------------------------------------------- #
# Function check_options() gets the commandline parameters                    #
# --------------------------------------------------------------------------- #
sub check_options {
  Getopt::Long::Configure ("bundling");
  GetOptions(
      'h'     => \$o_help,        'help'          => \$o_help,
      'V'     => \$o_version,     'version'       => \$o_version,
      'd:i'   => \$o_debug,       'debug:i'       => \$o_debug,
  );
  if (defined ($o_help)) { help(); exit $ERRORS{"UNKNOWN"}};
  if (defined($o_version)) { show_versioninfo(); exit $ERRORS{"UNKNOWN"}};
}

# --------------------------------------------------------------------------- #
# Function os_version() collects the OS version from the system we run on     #
# AIXHOST3@[/home/user]> oslevel -s ->  #5300-07-01-0748                      #
# AIXHOST3@[/home/user]> oslevel -r ->  #5300-07                              #
# oslevel command is /usr/bin/oslevel                                         #
# --------------------------------------------------------------------------- #
sub os_version {
  $aixversion=`/usr/bin/oslevel -s`;
  # some really old versions of AIX doe not know oslevel -s
  if ($aixversion =~ /^Usage: /) { $aixversion=`/usr/bin/oslevel -r`; }
  chomp $aixversion;
}

# --------------------------------------------------------------------------- #
# Function get_settings(): Which protocol, proxy and IBM update URL is set?   #
# AIXHOST3@[/home/user]> sudo /usr/sbin/suma -c                               #
# FIXSERVER_PROTOCOL=http                                                     #
# DL_TIMEOUT_SEC=180                                                          #
# DL_RETRY=1                                                                  #
# HTTP_PROXY=http://192.168.100.184:80/                                       #
# HTTPS_PROXY=                                                                #
# FTP_PROXY=                                                                  #
# FIXSERVER_URL=www14.software.ibm.com/webapp/set2/fixget                     #
# --------------------------------------------------------------------------- #
sub get_settings {
  my $value = "";
  my $prefix = "";
  $hostname=`/usr/bin/hostname`;

  $value = `/usr/sbin/suma -c | grep HTTP_PROXY`;
  if ($? != 0) { print "Unknown - Error executing suma, code $?. Please run as root - or run this script suid root.\n"; exit (3); }
  chomp $value;
  # print "Value: >$value<\n"; # Value: >        HTTP_PROXY=http://192.168.100.184:80/<
  ($prefix, $http_proxy) = split /=/, $value;

  $value = `/usr/sbin/suma -c | grep FIXSERVER_URL`;
  if ($? != 0) { print "Unknown - Error executing suma, code $?. Please run as root - or run this script suid root.\n"; exit (3); }
  chomp $value;
  # print "Value: >$value<\n";
  ($prefix, $update_url) = split /=/, $value;
}

# --------------------------------------------------------------------------- #
# Function get_updates(): Check if updates are available from IBM using suma  #
# AIXHOST3@[/home/user]> sudo /usr/sbin/suma -x -a RqType=Security            #
# -a Action=Preview                                                           #
# updates are listed like this:                                               #
# Download SUCCEEDED: /usr/sys/inst.images/installp/ppc/perl.rte.5.8.2.71.bff #
# Failures, i.e. due to incorrect proxy settings look like this:              #
# AIXHOST3@[/home/user]> sudo suma -x -a RqType=Security -a Action=Preview    #
# 0500-013 Failed to retrieve list from fix server.                           #
# It's a good idea to reduce the standard timeout from 180sec to, say, 15sec: #
# AIXHOST3@[/home/user]> sudo suma -c -a DL_TIMEOUT_SEC=15                    #
# --------------------------------------------------------------------------- #
sub get_updates {
  for (`/usr/sbin/suma -x -a RqType=Security -a Action=Preview 2>&1`) {
    if ($_ =~ /Failed to retrieve list from fix server/) {
      print "Unknown - Error getting the update list from IBM. Check proxy and update-server URL settings.\n"; exit (3);
    }
    if ($? != 0) { print "Unknown - Error executing suma, code $?. Please run as root - or run this script suid root.\n"; exit (3); }
    if ($_ =~ /Download SUCCEEDED: /) {
      # print $_."\n";
      my ($dummystr, $path) = split ': ', $_;
      my($filename, $directories, $suffix) = fileparse($path, ".bff");
      # print $filename."\n"; # returns perl.rte.5.8.2.71
      my ($fileset) =  split /\.\d+\.\d+\.\d+\.\d+/, $filename;
      $uplist[$upcount]{fileset} = $fileset;
      my $level = substr($filename, length ($fileset)+1, -1);
      $uplist[$upcount]{level} = $level;
      # print "Fileset: ".$fileset." Level: ".$level."\n"; # Fileset: perl.rte Level: .5.8.2.71
      $upcount++;
    }
  }
}

# --------------------------------------------------------------------------- #
# Function get_swlist(): Check what software we have installed                #
# MLJAIXT3@[/home/user] > lslpp -q -c -l                                      #
# -q Suppresses the display of column headings                                #
# -c Displays information as a list separated by colons                       #
# -l Displays name, most recent level, state, and description                 #
# returns this list:                                                          #
# Repository:Fileset:Level:PTF Id:State:Type:Description:EFIX Locked          #
# /usr/lib/objrepos:bos.64bit:5.3.7.0::APPLIED:F:Base OS 64 bit Runtime:      #
#                                                                             #
# COMMITTED - The specified fileset is installed on the system. The COMMITTED #
# state means that a commitment has been made to this level of the software,  #
# it cannot be rejected.                                                      #
# APPLIED  -  The specified fileset is installed on the system. The APPLIED   #
# state means that the fileset can be rejected with the installp command and  #
# the previous level of the fileset restored.                                 #
# --------------------------------------------------------------------------- #
sub get_swlist {
  my @values;
  for (`lslpp -q -c -l`) {
    (@values) = split /:/, $_;
    $swlist[$swcount]{repos}   = $values[0]; # /usr/lib/objrepos
    $swlist[$swcount]{fileset} = $values[1]; # perl.rte
    $swlist[$swcount]{level}   = $values[2]; # 5.8.2.70
    $swlist[$swcount]{ptfid}   = $values[3]; # _
    $swlist[$swcount]{state}   = $values[4]; # APPLIED
    $swlist[$swcount]{type}    = $values[5]; # F
    $swlist[$swcount]{desc}    = $values[6]; # Perl Version 5 Runtime Env
    $swlist[$swcount]{efix}    = $values[7]; # _
    # print $values[0];
    $swcount++;
  }
}

# --------------------------------------------------------------------------- #
# Function update_validation(): verify which fileset is to be updated         #
# --------------------------------------------------------------------------- #
sub update_validation {
  my $i=0;
  while ($i<$swcount) {
    my $j=0;
    while ($j<$upcount) {
      if ( $swlist[$i]{fileset} eq $uplist[$j]{fileset} ) {
        my ($sw_tl) = split /\.\d+$/, $swlist[$i]{level};
        my ($up_tl) = split /\.\d+$/, $uplist[$j]{level};
        if ($sw_tl eq $up_tl) {
          # print "Old Package ".$i." installed: ".$swlist[$i]{fileset}." (fileset) ".$swlist[$i]{level}." (version) ".$sw_tl." (TL)\n";
          # print "New Package ".$j." upd avail: ".$uplist[$j]{fileset}." (fileset) ".$uplist[$j]{level}." (version) ".$up_tl." (TL)\n";
          # print "# --------------------------------------------------------------------------- #\n";
          $updates[$upvalid] = $uplist[$j]{fileset}." Version ".$uplist[$j]{level};
          $upvalid++;
        }
      }
      $j++;
    }
    $i++;
  }
}

# --------------------------------------------------------------------------- #
# End Function Defs, Start Main                                               #
# --------------------------------------------------------------------------- #
check_options();
os_version();
get_settings();
get_updates();
get_swlist();
update_validation();

#print "AIX version $aixversion\n";
#print $upcount." updates available.\n";
#print "Update ".($upcount-1)." avail: ".$uplist[$upcount-1]{fileset}." (fileset) ".$uplist[$upcount-1]{level}." (version)\n";
#print $swcount." packages installed.\n";
#print "SW ".($swcount-1)." installed: ".$swlist[$swcount-1]{fileset}." (fileset) ".$swlist[$swcount-1]{level}." (version)\n";
#print $upvalid." updates validated.\n";
#print "Proxy Settings: -".$http_proxy."-\n";
#print "URL Settings: -".$update_url."-\n";
#print "Updates: @updates\n";

# no updates available - we are up to date
if($upvalid == 0) {
  print ("OK - system is up to date|OS Version $aixversion, Proxy $http_proxy, Update-URL $update_url\n");
  exit (0);
}

# We got updates, list them and add the performance section
if ($upvalid > 0) {
  print ("WARNING - $upvalid update(s) available: @updates|OS Version $aixversion, Proxy $http_proxy, Update-URL $update_url\n");
  exit (1);
}

exit  $ERRORS{"OK"};
# --------------------------------------------------------------------------- #
# End Main                                                                    #
# --------------------------------------------------------------------------- #
