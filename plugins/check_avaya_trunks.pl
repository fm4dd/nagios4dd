#!/usr/bin/perl -w 
############################## check_avaya_trunks #################
my $Version='1.0';
# Date:    Dec 08 2010
# Author:  Frank Migge (support at frank4dd dot com)
# Help:    http://nagios.fm4dd.com/
# Licence: GPL - http://www.fsf.org/licenses/gpl.txt
#################################################################
#
# Help : ./check_avaya_trunks.pl -h
#

use strict;
use Net::SNMP;
use Getopt::Long;

# Nagios specific

my $TIMEOUT = 15;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# SNMP Data
# g3trunkstaTable        1.3.6.1.4.1.6889.2.8.1.14.1 
# g3trunkstaEntry        1.3.6.1.4.1.6889.2.8.1.14.1.1.1 (G3-AVAYA-MIB::g3trunkstaTrunkGroup.1.1)
# g3trunkstaServiceState 1.3.6.1.4.1.6889.2.8.1.14.1.1.3
my $trunk_table_entries="1.3.6.1.4.1.6889.2.8.1.14.1.1.1";
my $trunk_table_enstate="1.3.6.1.4.1.6889.2.8.1.14.1.1.3";

# Globals
my $o_host = 	undef; 		# hostname
my $o_community = undef; 	# community
my $o_port = 	161; 		# port
my $o_help=	undef; 		# wan't some help ?
my $o_verb=	undef;		# verbose mode
my $o_version=	undef;		# print version
my $o_tgn=      undef;          # plugin specific: trunk group number to query
# End compatibility
my $o_warn=	undef;		# warning level
my $o_crit=	undef;		# critical level
my $o_timeout=  undef; 		# Timeout (Default 5)
my $o_version2= undef;          # use snmp v2c
# SNMPv3 specific
my $o_login=	undef;		# Login for snmpv3
my $o_passwd=	undef;		# Pass for snmpv3
my $v3protocols=undef;	        # V3 protocol list.
my $o_authproto='md5';		# Auth protocol
my $o_privproto='des';		# Priv protocol
my $o_privpass= undef;		# priv password

# functions

sub p_version { print "check_avaya_trunks version : $Version\n"; }

sub print_usage {
    print "Usage: $0 [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>])  [-p <port>] -T <trunkgroup number> -w <warn level> -c <crit level> [-f] [-t <timeout>] [-V]\n";
}

sub isnnum { # Return true if arg is not a number
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
  return 1;
}

sub help {
   print "\nAvaya SNMP Trunk Utilization Monitor for Nagios version ",$Version,"\n";
   print "GPL licence, (c)2010 Frank Migge\n\n";
   print_usage();
   print <<EOT;
-v, --verbose
   print extra debugging information 
-h, --help
   print this help message
-H, --hostname=HOST
   name or IP address of host to check
-C, --community=COMMUNITY NAME
   community name for the host's SNMP agent (implies v1 protocol)
-2, --v2c
   Use snmp v2c
-l, --login=LOGIN ; -x, --passwd=PASSWD
   Login and auth password for snmpv3 authentication 
   If no priv password exists, implies AuthNoPriv 
-X, --privpass=PASSWD
   Priv password for snmpv3 (AuthPriv protocol)
-L, --protocols=<authproto>,<privproto>
   <authproto> : Authentication protocol (md5|sha : default md5)
   <privproto> : Priv protocole (des|aes : default des) 
-P, --port=PORT
   SNMP port (Default 161)
-w, --warn=INTEGER
   warning level for cpu in percent
-c, --crit=INTEGER
   critical level for cpu in percent
-T, --trunkgroup
   this is the Avaya trunk group number to monitor
-t, --timeout=INTEGER
   timeout for SNMP in seconds (Default: 5)
-V, --version
   prints version number
EOT
}

# For verbose output
sub verb { my $t=shift; print $t,"\n" if defined($o_verb) ; }

