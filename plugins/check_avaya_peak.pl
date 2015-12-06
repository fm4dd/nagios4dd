#!/usr/bin/perl -w 
############################## check_avaya_peak #################
my $Version='1.0';
# Date:    Dec 08 2010
# Author:  Frank Migge (support at frank4dd dot com)
# Help:    http://nagios.fm4dd.com/
# Licence: GPL - http://www.fsf.org/licenses/gpl.txt
#################################################################
#
# Help : ./check_avaya_peak.pl -h
#
# Avaya S8xxx media servers provide call peak information through 
# Avaya's SNMP agents g3-mib for data, voice, srv, media and
# overall peak values. These are collected in hourly periods,
# so the published data is always refering to the last hour as
# their reference. The peak values available seem to be the
# concurrent number of calls measured per second, and the total.
# This plugin queries last hours peak values and compares them
# against warning and critical thresholds from one of these rate
# groups:
#
# g3callratedata
# g3callratevoice
# g3callratesrv
# g3callratemedia
# g3callratetotal
#
# The data is most useful for graphing to identify trends in
# usage, together with the trunk group call monitoring plugin.
# Without graphing, the plugin needs to run only once per hour,
# but for graphing we want to get data in 5 minute intervals.
# We can graph the concurrency peak or the total calls per hour.
#################################################################


use strict;
use Net::SNMP;
use Getopt::Long;

# Nagios specific

my $TIMEOUT = 15;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# SNMP base OID's for Avaya's G3 call rate data
my $g3callratedata  = "1.3.6.1.4.1.6889.2.8.1.110";
my $g3callratevoice = "1.3.6.1.4.1.6889.2.8.1.111";
my $g3callratesrv   = "1.3.6.1.4.1.6889.2.8.1.112";
my $g3callratemedia = "1.3.6.1.4.1.6889.2.8.1.113";
my $g3callratetotal = "1.3.6.1.4.1.6889.2.8.1.114";

# per selection, this will hold the selected base oid
my $g3callrate_baseoid = undef;

my $tretrieve       = "4.0"; # base oid appendix to get data about the peak rate cache health
# The timeperiod the peak data was generated in (hour)
# this is the only place we get the date, further
# data is only presenting the time
my $runyear         = "5.0"; # year,  i.e. 2010
my $runmonth        = "6.0"; # month, i.e. 12
my $runday          = "7.0"; # day,   i.e. 10
my $runhour         = "8.0"; # hour,  i.e. 12

# Todays last hour peaks, i.e.  11:16:12 = 14 calls (688 calls/hr)
my $meashour        = "9.0";  # The start hour in HHMM, i.e. 1100
my $numcalls        = "10.0"; # last hours total number of calls
my $bsyinthr        = "11.0"; # last hours peak time: hour, i.e. 11
my $bsyintmn        = "12.0"; # last hours peak time: mins, i.e. 16
my $bsyintsc        = "13.0"; # last hours peak time: secs, i.e. 12
my $bsycallcmpl     = "14.0"; # last hours 1sec peak value, i.e. 14

# variables holding the data returned by SNMP
my $tretrieveflag   = "0"; # returns 1=failed (cache corrupted crit), 2=update(in progress unknown) or 3=current (OK)
my $runyeardata     = "0"; # year,  i.e. 2010
my $runmonthdata    = "0"; # month, i.e. 12
my $rundaydata      = "0"; # day,   i.e. 10
my $runhourdata     = "0"; # hour,  i.e. 12
my $meashourdata    = "0"; # The start hour in HHMM, i.e. 1100
my $numcallsdata    = "0"; # last hours total number of calls
my $bsyinthrdata    = "0"; # last hours peak time: hour, i.e. 11
my $bsyintmndata    = "0"; # last hours peak time: mins, i.e. 16
my $bsyintscdata    = "0"; # last hours peak time: secs, i.e. 12
my $bsycallcmpldata = "0"; # last hours 1sec peak value, i.e. 14

my $peakdata        = "0";   # the peak data we are trying to get

# Globals
my $o_host          = undef; # hostname
my $o_community     = undef; # community
my $o_port          = 161;   # port
my $o_help          = undef; # wan't some help ?
my $o_verb          = undef; # verbose mode
my $o_version       = undef; # print version
my $o_ratetype      = undef; # plugin specific: data|voice|srv|media|total
my $o_peaktype      = undef; # plugin specific: concur|total
# End compatibility
my $o_warn          = undef; # warning level
my $o_crit          = undef; # critical level
my $o_timeout       = undef; # Timeout (Default 5)
my $o_perf          = undef; # Output performance data
my $o_version2      = undef; # use snmp v2c
# SNMPv3 specific
my $o_login         = undef; # Login for snmpv3
my $o_passwd        = undef; # Pass for snmpv3
my $v3protocols     = undef; # V3 protocol list.
my $o_authproto     ='md5';  # Auth protocol
my $o_privproto     ='des';  # Priv protocol
my $o_privpass      = undef; # priv password

