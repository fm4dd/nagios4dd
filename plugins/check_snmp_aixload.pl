#!/usr/bin/perl -w 
############################## check_snmp_load #################
my $Version='1.0';
# Date:    Mar 3 2011
# Author:  Frank Migge support[at]frank4dd.com
# Web:     http://nagios.fm4dd.com/
# Licence: GPL - http://www.fsf.org/licenses/gpl.txt
#################################################################
#
# Help : ./check_snmp_aixload.pl -h
#
# IBM's AIX OS update to TL11 SP4 breaks the SNMP load monitoring.
# All CPU load statistics are off the chart and describe a system
# load of 50% or more on a idle system. We used to query it using
# the check_snmp_load.pl plugin with -T stand that queries the
# HOSTMIB CPU load data.
#
# This program is a workaround that queries aixmibd's 
# aixSeCPUUtilization value instead.
#
# This check is based on check_snmp_load.pl v1.12 by Patrick Proy
# ( patrick at proy.org)

use strict;
use Net::SNMP;
use Getopt::Long;

# Nagios specific

my $TIMEOUT = 15;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# SNMP Datas
# AIX CPU
my $aix_cpu_oid = "1.3.6.1.4.1.2.6.191.1.2.1.0"; # AIX CPU % usage via aixmibd using aixSeCPUUtilization.0

# Globals


my $o_host = 	undef; 		# hostname
my $o_community = undef; 	# community
my $o_port = 	161; 		# port
my $o_help=	undef; 		# wan't some help ?
my $o_verb=	undef;		# verbose mode
my $o_version=	undef;		# print version
# check type  : stand | netsc |  netsl | as400 | cisco | cata | nsc | fg | bc | nokia | hp | lp  | hpux
my $o_check_type= "nokia";
# End compatibility
my $o_warn=	undef;		# warning level
my @o_warnL=	undef;		# warning levels for Linux Load or Cisco CPU
my $o_crit=	undef;		# critical level
my @o_critL=	undef;		# critical level for Linux Load or Cisco CPU
my $o_timeout=  undef; 		# Timeout (Default 5)
my $o_perf=     undef;          # Output performance data
my $o_version2= undef;          # use snmp v2c
# SNMPv3 specific
my $o_login=	undef;		# Login for snmpv3
my $o_passwd=	undef;		# Pass for snmpv3
my $v3protocols=undef;	# V3 protocol list.
my $o_authproto='md5';		# Auth protocol
my $o_privproto='des';		# Priv protocol
my $o_privpass= undef;		# priv password

# functions

sub p_version { print "check_snmp_load version : $Version\n"; }

sub print_usage {
    print "Usage: $0 [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>])  [-p <port>] -w <warn level> -c <crit level> -f -t <timeout>] [-V]\n";
}

sub isnnum { # Return true if arg is not a number
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
  return 1;
}

