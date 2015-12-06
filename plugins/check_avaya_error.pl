#!/usr/bin/perl -w 
############################# check_avaya_error #################
my $Version='1.2';
# Date:    Dec 08 2010
# Updated: Frank Migge (support at frank4dd dot com)
# Changes: Code cleanup (still not perfect), English translation
# Author:  Sascha Bay
# Help:    http://nagios.fm4dd.com/
# Licence: GPL - http://www.fsf.org/licenses/gpl.txt
#################################################################
#
# Help : ./check_avaya_error.pl -h
#

use strict;
use warnings;
use Net::SNMP;
use Getopt::Long;

# Nagios specific
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# Server alarms SNMP data per AVAYA MIB
my $svrAlarmLog         = ".1.3.6.1.4.1.6889.2.8.1.21.1.1.1"; # Serveralarms S8xxx
my $svrAlarmSource      = ".1.3.6.1.4.1.6889.2.8.1.21.1.1.2."; # Server Alarm Source
my $svrAlarmLevel       = ".1.3.6.1.4.1.6889.2.8.1.21.1.1.4."; # Server Alarm Level
my $svrAlarmAck         = ".1.3.6.1.4.1.6889.2.8.1.21.1.1.5."; # Server Alarm Ack
my $svrAlarmDate        = ".1.3.6.1.4.1.6889.2.8.1.21.1.1.6."; # Server Alarm Date
my $svrAlarmDesc        = ".1.3.6.1.4.1.6889.2.8.1.21.1.1.7."; # Server Alarm Description
# Communication Manager alarms SNMP data per AVAYA MIB
my $cmAlarmBaseOID      = ".1.3.6.1.4.1.6889.2.8.1.4.6.1";
my $cmAlarmPortOID      = ".1.3.6.1.4.1.6889.2.8.1.4.6.1.1";
my $cmAlarmIndexOID     = ".1.3.6.1.4.1.6889.2.8.1.4.6.1.2";
my $cmAlarmMaintNameOID = ".1.3.6.1.4.1.6889.2.8.1.4.6.1.3";
my $cmAlarmTypeOID      = ".1.3.6.1.4.1.6889.2.8.1.4.6.1.6";
my $cmAlarmSVCStateOID  = ".1.3.6.1.4.1.6889.2.8.1.4.6.1.7";
my $cmAlarmAckOID       = ".1.3.6.1.4.1.6889.2.8.1.4.6.1.8";
my $cmAlarmMonthOID     = ".1.3.6.1.4.1.6889.2.8.1.4.6.1.9";
my $cmAlarmDayOID       = ".1.3.6.1.4.1.6889.2.8.1.4.6.1.10";
my $cmAlarmHourOID      = ".1.3.6.1.4.1.6889.2.8.1.4.6.1.11";
my $cmAlarmMinuteOID    = ".1.3.6.1.4.1.6889.2.8.1.4.6.1.12";


# Global Data
my ($check_srv_table, $version, $continue_record, @IGNORE_MAINTNAME, @IGNORE_ALARMPORT, @cmAlarmPort, @cmAlarmIndex, @cmAlarmMaintName, @cmAlarmType, @cmAlarmSVCState, @cmAlarmAck, @cmAlarmMonth, @cmAlarmDay, @cmAlarmHour, @cmAlarmMinute);

#If we need to change a error into MAJOR then we need to put it into the array below
# i.e.: my @CHANGE_STATUS_2_MAJOR = ('UDS1-BD');
my @CHANGE_STATUS_2_MAJOR = ();