# functions
sub p_version { print "check_avaya_trunks version : $Version\n"; }

sub print_usage {
    print "Usage: $0 [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>])  [-p <port>] -P <rate type> -R <peak type> -w <warn level> -c <crit level> [-f] [-t <timeout>] [-f] [-V]\n";
}

sub isnnum { # Return true if arg is not a number
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
  return 1;
}

sub help {
   print "\nAvaya SNMP Call Peak Monitor for Nagios version ",$Version,"\n";
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
-p, --port=PORT
   SNMP port (Default 161)
-w, --warn=INTEGER
   warning level for cpu in percent
-c, --crit=INTEGER
   critical level for cpu in percent
-R, --ratetype=<type>
   select which rate typt to query, valid types are: data|voice|srv|media|total
-P, --peaktype=<type>
   select which peak type to query, valid types are: concur or total
-t, --timeout=INTEGER
   timeout for SNMP in seconds (Default: 5)
-f, --perfparse
   add additional performance data output
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
  'f'   => \$o_perf,            'perfparse'     => \$o_perf,
  'V'	=> \$o_version,		'version'	=> \$o_version,
  '2'   => \$o_version2,	'v2c'           => \$o_version2,
  'c:s' => \$o_crit,		'critical:s'    => \$o_crit,
  'w:s' => \$o_warn,		'warn:s'        => \$o_warn,
  'R:s' => \$o_ratetype,	'ratetype:s'    => \$o_ratetype,
  'P:s' => \$o_peaktype,	'peaktype:s'    => \$o_peaktype);
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
  # Check if we got warnings and critical
  if (!defined($o_warn) || !defined($o_crit))
    { print "put warning and critical info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
  # Check if warnings and critical are numbers
  if ( isnnum($o_warn) || isnnum($o_crit) ) 
    { print "Numeric value for warning or critical !\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
  # warnings should be smaller then critical
  if ($o_warn > $o_crit) 
    { print "warning <= critical ! \n";print_usage(); exit $ERRORS{"UNKNOWN"}}

  # Check if we got the rate type
  if (!defined($o_ratetype)) { print "missing Avaya rate type!\n";print_usage(); exit $ERRORS{"UNKNOWN"}}

  # set the base oid based on the rate type
  if ($o_ratetype eq "data")  { $g3callrate_baseoid = $g3callratedata; }
  elsif ($o_ratetype eq "voice") { $g3callrate_baseoid = $g3callratevoice; }
  elsif ($o_ratetype eq "srv")   { $g3callrate_baseoid = $g3callratesrv; }
  elsif ($o_ratetype eq "media") { $g3callrate_baseoid = $g3callratemedia; }
  elsif ($o_ratetype eq "total") { $g3callrate_baseoid = $g3callratetotal; }
  else { print "Invalid rate type! Valid types are: data voice srv media total\n";print_usage(); exit $ERRORS{"UNKNOWN"}}

  # Check if we got the peak type
  if (!defined($o_peaktype)) { print "missing Avaya peak type!\n";print_usage(); exit $ERRORS{"UNKNOWN"}}

  # Check if the peak type has valid strings
  if (($o_peaktype ne "concur") && ($o_peaktype ne "total"))
    { print "Invalid peak type! Valid types are: concur or total\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
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
      -hostname     => $o_host,
      -version      => '3',
      -username     => $o_login,
      -authpassword => $o_passwd,
      -authprotocol => $o_authproto,
      -timeout      => $o_timeout
    );  
  } else {
    verb("SNMPv3 AuthPriv login : $o_login, $o_authproto, $o_privproto");
    ($session, $error) = Net::SNMP->session(
      -hostname     => $o_host,
      -version      => '3',
      -username     => $o_login,
      -authpassword => $o_passwd,
      -authprotocol => $o_authproto,
      -privpassword => $o_privpass,
      -privprotocol => $o_privproto,
      -timeout      => $o_timeout
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
my @snmpoids; undef(@snmpoids);

############## Avaya peaks check ################

# create the OID list
my $g3callrate_tretrieve    = $g3callrate_baseoid . "." . $tretrieve;
my $g3callrate_runyear      = $g3callrate_baseoid . "." . $runyear;
my $g3callrate_runmonth     = $g3callrate_baseoid . "." . $runmonth;
my $g3callrate_runday       = $g3callrate_baseoid . "." . $runday;
my $g3callrate_runhour      = $g3callrate_baseoid . "." . $runhour;
my $g3callrate_meashour     = $g3callrate_baseoid . "." . $meashour;
my $g3callrate_numcalls     = $g3callrate_baseoid . "." . $numcalls;
my $g3callrate_bsyinthr     = $g3callrate_baseoid . "." . $bsyinthr;
my $g3callrate_bsyintmn     = $g3callrate_baseoid . "." . $bsyintmn;
my $g3callrate_bsyintsc     = $g3callrate_baseoid . "." . $bsyintsc;
my $g3callrate_bsycallcmpl  = $g3callrate_baseoid . "." . $bsycallcmpl;

# populate the OID array to fetch
undef(@snmpoids);
push(@snmpoids,$g3callrate_tretrieve);
push(@snmpoids,$g3callrate_runyear);
push(@snmpoids,$g3callrate_runmonth);
push(@snmpoids,$g3callrate_runday);
push(@snmpoids,$g3callrate_runhour);
push(@snmpoids,$g3callrate_meashour);
push(@snmpoids,$g3callrate_numcalls);
push(@snmpoids,$g3callrate_bsyinthr);
push(@snmpoids,$g3callrate_bsyintmn);
push(@snmpoids,$g3callrate_bsyintsc);
push(@snmpoids,$g3callrate_bsycallcmpl);

my $peak_array = (Net::SNMP->VERSION < 4) ?
          $session->get_request(\@snmpoids)
        : $session->get_request(-varbindlist => \@snmpoids);

if (! $peak_array) { 
   printf("ERROR: getting SNMP data : %s.\n", $session->error);
   $session->close;
   exit $ERRORS{"UNKNOWN"};
}

$session->close;

# sort out the returned SNMP data
foreach my $key (keys(%$peak_array)) {
  verb("SNMP data: $key = $peak_array->{$key}");
  if($key =~ $g3callrate_tretrieve)   { $tretrieveflag   = $peak_array->{$key}; }
  if($key =~ $g3callrate_runyear)     { $runyeardata     = $peak_array->{$key}; }
  if($key =~ $g3callrate_runmonth)    { $runmonthdata    = $peak_array->{$key}; }
  if($key =~ $g3callrate_runday)      { $rundaydata      = $peak_array->{$key}; }
  if($key =~ $g3callrate_runhour)     { $runhourdata     = $peak_array->{$key}; }
  if($key =~ $g3callrate_meashour)    { $meashourdata    = $peak_array->{$key}; }
  if($key =~ $g3callrate_numcalls)    { $numcallsdata    = $peak_array->{$key}; }
  if($key =~ $g3callrate_bsyinthr)    { $bsyinthrdata    = $peak_array->{$key}; }
  if($key =~ $g3callrate_bsyintmn)    { $bsyintmndata    = $peak_array->{$key}; }
  if($key =~ $g3callrate_bsyintsc)    { $bsyintscdata    = $peak_array->{$key}; }
  if($key =~ $g3callrate_bsycallcmpl) { $bsycallcmpldata = $peak_array->{$key}; }
}

if($tretrieveflag == 1) { # failed (cache corrupted, crit)
  print "Avaya peaks for $o_ratetype - data cache is corrupted : CRITICAL\n";
  exit $ERRORS{"CRITICAL"};
}
if($tretrieveflag == 2) { # update (in progress, unknown)
  print "Avaya peaks for $o_ratetype - data update is in progress : UNKKNOWN\n";
  exit $ERRORS{"UNKNOWN"};
}
if($tretrieveflag == 3) { # data is current (OK)
  
  if($o_peaktype eq "concur") { $peakdata = $bsycallcmpldata; }
  elsif($o_peaktype eq "total") { $peakdata = $numcallsdata; }

  print "Avaya peaks for '$o_ratetype' at $meashourdata - $peakdata $o_peaktype calls";
  $exit_val=$ERRORS{"OK"};

  if ( $peakdata > $o_crit ) {
    print " $peakdata > $o_crit : CRITICAL";
    $exit_val=$ERRORS{"CRITICAL"};
  }

  if ( $peakdata > $o_warn ) {
    # output warn error only if no critical was found
    if ($exit_val eq $ERRORS{"OK"}) {
      print " $peakdata > $o_warn : WARNING"; 
      $exit_val=$ERRORS{"WARNING"};
    }
  }
}
print " : OK" if ($exit_val eq $ERRORS{"OK"});
if (defined($o_perf)) {
   print " | peakdata=$peakdata peaktype=$o_peaktype ratetype=$o_ratetype peaktime=$bsyinthrdata:$bsyintmndata:$bsyintscdata";
}
print "\n";
exit $exit_val;
