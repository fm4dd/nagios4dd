#!/usr/bin/perl -w
############### check_apachestatus.pl #######################
# Version: 1.7
# Date:    22 April 2016 Frank4DD http://nagios.fm4dd.com/
# Author:  De Bodt Lieven (Lieven.DeBodt at gmail.com)
# Licence: GPL - http://www.fsf.org/licenses/gpl.txt
#############################################################
# 20160422 <contact at christian-lauf dot info> v1.7
#         Add parameter -u/--uri= to specify location of server-status handler
#         For system where this was changed purposely
#
# 20090514 <public at frank4dd dot com> v1.6
#          Add support for URL access through a web proxy
#          and the https (SSL) connection method.
#          http://nagios.fm4dd.com/
#
# 20090219 <public at frank4dd dot com> v1.5
#          Bugfix for unnecessary errors when server-status
#          has no "ExtendedStatus On". Now it handles both.
#
# 20081226 <public at frank4dd dot com> v1.4
#          Bugfix for bugfix below, we were still getting 
#          errors "Use of uninitialized value in printf"
#          when return =  "0 requests/sec - 0 B/second -"
#
# 20080930 <karsten at behrens dot in> v1.3
#          Fixed bug in perfdata regexp when Apache output was
#          "nnn B/sec" instead of "nnn kB/sec"
#
# 20080912 <karsten at behrens dot in> v1.2
#          added output of Requests/sec, kB/sec, kB/request  
#          changed perfdata output so that PNP accepts it
#          http://www.behrens.in/download/check_apachestatus.pl.txt
#
# help : ./check_apachestatus.pl -h

use strict;
use Getopt::Long;
use LWP::UserAgent;
use Time::HiRes qw(gettimeofday tv_interval);

# Nagios specific
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# Globals

my $Version='1.7';
my $Name=$0;

my $o_host =		undef; 		# hostname 
my $o_help=		undef; 		# want some help ?
my $o_port= 		undef; 		# port
my $o_proxyurl=		undef;          # web proxy URL
my $o_https=		undef;          # use https (SSL) instead of http
my $o_proto=		"http://";      # contains either http:// or https:// set by $o_https
my $o_version= 		undef;  	# print version
my $o_warn_level=	undef;  	# Number of available slots that will cause a warning
my $o_crit_level=	undef;  	# Number of available slots that will cause an error
my $o_timeout=  	15;            	# Default 15s Timeout
my $o_uri=             "/server-status"; # Default Apache URI

# functions

sub show_versioninfo { print "$Name version : $Version\n"; }

sub print_usage {
   print "Usage: $Name -H <host> [-p <port>] [-u <uri>] [-x <proxyurl>] [-s] [-t <timeout>] [-w <warn_level> -c <crit_level>] [-V]\n";
}

# Get the alarm signal
$SIG{'ALRM'} = sub {
  print ("ERROR: Alarm signal (Nagios time-out)\n");
  exit $ERRORS{"CRITICAL"};
};

sub help {
  print "Apache Monitor for Nagios version ",$Version,"\n";
  print "GPL licence, (c)2006-2009 Frank4DD\n\n";
  print_usage();
  print <<EOT;
-h, --help
   print this help message
-H, --hostname=HOST
   name or IP address of host to check
-p, --port=PORT
   Http port
-u, --uri=/STATUS-URI
   URI to the Serverstatus page, if changed from Apache default
-x, --proxyurl=http://proxy:port/
   URL of a proxy server, including protocol and port
-s, --https
   use https instead of http
-t, --timeout=INTEGER
   timeout in seconds (Default: $o_timeout)
-w, --warn=MIN
   number of remaining available slots that will cause a warning
   -1 for no warning
-c, --critical=MIN
   number of remaining available slots that will cause an error
-V, --version
   prints version number
Note :
  The script will return
    * Without warn and critical options:
        OK       if we are able to connect to the apache server's status page,
        CRITICAL if we aren't able to connect to the apache server's status page,,
    * With warn and critical options:
        OK       if we are able to connect to the apache server's status page and #available slots > <warn_level>,
        WARNING  if we are able to connect to the apache server's status page and #available slots <= <warn_level>,
        CRITICAL if we are able to connect to the apache server's status page and #available slots <= <crit_level>,
        UNKNOWN  if we aren't able to connect to the apache server's status page

Perfdata legend:
"_;S;R;W;K;D;C;L;G;I;.;1;2;3"
_ : Waiting for Connection
S : Starting up
R : Reading Request
W : Sending Reply
K : Keepalive (read)
D : DNS Lookup
C : Closing connection
L : Logging
G : Gracefully finishing
I : Idle cleanup of worker
. : Open slot with no current process
1 : Requests per sec
2 : kB per sec
3 : kB per Request

EOT
}

