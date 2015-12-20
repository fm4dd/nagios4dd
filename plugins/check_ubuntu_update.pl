#!/usr/bin/perl -w
########################### check_ubuntu_update.pl  ##################
my $VERSION = '0.7';
#
# Original plugin: check_debian_packages
#
# Author: Copyright (C) 2005 Francesc Guasch
#
# License: GPL - http://www.fsf.org/licenses/gpl.txt
#
# Report bugs to: frankie@etsetb.upc.edu
#
# This program checks outstanding patches for Ubuntu by calling
# the apt-get (or aptitude) tool.
#####################################################################
use strict;
use lib '/srv/app/nagios/lib';
use utils qw(%ERRORS &print_revision &support &usage);
use Getopt::Long;

my $RET = 'OK';
my $LOCK_FILE = "/var/lib/dpkg/lock";
my $CMD_APT = "/usr/bin/apt-get -s upgrade";
my ($PROGNAME) = $0 =~ m#.*/(.*)#;
my ($help,$version);
# my $CMD_APT = "/usr/bin/aptitude -v -s -y safe-upgrade";
my $TIMEOUT = 60;
my $DEBUG = 0;

######################################################################
# unlikely but compliant
######################################################################
$SIG{'ALRM'} = sub {
   print ("ERROR: Timeout\n");
   exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);

######################################################################
# subs
######################################################################
sub print_usage {
   print "Usage: $PROGNAME [--debug] [--version] [--help]" ." [--timeout=$TIMEOUT]\n";
}

sub add_info {
   my ($info,$type,$pkg) = @_;
   $$info .= scalar(keys %$pkg)." new pkgs in $type: ";
   if (keys %$pkg< 5 ) {
      $$info .= join " ",keys %$pkg;
   }
   else {
      my $alguns = join " ",keys %$pkg;
      $alguns = substr($alguns,0,80);
      $alguns .= "...";
      $$info .= $alguns;
   }
}

sub exit_unknown {
   my ($info) = @_;
   chomp $info;
   $RET='UNKNOWN';
   print "$RET - $info\n";
   exit $ERRORS{$RET};
};

sub run_apt {
   my ($pkg,$ver,$type,$release);
   open APT,"$CMD_APT 2>&1|" or exit_unknown($!);
   my (%updates,%backports,%security,%other);
   while (<APT>) {
      print "APT: $_" if $DEBUG;
      exit_unknown($_) if /(Could not open lock file)|(Could not get lock)/;
      next unless /^Inst/;
      ($pkg,$ver,$release) = /Inst (.*?) .*\((.*?) (.*?)\)/;
      print "$_\npkg=$pkg ver=$ver release=$release\n" if $DEBUG;
      die "$_\n" unless defined $release;
      $release = 'updates'  
      if $release =~ /updates/;
      $release = 'backports'
      if $release =~ /backports/;
      $release = 'security' 
      if $release =~ /security/i;
      if ($release eq 'updates') { $updates{$pkg} = $ver; }
      elsif ($release eq 'backports') { $backports{$pkg} = $ver; }
      elsif ($release eq 'security') { $security{$pkg} = $ver; }
      else { $other{$pkg}=$ver; }
   }
   close APT;
   my $info = '';
   if (keys (%security)) {
      $RET = 'CRITICAL';
      add_info(\$info,'security',\%security);
   }
   elsif (keys (%other) or keys(%updates)) {
      $RET = 'WARNING';
      add_info(\$info,'updates',\%updates);
      add_info(\$info,'backports',\%backports) if keys %backports;
      add_info(\$info,'other',\%other) if keys %other;
   }
   else { $info = 'No outstanding patches.'; }
   print "$RET - $info\n";
}

#####################################################################
# main program
#####################################################################

# Check command line arguments
GetOptions( help        => \$help,
            debug       => \$DEBUG,
            version     => \$version,
            'timeout=s' => \$TIMEOUT );

if ($help) {
   print_revision($PROGNAME,"\$Revision: $VERSION \$");
   print "Copyright (c) 2005 Francesc Guasch - Ortiz\n";
   print "\n";
   print "Perl Check Ubuntu patches plugin for Nagios\n";
   print "\n";
   print_usage();
   exit($ERRORS{OK});
}

if ($version) {
   print_revision($PROGNAME,"\$Revision: $VERSION \$");
   exit($ERRORS{OK});
}

# run the check
run_apt();

exit $ERRORS{$RET};