sub check_options {
  Getopt::Long::Configure ("bundling");
  GetOptions(
  'v'	=> \$o_verb,		'verbose'	=> \$o_verb,
  'h'   => \$o_help,    	'help'        	=> \$o_help,
  'H:s' => \$o_host,		'hostname:s'	=> \$o_host,
  'p:i' => \$o_port, 		'port:i'	=> \$o_port,
  'C:s' => \$o_community,	'community:s'	=> \$o_community,
  'l:s'	=> \$o_login,		'login:s'	=> \$o_login,
  'x:s'	=> \$o_passwd,		'passwd:s'	=> \$o_passwd,
  'X:s'	=> \$o_privpass,	'privpass:s'	=> \$o_privpass,
  'L:s'	=> \$v3protocols,	'protocols:s'	=> \$v3protocols,   
  't:i' => \$o_timeout,		'timeout:i'     => \$o_timeout,
  'V'	=> \$o_version,		'version'	=> \$o_version,
  '2'   => \$o_version2,	'v2c'           => \$o_version2,
  'c:s' => \$o_crit,		'critical:s'    => \$o_crit,
  'w:s' => \$o_warn,		'warn:s'        => \$o_warn,
  'T:i' => \$o_tgn,		'trunkgroup'    => \$o_tgn,);
  # Basic checks
  if (defined($o_timeout) && (isnnum($o_timeout) || ($o_timeout < 2) || ($o_timeout > 60))) 
    { print "Timeout must be >1 and <60 !\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
  if (!defined($o_timeout)) {$o_timeout=5;}
  if (defined ($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}};
  if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}};
  if ( ! defined($o_host) ) # check host and filter 
  { print_usage(); exit $ERRORS{"UNKNOWN"}}
  # check snmp information
  if ( !defined($o_community) && (!defined($o_login) || !defined($o_passwd)) )
    { print "Put snmp login info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
  if ((defined($o_login) || defined($o_passwd)) && (defined($o_community) || defined($o_version2)) )
    { print "Can't mix snmp v1,2c,3 protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
  if (defined ($v3protocols)) {
    if (!defined($o_login)) { print "Put snmp V3 login info with protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    my @v3proto=split(/,/,$v3protocols);
    if ((defined ($v3proto[0])) && ($v3proto[0] ne "")) {$o_authproto=$v3proto[0];	}	# Auth protocol
    if (defined ($v3proto[1])) {$o_privproto=$v3proto[1];	}	# Priv  protocol
    if ((defined ($v3proto[1])) && (!defined($o_privpass))) {
      print "Put snmp V3 priv login info with priv protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
  }
  # Check warnings and critical
  if (!defined($o_warn) || !defined($o_crit))
    { print "put warning and critical info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
  # Get rid of % sign
  $o_warn =~ s/\%//g; 
  $o_crit =~ s/\%//g;
  if ( isnnum($o_warn) || isnnum($o_crit) ) 
    { print "Numeric value for warning or critical !\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
  if ($o_warn > $o_crit) 
    { print "warning <= critical ! \n";print_usage(); exit $ERRORS{"UNKNOWN"}}
  if (!defined($o_tgn)) { print "missing Avaya trunk group number!\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
}

########## MAIN #######

check_options();

# Check gobal timeout if snmp screws up
if (defined($TIMEOUT)) {
  verb("Alarm at $TIMEOUT + 5");
  alarm($TIMEOUT+5);
} else {
  verb("no global timeout defined : $o_timeout + 10");
  alarm ($o_timeout+10);
}

$SIG{'ALRM'} = sub {
 print "No answer from host\n";
 exit $ERRORS{"UNKNOWN"};
};

# Connect to host
my ($session,$error);
if ( defined($o_login) && defined($o_passwd)) {
  # SNMPv3 login
  verb("SNMPv3 login");
    if (!defined ($o_privpass)) {
  verb("SNMPv3 AuthNoPriv login : $o_login, $o_authproto");
    ($session, $error) = Net::SNMP->session(
      -hostname   	=> $o_host,
      -version		=> '3',
      -username		=> $o_login,
      -authpassword	=> $o_passwd,
      -authprotocol	=> $o_authproto,
      -timeout          => $o_timeout
    );  
  } else {
    verb("SNMPv3 AuthPriv login : $o_login, $o_authproto, $o_privproto");
    ($session, $error) = Net::SNMP->session(
      -hostname   	=> $o_host,
      -version		=> '3',
      -username		=> $o_login,
      -authpassword	=> $o_passwd,
      -authprotocol	=> $o_authproto,
      -privpassword	=> $o_privpass,
	  -privprotocol => $o_privproto,
      -timeout          => $o_timeout
    );
  }
} else {
  if (defined ($o_version2)) {
    # SNMPv2 Login
    verb("SNMP v2c login");
    ($session, $error) = Net::SNMP->session(
  	 -hostname  => $o_host,
  	 -version   => 2,
  	 -community => $o_community,
  	 -port      => $o_port,
  	 -timeout   => $o_timeout);
  } else {
    # SNMPV1 login
    verb("SNMP v1 login");
    ($session, $error) = Net::SNMP->session(
  	-hostname  => $o_host,
  	-community => $o_community,
  	-port      => $o_port,
  	-timeout   => $o_timeout);
  }
}

if (!defined($session)) {
   printf("ERROR opening session: %s.\n", $error);
   exit $ERRORS{"UNKNOWN"};
}

my $exit_val=undef;

############## Avaya trunks check ################

my $raw_trunk_array = $session->get_entries(-columns => [$trunk_table_entries]);

if (! $raw_trunk_array) {
   printf("ERROR: Description table : %s.\n", $session->error);
   $session->close;
   exit $ERRORS{"UNKNOWN"};
}

my $raw_channel_status = $session->get_entries(-columns => [$trunk_table_enstate]);

if (!defined($raw_channel_status)) {
   printf("ERROR: Description table : %s.\n", $session->error);
   $session->close;
   exit $ERRORS{"UNKNOWN"};
}

$session->close;

# Start working with the data
my $num_channels = keys %$raw_trunk_array;
my $trunks         = 0; # Incrementer for trunks
my $channels       = 1; # Incrementer for channels
my $channels_busy  = 0; # Incrementer for channels in use
my $total_busy     = 0; # Incrementer for channels in use
my $channels_total = 0; # Incrementer for channels total
my $trunk_group    = 0; # trunk group number

foreach my $key (sort (keys(%$raw_trunk_array))) {
  #print "Test1: $key = $raw_trunk_array->{$key}\n";
  if ($trunk_group != $raw_trunk_array->{$key}) {
    if($trunk_group) {
      verb("Trunk $trunks: TGN $trunk_group, $channels channels, $channels_busy active.");
      if ($trunk_group == $o_tgn) { last; }
    }
    $channels_busy=0;
    $channels=1;
    $trunks++;
    $trunk_group = $raw_trunk_array->{$key};
    substr($key,30,1,"3");
    if($raw_channel_status->{$key} eq "in-service/active") { $channels_busy++; $total_busy++; }
  }
  else {
    $channels++;
    # check if trunk channel is idle or active
    # key is: 1.3.6.1.4.1.6889.2.8.1.14.1.1.1.991.8
    substr($key,30,1,"3");
    # print "Test1: $key = $raw_channel_status->{$key}\n";
    if($raw_channel_status->{$key} eq "in-service/active") { $channels_busy++; $total_busy++; }
  }
  $channels_total++;
}
verb("Trunk $trunks: TGN $trunk_group $channels channels, $channels_busy active.");
verb("Avaya system $o_host has $trunks trunks with $total_busy/$channels_total active channels.");


print "Avaya Trunk TGN $trunk_group - $channels_busy of $channels channels active:";

$exit_val=$ERRORS{"OK"};
if ( $channels_busy > $o_crit ) {
   print " $channels_busy > $o_crit : CRITICAL";
   $exit_val=$ERRORS{"CRITICAL"};
  }
if ( $channels_busy > $o_warn ) {
   # output warn error only if no critical was found
   if ($exit_val eq $ERRORS{"OK"}) {
     print " $channels_busy > $o_warn : WARNING"; 
     $exit_val=$ERRORS{"WARNING"};
   }
}
print " OK" if ($exit_val eq $ERRORS{"OK"});
print "\n";
exit $exit_val;