sub check_options {
  Getopt::Long::Configure ("bundling");
  GetOptions(
      'h'     => \$o_help,        'help'          => \$o_help,
      'H:s'   => \$o_host,        'hostname:s'	  => \$o_host,
      'p:i'   => \$o_port,        'port:i'	  => \$o_port,
      'u:s'   => \$o_uri,         'uri:s'         => \$o_uri,
      'x:s'   => \$o_proxyurl,    'proxyurl:s'	  => \$o_proxyurl,
      's'     => \$o_https,	  'https'	  => \$o_https,
      'V'     => \$o_version,     'version'       => \$o_version,
      'w:i'   => \$o_warn_level,  'warn:i'	  => \$o_warn_level,
      'c:i'   => \$o_crit_level,  'critical:i'	  => \$o_crit_level,
      't:i'   => \$o_timeout,     'timeout:i'     => \$o_timeout,

  );

  if (defined ($o_help)) { help(); exit $ERRORS{"UNKNOWN"}};
  if (defined($o_version)) { show_versioninfo(); exit $ERRORS{"UNKNOWN"}};
  if (((defined($o_warn_level) && !defined($o_crit_level)) || (!defined($o_warn_level) && defined($o_crit_level))) || ((defined($o_warn_level) && defined($o_crit_level)) && (($o_warn_level != -1) &&  ($o_warn_level <= $o_crit_level)))) { 
    print "Check warn and crit!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}
  }
  # Check compulsory attributes
  if (!defined($o_host)) { print_usage(); exit $ERRORS{"UNKNOWN"}};
}

########## MAIN ##########

check_options();

my $timing0 = [gettimeofday];
my $response = undef;
my $request = undef;
my $ua = LWP::UserAgent->new( protocols_allowed => ['http','https'], timeout => $o_timeout);

if (defined($o_proxyurl)) { $ua->proxy(['http'], $o_proxyurl); }

if (defined($o_https)) { 
  $o_proto = "https://";
  # proxy support is tricky for https. It needs crypt::ssleay installed
  # and only works with the https_proxy environment variable set. Omit the trailing slash!
  if (defined($o_proxyurl)) { $ENV{HTTPS_PROXY}= $o_proxyurl; }
}

if (!defined($o_port)) {
  $request = HTTP::Request->new(GET => $o_proto.$o_host.$o_uri);
} else {
  $request = HTTP::Request->new(GET => $o_proto.$o_host.':'.$o_port.$o_uri);
}

$response = $ua->request($request);
my $timeelapsed = tv_interval ($timing0, [gettimeofday]);

