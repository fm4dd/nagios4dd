#!/usr/bin/perl -w
#    
#  (c) 2008  Marc Patino Gómez (marcpatino at gmail dot com)
#            
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# you should have received a copy of the GNU General Public License
# along with this program (or with Netsaint);  if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA
#
#######################################################################
# check_asa_sessions - script for checking asa stablished sessions
# on Cisco ASA clusters using SNMP
#
# Version: 0.2
# Changelog: 
# 	2008-06-09: Initial version created
#       2015-07-03: OID fix, rewrite, new functions (support@frank4dd.com)

use strict;
use Net::SNMP;
use Getopt::Long;
use lib '/srv/app/nagios/libexec';
use utils qw (%ERRORS $TIMEOUT);

my $hostname;
my $community;
my $debug;
my $timeout;
my $check_type;
my $cluster_ip;
my $retries;
my $help;
my $warning;
my $critical;

Getopt::Long::Configure('bundling');
GetOptions (
	"help" 		=> \$help,
	"hostname=s" 	=> \$hostname,
	"community=s" 	=> \$community,
	"debug" 	=> \$debug,
	"timeout=i"	=> \$timeout,
	"retries=i"	=> \$retries,
        "type=s"	=> \$check_type,
        "cluster=s"	=> \$cluster_ip,
	"h" 		=> \$help,
	"H=s"	 	=> \$hostname,
	"C=s"	 	=> \$community,
	"d" 		=> \$debug,
	"t=i"		=> \$timeout,
        "w=s"		=> \$warning,
        "c=s"		=> \$critical,
	"r=i"		=> \$retries,
        "T=s"		=> \$check_type,
        "u=s"		=> \$cluster_ip
);

unless (defined ($debug)) {
	$debug = 0;
}
unless (defined ($timeout)) {
	$timeout = $TIMEOUT;
}
unless (defined ($retries)) {
	$retries = 1;
}
unless (defined ($retries)) {
        $check_type = "ipsec";
}

# OID's to check
my $ipsec_oid  = ".1.3.6.1.4.1.9.9.171.1.3.1.1.0"; # Cisco ASA IPSec Session count
my $sslvpn_oid = ".1.3.6.1.4.1.9.9.392.1.3.35.0"; # Cisco ASA SSL VPN count
my $webvpn_oid = ".1.3.6.1.4.1.9.9.392.1.3.38.0"; # Cisco ASA Web VPN count
my $rasvpn_oid = ".1.3.6.1.4.1.9.9.392.1.3.1.0"; #  Cisco ASA All VPN session count

# valid values
my @valid_types = ("ipsec","sslvpn","webvpn", "rasvpn");
# Session OID array
my %session_oid = ("ipsec",$ipsec_oid,"sslvpn",$sslvpn_oid,"webvpn",$webvpn_oid,"rasvpn",$rasvpn_oid);


###########################################
# sub: help
# Prints help information

sub help () {
	print <<USE;
Usage: check_asa_sessions.pl [options]
where options is
-h, --help		Print this text
-H, --hostname		Hostname (required)
-C, --community		SNMP Community (required)
-w, --warning		warning connections (required)
-c, --critical		critical connections (required)
-d, --debug		Show debug information
-t, --timeout		Timeout value in seconds (defaults to $TIMEOUT)
-r, --retries		Number of retries (defaults to 1)
-T, --type		ipsec | sslvpn | webvpn | rasvpn
-u, --cluster		add the IP addresses of the remaining VPN cluster members
			this option will count the sessions over all members
			and return the summary

Note that every retry has its own timeout value, for example,
if timeout is 15 and retries is 1, maximum timeout would be 30s.

USE
	exit ($ERRORS{OK});
};

###########################################
# sub: status_request
# The function that does the actual snmp
# requests
sub status_request () {
	my ($hostname, $community, $debug, $timeout, $retries, $check_type) = @_;

        my $count = 0;
        my $error;
        my @oidlist = $session_oid{$check_type};

	my ($session);

        # SNMPV1 login
        ($session, $error) = Net::SNMP->session(
              -hostname  => $hostname,
              -community => $community,
              -retries   => $retries,
              -timeout   => $timeout
          );

	unless ($session) {
		print "Session error: $error\n";
		exit $ERRORS{UNKNOWN};
	}
	my $result = (Net::SNMP->VERSION < 4) ?
                     $session->get_request (@oidlist)
	           : $session->get_request (-varbindlist => \@oidlist);

        if (!defined ($$result{$session_oid{$check_type}})) {
		print "UNKNOWN: Check timed out\n";
		exit ($ERRORS{UNKNOWN});
	}

       if (!defined($result)) {
           printf("ERROR: Description table : %s.\n", $session->error);
           $session->close;
           exit $ERRORS{"UNKNOWN"};
       }

        $count=$$result{$session_oid{$check_type}};
	$session->close;

	return ($count);
}

# Check command line arguments

&help () if ($help);
&help () unless ($hostname && $community);

my ($sessions) = &status_request ($hostname, $community, $debug, $timeout, $retries, $check_type);

if (defined($cluster_ip)) {
  my ($csessions) = &status_request ($cluster_ip, $community, $debug, $timeout, $retries, $check_type);
  if  ($debug) { 
    print "Primary sessions: $sessions\n";
    print "Secondary sessions: $csessions\n";
  }

  $sessions = $sessions + $csessions;
  $check_type = $check_type . " cluster";
}

# perfdata: 'label'=value[UOM];[warn];[crit];[min];[max]

my $perf = "|".$check_type."=".$sessions.";".$warning.";".$critical.";0;\n";

# Determine status against warning /crit thresholds

if ($sessions < $warning) {
	print "OK: $sessions Cisco ASA $check_type sessions".$perf;
	exit ($ERRORS{OK});
} elsif ($sessions > $warning && $sessions < $critical) {
	print "WARNING: $sessions Cisco ASA $check_type sessions".$perf; 
	exit ($ERRORS{WARNING});
} elsif ($sessions > $critical) {
	print "CRITICAL: $sessions Cisco ASA $check_type sessions".$perf; 
	exit ($ERRORS{CRITICAL});
} else {
	print "UNKNOWN: $sessions Cisco ASA $check_type sessions".$perf;
	exit ($ERRORS{UNKNOWN});
}
