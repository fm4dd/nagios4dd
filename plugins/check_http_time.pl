#!/usr/bin/perl -w 
############################## check_snmp_time.pl #################
my $Version='1.0';
# Date    : Dec 08 2010
# Purpose : Nagios plugin to check the time on a server using http.\n";
# Author  : Frank Migge (support at frank4dd dot com)
# Help    : http://nagios.fm4dd.com/
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt
#################################################################
#
# Help : ./check_snmp_time.pl -h
#
# This plugin queries the remote systems time through a web server and
# compares it against the local time of the Nagios server. This identifies
# systems with incorrect time and sends alarms if the time is off to far.
#
use strict;
use Getopt::Long;
use LWP::UserAgent;
use Time::HiRes qw(gettimeofday tv_interval);
use Date::Format;

# Nagios specific
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# Globals
my $Name=$0;
my $o_checkurl  = undef; # url to check for
my $o_proxyurl  = undef; # web proxy URL
my $o_proxyuser = undef; # web proxy auth user id
my $o_proxypass = undef; # web proxy auth password
my $o_help      = undef; # wan't some help ?
my $o_verb      = undef; # verbose mode
my $o_version   = undef; # print version
my $o_warn      = undef; # warning level in seconds
my $o_crit      = undef; # critical level in seconds
my $o_timeout   = undef; # Timeout (Default 5)
my $o_perf      = undef; # Output performance data
my $exit_val    = undef;

# functions
sub p_version { print "check_snmp_time version : $Version\n"; }

sub print_usage {
    print "Usage: $0 [-v] -d <checkurl> [-x <proxyurl>] [-u <proxyuser> -p <proxypass>] -w <warn level> -c <crit level> [-f] [-t <timeout>] [-V]\n";
}

sub isnnum { # Return true if arg is not a number
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$|^-(\d+\.?\d*)|(^-\.\d+)$/ ) { return 0 ;}
  return 1;
}

sub help {
   print "\nRemote HTTP System Time Monitor for Nagios version ",$Version,"\n";
   print "GPL licence, (c) 2010 Frank4DD\n\n";
   print_usage();
   print <<EOT;

This plugin queries the remote systems time through HTTP and compares it against the local time of the Nagios server. This identifies systems with no correct time set and sends alarms if the time is off to far.

-v, --verbose
   print extra debugging information 
-h, --help
   print this help message
-d, --checkurl=<http://xxx.yy.zz>
   web URL of the system to check time against
-x, --proxyurl=<http://xxx.yy.zz>
   proxy server URL to use if needed
-u, --proxyuser=<proxy auth userid>
   if the proxy server requires authentication, proxy user ID
-p, --proxypass=<password>
   if the proxy server requires authentication, the proxy users password
-w, --warn=INTEGER
   warning level for time difference in seconds
-c, --crit=INTEGER
   critical level for time difference in seconds
-f, --perfparse
   Perfparse compatible output
-t, --timeout=INTEGER
   HTTP timeout in seconds (Default: 5)
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
        'd:s'   => \$o_checkurl,        'checkurl:s'    => \$o_checkurl,
        'x:s'   => \$o_proxyurl,        'proxyurl:s'    => \$o_proxyurl,
        'u:s'   => \$o_proxyuser,       'proxyuser:s'   => \$o_proxyuser,
        'p:s'   => \$o_proxypass,       'proxypass:s'   => \$o_proxypass,
        'w:s'   => \$o_warn,            'warn:s'        => \$o_warn,
        'c:s'   => \$o_crit,            'critical:s'    => \$o_crit,
        'f'     => \$o_perf,            'perfparse'     => \$o_perf,
        't:i'   => \$o_timeout,       	'timeout:i'     => \$o_timeout,
        'V'     => \$o_version,         'version'       => \$o_version,
	);
    # Basic checks
    if (defined($o_timeout) && (isnnum($o_timeout) || ($o_timeout < 2) || ($o_timeout > 60))) 
      { print "Timeout must be >1 and <60 !\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    if (!defined($o_timeout)) {$o_timeout=5;}
    if (defined ($o_help) ) { help(); exit $ERRORS{"UNKNOWN"}};
    if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}};
    if (defined($o_proxyuser) && !defined($o_proxypass)) 
        { print "Setting the proxy user name requires to set the password.\n"; print_usage(); exit $ERRORS{"UNKNOWN"}};
    # Check warnings and critical
    if (!defined($o_warn) || !defined($o_crit))
 	{ print "put warning and critical info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
    if ( isnnum($o_warn) || isnnum($o_crit) ) 
	{ print "Numeric value for warning or critical !\n";print_usage(); exit $ERRORS{"UNKNOWN"}}
    if ($o_warn > $o_crit) 
        { print "warning <= critical ! \n";print_usage(); exit $ERRORS{"UNKNOWN"}}
    if (!defined($o_checkurl)) { print_usage(); exit $ERRORS{"UNKNOWN"}};
}

