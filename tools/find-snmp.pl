#!/usr/bin/perl -w
# ------------------------------------------------------------ #
# find_snmp.pl v1.0 20150115 frank4dd  GPLv3                   #
#                                                              #
# This script tries to identify SNMP-systems ready for Nagios. #
# Note: ICMP ping requires root privileges for execution.      #
# ------------------------------------------------------------ #
use Net::Ping;
use Net::SNMP;

# ------------------------------------------------------------ #
# Below is the network range we will verify. This is typically #
# a class-C network, sometimes a smaller subnet range. We give #
# the values on the command line, but we could also hardcode.. #
# my $basenet = "192.168.240";                                 #
# my $start_host = 1;                                          #
# my $end_host = 25;                                           #
# ------------------------------------------------------------ #
$num_args = $#ARGV + 1;
if ($num_args < 3 || $num_args > 4) {
  print "Usage: find_snmp.pl [network-base] [start_ip] [end_ip] [optional: community]\n\n";
  print "Example: find_snmp.pl 192.168.1 20 44\n";
  print "This will run the check on these IP's: 192.168.1.20-44.\n";
  exit -1;
}

my $basenet=$ARGV[0];
my $start_host=$ARGV[1];
my $end_host=$ARGV[2];

# ------------------------------------------------------------ #
# Here we define the list of known SNMP communities for our NW #
# The longer the list, the longer the scan time (SNMP timeout) #
# ------------------------------------------------------------ #
# SECro    - SNMP string 1
# MYaccCom - CSC SNMP string
# public   - default SNMP read string
# private  - default SNMP write string

my @commlist = ("SECro", "MYaccCom", "public", "private");

# ------------------------------------------------------------ #
# If we got a commandline community arg, we add it to our list #
# ------------------------------------------------------------ #
if($ARGV[3]) {  push (@commlist, $ARGV[3]) };

# ------------------------------------------------------------ #
# We loop through IP's, and attempt a SNMP query for the name. #
# e.g. snmpget -r 1 -v 1 -c public 192.168.11.12 \             #
# SNMPv2-MIB::sysName.0 -Ov [Enter]                            #
# STRING: myfiltad01.fm4dd.com                                 #
# ------------------------------------------------------------ #
my @query_oid = ( "1.3.6.1.2.1.1.5.0" ); # SNMPv2-MIB::sysName.0 
my $port = 161;
my $timeout = 1;

my $host = $start_host;

while($host<=$end_host) {
  $ip = $basenet.".".$host;
  print "Checking $ip... ";

  # ------------------------------------------------------------ #
  # Before checking SNMP, we first ping the host if it exists.   #
  # timeout 1 second, providing a fast scan (ptimeout = 1;).     #
  # ------------------------------------------------------------ #
  my $p=Net::Ping->new('icmp');
  my $ptimeout = 1;
  if ($p->ping($ip, $ptimeout)) { print "Host $ip alive... "; }
  else {
    print "Host does not exist.\n";
    $host++;
    next;
  }
  $p->close();

  my $commcount = 1;
  for my $community (@commlist) {
    # ------------------------------------------------------------ #
    # Here we make the SNMP query and see if the device responds.  #
    # ------------------------------------------------------------ #
    # SNMPv2 Login, get a session
    ($session, $error) = Net::SNMP->session(
    -hostname  => $ip,
    -version   => 2,
    -community => $community,
    -port      => $port,
    -timeout   => $timeout
    );

    if (!defined($session)) {
      printf("SNMP response: %s.\n", $error);
      $host++;
      next;
    }

    # query the OID here
    my $result = $session->get_request(-varbindlist => \@query_oid);

    # check the result
    if (!defined($result)) {
      if ($session->error =~ m/No response from remote host/i) 
        { printf("No-SNMP(".$commcount.") "); }
      else
        { printf("SNMP err: %s.\n", $session->error); }
      $session->close;
    }
    else {
      # debug
      #print "\n".$result->{$query_oid[0]}."\n";
      print "Found: ".$result->{$query_oid[0]}." (".$community.")";
      $session->close;
      last;
    }
    $commcount++;
  }
  print "\n";
  $host++;
}