my $webcontent = undef;
if ($response->is_success) {
  $webcontent=$response->content;
  my @webcontentarr = split("\n", $webcontent);
  my $i = 0;
  my $BusyWorkers=undef;
  my $IdleWorkers=undef;
  # Get the amount of idle and busy workers(Apache2)/servers(Apache1)
  while (($i < @webcontentarr) && ((!defined($BusyWorkers)) || (!defined($IdleWorkers)))) {
    if ($webcontentarr[$i] =~ /(\d+)\s+requests\s+currently\s+being\s+processed,\s+(\d+)\s+idle\s+....ers/) {
      ($BusyWorkers, $IdleWorkers) = ($webcontentarr[$i] =~ /(\d+)\s+requests\s+currently\s+being\s+processed,\s+(\d+)\s+idle\s+....ers/);
    }
    $i++;
  }

  # get requests/sec, (?)b/sec, (?)b/req
  $i = 0;
  my $rPerSec=undef;
  my $rPerSecSfx=undef;
  my $bPerSec=undef;
  my $bPerSecSfx=undef;
  my $bPerReq=undef;
  my $bPerReqSfx=undef;
  while (($i < @webcontentarr) && ((!defined($rPerSec)) || (!defined($bPerSec)) || (!defined($bPerReq)))) {
    if ($webcontentarr[$i] =~ /([0-9]*\.?[0-9]+)\s([A-Za-z]+)\/sec\s-\s([0-9]*\.?[0-9]+)\s([A-Za-z]+)\/second\s-\s([0-9]*\.?[0-9]+)\s([A-Za-z]+)\/request/){
      ($rPerSec, $rPerSecSfx, $bPerSec, $bPerSecSfx, $bPerReq, $bPerReqSfx) = ($webcontentarr[$i] =~ /([0-9]*\.?[0-9]+)\s([A-Za-z]+)\/sec\s-\s([0-9]*\.?[0-9]+)\s([A-Za-z]+)\/second\s-\s([0-9]*\.?[0-9]+)\s([A-Za-z]+)\/request/);
    }
    $i++;
  }

  # Get the scoreboard
  my $ScoreBoard = "";
  $i = 0;
  my $PosPreBegin = undef;
  my $PosPreEnd = undef;
  while (($i < @webcontentarr) && ((!defined($PosPreBegin)) || (!defined($PosPreEnd)))) {
    if (!defined($PosPreBegin)) {
      if ( $webcontentarr[$i] =~ m/<pre>/i ) {
        $PosPreBegin = $i;
      }
    } 
    if (defined($PosPreBegin)) {
      if ( $webcontentarr[$i] =~ m/<\/pre>/i ) {
        $PosPreEnd = $i;
      }
    }
    $i++;
  }  
  for ($i = $PosPreBegin; $i <= $PosPreEnd; $i++) {
    $ScoreBoard = $ScoreBoard . $webcontentarr[$i];
  }
  $ScoreBoard =~ s/^.*<[Pp][Rr][Ee]>//;
  $ScoreBoard =~ s/<\/[Pp][Rr][Ee].*>//;

  my $CountOpenSlots  = ($ScoreBoard =~ tr/\.//);
  my $ConnectionWait  = 0; $ConnectionWait  = ($ScoreBoard =~ tr/\_//);
  my $ConnectionStart = 0; $ConnectionStart = ($ScoreBoard =~ tr/S//);
  my $ConnectionRead  = 0; $ConnectionRead  = ($ScoreBoard =~ tr/R//);
  my $ConnectionReply = 0; $ConnectionReply = ($ScoreBoard =~ tr/W//);
  my $ConnKeepalive   = 0; $ConnKeepalive   = ($ScoreBoard =~ tr/K//);
  my $ConnDnsLookup   = 0; $ConnDnsLookup   = ($ScoreBoard =~ tr/D//);
  my $ConnectionClose = 0; $ConnectionClose = ($ScoreBoard =~ tr/C//);
  my $ConnectionLog   = 0; $ConnectionLog   = ($ScoreBoard =~ tr/L//);
  my $ConnGraceFinish = 0; $ConnGraceFinish = ($ScoreBoard =~ tr/G//);
  my $ConnIdleCleanup = 0; $ConnIdleCleanup = ($ScoreBoard =~ tr/I//);


# finished data gathering, preparing the data output
my $output = " $timeelapsed seconds response time. Idle $IdleWorkers, busy $BusyWorkers, open slots $CountOpenSlots";
# add the performance data separator
  $output = $output." | ";
# add the performance data
  $output = $output."'Waiting for Connection'=$ConnectionWait 'Starting Up'=$ConnectionStart 'Reading Request'=$ConnectionRead ";
  $output = $output."'Sending Reply'=$ConnectionReply 'Keepalive (read)'=$ConnKeepalive 'DNS Lookup'=$ConnDnsLookup ";
  $output = $output."'Closing Connection'=$ConnectionClose 'Logging'=$ConnectionLog 'Gracefully finishing'=$ConnGraceFinish ";
  $output = $output."'Idle cleanup'=$ConnIdleCleanup 'Open slot'=$CountOpenSlots";

# check if server-status has "ExtendedStatus On" output available
  if( defined($rPerSec) && defined($rPerSecSfx) && defined($bPerSec)
   && defined($bPerSecSfx) && defined($bPerReq) && defined($bPerReqSfx) ) {
    $output = sprintf("%s 'Requests/sec'=%0.1f '%s per sec'=%0.1f%s '%s per Request'=%0.1f%s\n",
                       $output, $rPerSec, $bPerSecSfx, $bPerSec, $bPerSecSfx, $bPerReqSfx, $bPerReq, $bPerReqSfx);
  } else {
    $output = $output."\n";
  }

  if (defined($o_crit_level) && ($o_crit_level != -1)) {
    if (($CountOpenSlots + $IdleWorkers) <= $o_crit_level) {
      print "CRITICAL ".$output;
      exit $ERRORS{"CRITICAL"}
    }
  } 
  if (defined($o_warn_level) && ($o_warn_level != -1)) {
    if (($CountOpenSlots + $IdleWorkers) <= $o_warn_level) {
      print "WARNING ".$output;
      exit $ERRORS{"WARNING"}
    }
  }
  print "OK ".$output;
      exit $ERRORS{"OK"}
}
else {
  if (defined($o_warn_level) || defined($o_crit_level)) {
    printf("UNKNOWN %s\n", $response->status_line);
    exit $ERRORS{"UNKNOWN"}
  } else {
    printf("CRITICAL %s\n", $response->status_line);
    exit $ERRORS{"CRITICAL"}
  }
}