########## MAIN #######
check_options();

$SIG{'ALRM'} = sub {
 print "No answer from host\n";
 exit $ERRORS{"UNKNOWN"};
};

# Prepare the HTTP session
my $ua = LWP::UserAgent->new;
$ua->agent("check_http_time/$Version");
$ua->timeout($o_timeout);
$ua->env_proxy;
$ua->max_redirect(1); # do not follow redirects

# prepare the HTTP request header
my $req = HTTP::Request->new(HEAD => $o_checkurl );

# set proxy if requested
if (defined($o_proxyurl)) { $ua->proxy(['http'], $o_proxyurl); }

# set proxy authentication, if applicable
$req->proxy_authorization_basic ( $o_proxyuser, $o_proxypass ) if ( $o_proxyuser );

# force a clean time stamp from the webserver (not a cached one)
$req->header(Pragma => "no-cache");
#$req->header(Pragma => "no-cache", Connection => "close");

###### START TIME RETRIEVAL ###########
# 1. get local time "seconds since epoch, UTC" into local_timestamp
my $local_timestamp = time();

# 2. send the request to the webserver
verb("HTTP request: ".$req->as_string);

# 3. receive the request
my $res = $ua->request($req);

if (! $res->date) {
   printf("ERROR: Cannot get HTTP date response\n");
   exit $ERRORS{"UNKNOWN"};
}

# $res->as_string output is formatted by perl!
verb("HTTP response: ".$res->as_string);

# calculate the difference between local and remote time
my $offset = $res->date - $local_timestamp;

my $local_timestring = time2str("%Y-%m-%e_%T", $local_timestamp);
my $remote_timestring = time2str("%Y-%m-%e_%T", $res->date);
verb("Local Time:  $local_timestring\nRemote Time: $remote_timestring");

if ( $offset == 0 ) {
  print "$o_checkurl clock is accurate to the second";
} else {
  if ( abs($offset) != $offset ) {
     print "$o_checkurl clock is ".abs($offset)." seconds late";
  }
  if ( abs($offset) == $offset ) {
    print "$o_checkurl clock is $offset seconds early";
  }
}


$exit_val=$ERRORS{"OK"};
if ( abs($offset) > $o_crit ) {
   print " ($offset > +/-$o_crit) : CRITICAL";
   $exit_val=$ERRORS{"CRITICAL"};
  }
if ( abs($offset) > $o_warn ) {
   # output warn error only if no critical was found
   if ($exit_val eq $ERRORS{"OK"}) {
     print " ($offset > +/-$o_warn) : WARNING"; 
     $exit_val=$ERRORS{"WARNING"};
   }
}
print " : OK" if ($exit_val eq $ERRORS{"OK"});
if (defined($o_perf)) {
   print " | local=$local_timestring remote=$remote_timestring offset=$offset";
}
print "\n";


exit $exit_val;