# global variables
my $o_host =    undef;          # hostname
my $o_community = undef;        # community
my $o_port =    161;            # port
my $o_help=     undef;          # wan't some help ?
my $o_verb=     undef;          # verbose mode
my $o_version=  undef;          # print version
# End compatibility
my $o_timeout=  15;          # Timeout (Default 15)
my $o_perf=     undef;          # Output performance data
my $o_version2= undef;          # use snmp v2c
# SNMPv3 specific
my $o_login=    undef;          # Login for snmpv3
my $o_passwd=   undef;          # Pass for snmpv3
my $v3protocols=undef;          # V3 protocol list.
my $o_authproto='md5';          # Auth protocol
my $o_privproto='des';          # Priv protocol
my $o_privpass= undef;          # priv password
# avaya specific variables
my $o_avaya_log = undef;
my $o_avaya_error = undef;
my $o_ignore_maintname = undef;
my $o_ignore_alarmport = undef;
my $numberErrors = 0;
my $temp_count = 0;
my $output = '';

# functions
sub p_version { print "check_avaya_error version : $Version\n"; }

sub print_usage {
    print "Usage: $0 [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>])  [-p <port>] -S <SVL|CML> -E <errorlevel> [-t <timeout>] [-V]\n";
}

sub isnnum { # Return true if arg is not a number
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
  return 1;
}