sub help {
   print "\nAIX SNMP CPU load Monitor for Nagios version ",$Version,"\n";
   print "GPL licence, (c)2011 Frank Migge\n\n";
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
-w, --warn=INTEGER | INT,INT,INT
   1 value check : warning level for cpu in percent (on one minute)
   3 value check : comma separated level for load or cpu for 1min, 5min, 15min 
-c, --crit=INTEGER | INT,INT,INT
   critical level for cpu in percent (on one minute)
   1 value check : critical level for cpu in percent (on one minute)
   3 value check : comma separated level for load or cpu for 1min, 5min, 15min 
-f, --perfparse
   Perfparse compatible output
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
        'h'     => \$o_help,    	'help'        	=> \$o_help,
        'H:s'   => \$o_host,		'hostname:s'	=> \$o_host,
        'p:i'   => \$o_port,   		'port:i'	=> \$o_port,
        'C:s'   => \$o_community,	'community:s'	=> \$o_community,
	'l:s'	=> \$o_login,		'login:s'	=> \$o_login,
	'x:s'	=> \$o_passwd,		'passwd:s'	=> \$o_passwd,
	'X:s'	=> \$o_privpass,	'privpass:s'	=> \$o_privpass,
	'L:s'	=> \$v3protocols,	'protocols:s'	=> \$v3protocols,   
        't:i'   => \$o_timeout,       	'timeout:i'     => \$o_timeout,
	'V'	=> \$o_version,		'version'	=> \$o_version,
	'2'     => \$o_version2,        'v2c'           => \$o_version2,
        'c:s'   => \$o_crit,            'critical:s'    => \$o_crit,
        'w:s'   => \$o_warn,            'warn:s'        => \$o_warn,
        'f'     => \$o_perf,            'perfparse'     => \$o_perf,
	);
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
    # Check for multiple warning and crit in case of -L
	if (($o_check_type eq "netsl") || ($o_check_type eq "cisco") || ($o_check_type eq "cata") || 
		($o_check_type eq "nsc") || ($o_check_type eq "hpux")) {
		@o_warnL=split(/,/ , $o_warn);
		@o_critL=split(/,/ , $o_crit);
		if (($#o_warnL != 2) || ($#o_critL != 2)) 
			{ print "3 warnings and critical !\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
		for (my $i=0;$i<3;$i++) {
			if ( isnnum($o_warnL[$i]) || isnnum($o_critL[$i])) 
				{ print "Numeric value for warning or critical !\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
			if ($o_warnL[$i] > $o_critL[$i]) 
				{ print "warning <= critical ! \n";print_usage(); exit $ERRORS{"UNKNOWN"}}
		}
	} else {
		if (($o_warn =~ /,/) || ($o_crit =~ /,/)) {
             { print "Multiple warning/critical levels not available for this check\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
		}
        if ( isnnum($o_warn) || isnnum($o_crit) ) 
			{ print "Numeric value for warning or critical !\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
		if ($o_warn > $o_crit) 
            { print "warning <= critical ! \n";print_usage(); exit $ERRORS{"UNKNOWN"}}
	}
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
		 -timeout   => $o_timeout
		);
  	} else {
	  # SNMPV1 login
	  verb("SNMP v1 login");
	  ($session, $error) = Net::SNMP->session(
		-hostname  => $o_host,
		-community => $o_community,
		-port      => $o_port,
		-timeout   => $o_timeout
	  );
	}
}
if (!defined($session)) {
   printf("ERROR opening session: %s.\n", $error);
   exit $ERRORS{"UNKNOWN"};
}

my $exit_val=undef;

################## CPU for AIX ###########
# Get load table
my @oidlist = $aix_cpu_oid;
verb("Checking OID : @oidlist");
my $resultat = (Net::SNMP->VERSION < 4) ? 
	  $session->get_request(@oidlist)
	: $session->get_request(-varbindlist => \@oidlist);
if (!defined($resultat)) {
   printf("ERROR: Description table : %s.\n", $session->error);
   $session->close;
   exit $ERRORS{"UNKNOWN"};
}
$session->close;

if (!defined ($$resultat{$aix_cpu_oid})) {
  print "No CPU information : UNKNOWN\n";
  exit $ERRORS{"UNKNOWN"};
}

my $load=$$resultat{$aix_cpu_oid};
verb("OID returned $load");
printf("CPU used %.1f%% (",$load);

$exit_val=$ERRORS{"OK"};
if ($load > $o_crit) {
 print ">$o_crit) : CRITICAL";
 $exit_val=$ERRORS{"CRITICAL"};
} else {
  if ($load > $o_warn) {
   print ">$o_warn) : WARNING";
   $exit_val=$ERRORS{"WARNING"};
  }
}
print "<$o_warn) : OK" if ($exit_val eq $ERRORS{"OK"});
(defined($o_perf)) ?
   print " | cpu_prct_used=$load%;$o_warn;$o_crit\n"
 : print "\n";
exit $exit_val;