sub help {
   print "\nAvaya SNMP Error Monitor for Nagios version ",$Version,"\n";
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
-S, --service=SERVICE
   Please specify SVL (server logs) or CML (communication manager logs)
-E, --errorlevel=LEVEL
    Please specify one of the following: MAJ, MIN, WRN or CRI
-I, --ignore=(Name,Name,Name)
    ignores Maintnames (only CML), Array possible (Name,Name,Name)
-P, --alarmport=(Name,Name,Name)
    ignores Alarmports (only CML), Array possible (Name,Name,Name)
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
    'v'     => \$o_verb,            'verbose'       => \$o_verb,
    'h'     => \$o_help,            'help'          => \$o_help,
    'H:s'   => \$o_host,            'hostname:s'    => \$o_host,
    'p:i'   => \$o_port,            'port:i'        => \$o_port,
    'C:s'   => \$o_community,       'community:s'   => \$o_community,
    'l:s'   => \$o_login,           'login:s'       => \$o_login,
    'x:s'   => \$o_passwd,          'passwd:s'      => \$o_passwd,
    'X:s'   => \$o_privpass,        'privpass:s'    => \$o_privpass,
    'L:s'   => \$v3protocols,       'protocols:s'   => \$v3protocols,
    't:i'   => \$o_timeout,         'timeout:i'     => \$o_timeout,
    'V'     => \$o_version,         'version'       => \$o_version,
    '2'     => \$o_version2,        'v2c'           => \$o_version2,
    'S:s'   => \$o_avaya_log,       'service:s'     => \$o_avaya_log,
    'E:s'   => \$o_avaya_error,     'errorlevel:s'  => \$o_avaya_error,
    'i:s'   => \$o_ignore_maintname,'ignore:s'      => \$o_ignore_maintname,
    'P:s'   => \$o_ignore_alarmport,'alarmport:s'   => \$o_ignore_alarmport,
  );
  # Basic checks
  if (defined($o_timeout) && (isnnum($o_timeout) || ($o_timeout < 2) || ($o_timeout > 60)))
    { print "Timeout must be >1 and <60 !\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
  if (!defined($o_timeout)) {$o_timeout=5;}
  if (defined ($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}};
  if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}};
  # check host and filter
  if ( ! defined($o_host) ) { print_usage(); exit $ERRORS{"UNKNOWN"}}
  # check snmp information
  if ( !defined($o_community) && (!defined($o_login) || !defined($o_passwd)) )
    { print "Put snmp login info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
  if ((defined($o_login) || defined($o_passwd)) && (defined($o_community) || defined($o_version2)) )
    { print "Can't mix snmp v1,2c,3 protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
  if (defined ($v3protocols)) {
    if (!defined($o_login)) { print "Put snmp V3 login info with protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    my @v3proto=split(/,/,$v3protocols);
    if ((defined ($v3proto[0])) && ($v3proto[0] ne "")) {$o_authproto=$v3proto[0];        }       # Auth protocol
    if (defined ($v3proto[1])) {$o_privproto=$v3proto[1]; }       # Priv  protocol
    if ((defined ($v3proto[1])) && (!defined($o_privpass))) {
      print "Put snmp V3 priv login info with priv protocols!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
  }
  # Check if Service ist missing
  if (!defined $o_avaya_log) {
    printf "\nMissing argument [service]. Please specify SML | CML\n";
    exit($ERRORS{'UNKNOWN'});
  }
  # Uknown Parameter for service
  if ($o_avaya_log !~ /SVL/ && $o_avaya_log !~ /CML/) {
    printf "\nUnknown Parameter for [service]. Please specify SVL | CML\n";
    exit($ERRORS{'UNKNOWN'});
  }
  # Check if Errorlevel is missing
  if (!defined $o_avaya_error) {
    printf "\nMissing argument [errorlevel]. Please specify MAJ | MIN | WRN | CRI\n";
    exit($ERRORS{'UNKNOWN'});
  }
  # Uknown Parameter for Errorlevel
  if ($o_avaya_error !~ /MAJ/ && $o_avaya_error !~ /MIN/ && $o_avaya_error !~ /WRN/ && $o_avaya_error !~ /CRI/) {
    printf "\nUnknown Parameter for [errorlevel]. Please specify MAJ | MIN | WRN | CRI\n";
    exit($ERRORS{'UNKNOWN'});
  }
  if (defined $o_ignore_maintname) {
    if(grep /,/ , $o_ignore_maintname){
      @IGNORE_MAINTNAME = split(/,/, $o_ignore_maintname);
    }else{
      push(@IGNORE_MAINTNAME,$o_ignore_maintname);
    }
  }
  if (defined $o_ignore_alarmport) {
    if(grep /,/ , $o_ignore_alarmport){
      @IGNORE_ALARMPORT = split(/,/, $o_ignore_alarmport);
    }else{
      push(@IGNORE_ALARMPORT,$o_ignore_alarmport);
    }
  }
}

########## MAIN #######

check_options();

$SIG{'ALRM'} = sub { print "No answer from host\n"; exit $ERRORS{"UNKNOWN"};
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
      -translate    => 0,
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
     -translate => 0,
     -timeout   => $o_timeout
    );
  } else { 
    # SNMPV1 login
    verb("SNMP v1 login");
    ($session, $error) = Net::SNMP->session(
      -hostname  => $o_host,
      -community => $o_community,
      -port      => $o_port,
      -translate => 0,
      -timeout   => $o_timeout
    );
  }
}
if (!defined($session)) {
   printf("ERROR opening session: %s.\n", $error);
   exit $ERRORS{"UNKNOWN"};
}

my $exit_val=undef;
my @snmpoids; undef(@snmpoids);

############## Avaya Error check ################
my %statusCodes = ( 
  1 => "OK",
  2 => "WARNING",
  3 => "CRITICAL",
  4 => "UNKNOWN",
  WRN => "1",
  MAJ => "2",
  MIN => "2",
  WARNING => "1",
  MINOR => "2",
  MAJOR => "2");

my $exitcode = $ERRORS{"OK"};

if ($o_avaya_log eq "SVL") {
  # Serveralarms S8730
  $check_srv_table = `/usr/bin/snmpget -v 2c -c $o_community $o_host $svrAlarmLog`;

  if($check_srv_table !~ /No Such Instance currently exists at this OID/){
    $session->max_msg_size(5000);
    my $result = $session->get_table(baseoid => $svrAlarmLog);
  
    if (!defined($result)) {
      print "UNKOWN: Unable to read AVAYA Alarm status. ERROR: ". $session->error()  ."\n";
      exit $ERRORS{"UNKNOWN"};
    }
  
    my @Lines = sort(values %{$result});
    my $AnzahlErrors = @Lines;
  
    for (my $errorline = 0; $errorline < $AnzahlErrors; $errorline++) {
  
      my $svrAlarmSource = $svrAlarmSource.$errorline; # Server Alarm Source
      my $svrAlarmLevel  = $svrAlarmAck.$errorline;    # Server Alarm Level
      my $svrAlarmAck    = $svrAlarmDate.$errorline;   # Server Alarm Ack
      my $svrAlarmDate   = $svrAlarmDate.$errorline;   # Server Alarm Date
      my $svrAlarmDesc   = $svrAlarmDesc.$errorline;   # Server Alarm Description
        
      undef(@snmpoids);  
      push(@snmpoids,$svrAlarmSource);
      push(@snmpoids,$svrAlarmLevel);
      push(@snmpoids,$svrAlarmAck);
      push(@snmpoids,$svrAlarmDate);
      push(@snmpoids,$svrAlarmDesc);
      
      # Send SNMP query
      $result = $session->get_request(varbindlist => \@snmpoids);
      if (!defined($result)) {
        print "UNKOWN: Unable to read AVAYA Alarm status. ERROR: ". $session->error()  ."\n";
        exit $ERRORS{"UNKNOWN"};
      }
    
      my $AlarmSource = $result->{$svrAlarmSource};
      my $AlarmLevel  = $result->{$svrAlarmLevel};
      my $AlarmAck    = $result->{$svrAlarmAck};
      my $AlarmDate   = $result->{$svrAlarmDate};
      my $AlarmDesc   = $result->{$svrAlarmDesc};
      if($AlarmLevel eq "$o_avaya_error"){
        # Umwandeln the Errors
        if($AlarmLevel eq "WRN") {$AlarmLevel = "WARNING";}
        elsif($AlarmLevel eq "MIN") {$AlarmLevel = "CRITICAL";}
        elsif($AlarmLevel eq "MAJ") {$AlarmLevel = "CRITICAL";}
        elsif($AlarmLevel eq "CRI") {$AlarmLevel = "CRITICAL";}
        $output .= "$AlarmSource: Alarm($AlarmLevel), Date: $AlarmDate, Desc: $AlarmDesc\n";
        if ($exitcode < $statusCodes{$AlarmLevel}) { $exitcode = $statusCodes{$AlarmLevel}; }
        $numberErrors++;
      }
    }
  } else {
    verb("Server Alarms: $check_srv_table\n");
    print "UNKOWN: No OID available for Server status.\n";
    exit $ERRORS{"UNKNOWN"};
  }
} elsif ($o_avaya_log eq "CML") {
  # Umwandeln the Errors
  if($o_avaya_error eq "WRN") {$o_avaya_error = "WARNING";}
  elsif($o_avaya_error eq "MIN") {$o_avaya_error = "MINOR";}
  elsif($o_avaya_error eq "MAJ") {$o_avaya_error = "MAJOR";}
  elsif($o_avaya_error eq "CRI") {$o_avaya_error = "CRITICAL";}
  
  verb("/usr/bin/snmpbulkget -v 2c -c $o_community $o_host -Cn1 -Cr5 $cmAlarmBaseOID");
  $check_srv_table = `/usr/bin/snmpbulkget -v 2c -c $o_community $o_host -Cn1 -Cr5 $cmAlarmBaseOID`;

  if($check_srv_table !~ /No Such Object available on this agent at this OID/){
    $session->max_msg_size(5000);
    #Read the AlarmPorts
    my $temp_cmAlarmPort = $session->get_table(baseoid => $cmAlarmPortOID);
    if (!defined($temp_cmAlarmPort)) {
      print "UNKOWN: Unable to read AVAYA CM Alarm Port. ERROR: ". $session->error()  ."\n";
      exit $ERRORS{"UNKNOWN"};
    }

    foreach my $tempcmAlarmPortOID (sort keys %{$temp_cmAlarmPort}) {
      push(@cmAlarmPort, $temp_cmAlarmPort->{$tempcmAlarmPortOID});
    }

    #Read the AlarmIndex
    my $temp_cmAlarmIndex = $session->get_table(baseoid => $cmAlarmIndexOID);
    if (!defined($temp_cmAlarmIndex)) {
      print "UNKOWN: Unable to read AVAYA CM Alarm Index. ERROR: ". $session->error()  ."\n";
      exit $ERRORS{"UNKNOWN"};
    }
    
    foreach my $tempcmAlarmIndexOID (sort keys %{$temp_cmAlarmIndex}) {
       push(@cmAlarmIndex, $temp_cmAlarmIndex->{$tempcmAlarmIndexOID});
    }
     
    #Read the AlarmMaintName
    my $temp_cmAlarmMaintName = $session->get_table(baseoid => $cmAlarmMaintNameOID);
    if (!defined($temp_cmAlarmMaintName)) {
      print "UNKOWN: Unable to read AVAYA CM Alarm MaintName. ERROR: ". $session->error()  ."\n";
      exit $ERRORS{"UNKNOWN"};
    }
    
    foreach my $tempcmAlarmMaintNameOID (sort keys %{$temp_cmAlarmMaintName}) {
       push(@cmAlarmMaintName, $temp_cmAlarmMaintName->{$tempcmAlarmMaintNameOID});
    }
    
    #Read the SVCState
    my $temp_cmAlarmSVCState = $session->get_table(baseoid => $cmAlarmSVCStateOID);
    if (!defined($temp_cmAlarmSVCState)) {
      print "UNKOWN: Unable to read AVAYA CM Alarm SVCState. ERROR: ". $session->error()  ."\n";
      exit $ERRORS{"UNKNOWN"};
    }
    
    foreach my $tempcmAlarmSVCStateOID (sort keys %{$temp_cmAlarmSVCState}) {
       push(@cmAlarmSVCState, $temp_cmAlarmSVCState->{$tempcmAlarmSVCStateOID});
    }
    
    #Read the AlarmAck
    my $temp_cmAlarmAck = $session->get_table(baseoid => $cmAlarmAckOID);
    if (!defined($temp_cmAlarmAck)) {
      print "UNKOWN: Unable to read AVAYA CM Alarm AlarmAck. ERROR: ". $session->error()  ."\n";
      exit $ERRORS{"UNKNOWN"};
    }
    
    foreach my $tempcmAlarmAckOID (sort keys %{$temp_cmAlarmAck}) {
      push(@cmAlarmAck, $temp_cmAlarmAck->{$tempcmAlarmAckOID});
    }
    
    ########## Get Alarm Date and Time ##########
    #Read the AlarmMonth
    my $temp_cmAlarmMonth = $session->get_table(baseoid => $cmAlarmMonthOID);
    if (!defined($temp_cmAlarmMonth)) {
      print "UNKOWN: Unable to read AVAYA CM Alarm Month. ERROR: ". $session->error()  ."\n";
      exit $ERRORS{"UNKNOWN"};
    }
    
    foreach my $tempcmAlarmMonthOID (sort keys %{$temp_cmAlarmMonth}) {
      push(@cmAlarmMonth, $temp_cmAlarmMonth->{$tempcmAlarmMonthOID});
    }
    #Read the AlarmDay
    my $temp_cmAlarmDay = $session->get_table(baseoid => $cmAlarmDayOID);
    if (!defined($temp_cmAlarmDay)) {
      print "UNKOWN: Unable to read AVAYA CM Alarm Day. ERROR: ". $session->error()  ."\n";
      exit $ERRORS{"UNKNOWN"};
    }
    
    foreach my $tempcmAlarmDayOID (sort keys %{$temp_cmAlarmDay}) {
      push(@cmAlarmDay, $temp_cmAlarmDay->{$tempcmAlarmDayOID});
    }
    #Read the AlarmHour
    my $temp_cmAlarmHour = $session->get_table(baseoid => $cmAlarmHourOID);
    if (!defined($temp_cmAlarmHour)) {
      print "UNKOWN: Unable to read AVAYA CM Alarm Hour. ERROR: ". $session->error()  ."\n";
      exit $ERRORS{"UNKNOWN"};
    }
    
    foreach my $tempcmAlarmHourOID (sort keys %{$temp_cmAlarmHour}) {
      push(@cmAlarmHour, $temp_cmAlarmHour->{$tempcmAlarmHourOID});
    }
    #Read the AlarmMinute
    my $temp_cmAlarmMinute = $session->get_table(baseoid => $cmAlarmMinuteOID);
    if (!defined($temp_cmAlarmMinute)) {
      print "UNKOWN: Unable to read AVAYA CM Alarm Minute. ERROR: ". $session->error()  ."\n";
      exit $ERRORS{"UNKNOWN"};
    }
    
    foreach my $tempcmAlarmMinuteOID (sort keys %{$temp_cmAlarmMinute}) {
      push(@cmAlarmMinute, $temp_cmAlarmMinute->{$tempcmAlarmMinuteOID});
    }
    
    
    #Read the AlarmType
    my $temp_cmAlarmType = $session->get_table(baseoid => $cmAlarmTypeOID);
    if (!defined($temp_cmAlarmType)) {
      print "UNKOWN: Unable to read AVAYA CM Alarm AlarmType. ERROR: ". $session->error()  ."\n";
      exit $ERRORS{"UNKNOWN"};
    }
    
    foreach my $tempcmAlarmTypeOID (sort keys %{$temp_cmAlarmType}) {
      my $cmAlarmType = $temp_cmAlarmType->{$tempcmAlarmTypeOID};
      if(grep $_ eq $cmAlarmMaintName[$temp_count], @CHANGE_STATUS_2_MAJOR){
          $cmAlarmType = "MAJOR";
       }
      if($cmAlarmType eq "$o_avaya_error" && $cmAlarmIndex[$temp_count] eq "1"){
        $continue_record = 0;
        if (defined $o_ignore_maintname && grep $_ eq $cmAlarmMaintName[$temp_count], @IGNORE_MAINTNAME) {
            #print "Record MaintName ignored\n";
            $continue_record = 1;
          }
        if(defined $o_ignore_alarmport && grep $_ eq $cmAlarmPort[$temp_count], @IGNORE_ALARMPORT) {
            #print "Record Alarmport ignored\n";
            $continue_record = 1;
        }
        if($continue_record eq 0){
            $output .= "$cmAlarmType Alarmport: $cmAlarmPort[$temp_count], MaintName: $cmAlarmMaintName[$temp_count], Date: $cmAlarmDay[$temp_count].$cmAlarmMonth[$temp_count]. Time: $cmAlarmHour[$temp_count]:$cmAlarmMinute[$temp_count] ";
            if ($exitcode < $statusCodes{$cmAlarmType}) {
              $exitcode = $statusCodes{$cmAlarmType};
            }
            $numberErrors++;
          }
        }
      $temp_count++;
    }
  }
}

# -----------------------------------------------
#   Close SNMP connection and reset timeout
# -----------------------------------------------
$session->close();
alarm(0);

# -----------------------------------------------
#  Exit script in a nagios friendly way
# -----------------------------------------------
if($numberErrors eq 0 && $o_avaya_log eq "SVL") {
  print ("OK: No Avaya Server Alerts ($o_avaya_error)\n" );
  exit($ERRORS{'OK'});
}
elsif($numberErrors eq 0 && $o_avaya_log eq "CML") {
  print ("OK: No Communications Manager Alerts ($o_avaya_error)\n" );
  exit($ERRORS{'OK'});
}
else{
  print ("$statusCodes{$exitcode+1}: $output" );
  exit($exitcode);
}
