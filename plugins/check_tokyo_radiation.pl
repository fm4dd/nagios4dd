#!/usr/bin/perl -w
####################### check_tokyo_radiation.pl #################
my $Version='1.1';
# Date    : Mar 24 2011
# Purpose : Nagios plugin to check the published Tokyo radiation
# Author  : Frank Migge (support at frank4dd dot com)
# Help    : http://nagios.fm4dd.com/
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt
#################################################################
#
# Help : ./check_tokyo_radiation.pl -h
#
# This check retireves the hourly radiation data published
# at URL http://ftp.jaist.ac.jp/pub/emergency/monitoring.tokyo-eiken.go.jp/report/report_table.do.html
# and checks it against warn and crit thresholds of microgray per hour.
#
#<tr>
#<td>2011-03-23&nbsp;&nbsp;&nbsp;16:00～16:59</td>
#<td style="text-align:right;">0.150</td>
#<td style="text-align:right;">0.139</td>
#<td style="text-align:right;">0.146</td>
#</tr>
    
use strict;
use Getopt::Long;
use LWP::UserAgent;
use HTML::TokeParser;
use Encode;

# Nagios specific
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# Globals
my $Name=$0;
my $o_checkurl  = "http://ftp.jaist.ac.jp/pub/emergency/monitoring.tokyo-eiken.go.jp/report/report_table.do.html";
#my $o_checkurl  = "http://113.35.73.180/report/report_table.do";
my $o_proxyurl  = undef; # web proxy URL
my $o_proxyuser = undef; # web proxy auth user id
my $o_proxypass = undef; # web proxy auth password
my $o_help      = undef; # wan't some help ?
my $o_verb      = undef; # verbose mode
my $o_version   = undef; # print version
my $o_warn      = undef; # warning level
my $o_crit      = undef; # critical level
my $o_timeout   = undef; # Timeout (Default 5)
my $o_perf      = undef; # Output performance data
my $exit_val    = undef;

# functions
sub p_version { print "check_tokyo_radiation.pl version : $Version\n"; }

sub print_usage {
    print "Usage: $0 [-v] [-x <proxyurl>] [-u <proxyuser> -p <proxypass>] -w <warn level> -c <crit level> [-f] [-t <timeout>] [-V]\n";
}

sub isnnum { # Return true if arg is not a number
  my $num = shift;
  if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$|^-(\d+\.?\d*)|(^-\.\d+)$/ ) { return 0 ;}
  return 1;
}

sub help {
   print "\nTokyo environmental radiation monitor for Nagios version ",$Version,"\n";
   print "GPL licence, (c) 2011 Frank4DD\n\n";
   print_usage();
   print <<EOT;

This plugin queries the Tokyo environmental radiation levels published hourly by MEXT against warning and critical thresholds given in microgray per hour.
The data URL is hardcoded inside this script and points to $o_checkurl.

-v, --verbose
   print extra debugging information 
-h, --help
   print this help message
-x, --proxyurl=<http://xxx.yy.zz>
   proxy server URL to use if needed
-u, --proxyuser=<proxy auth userid>
   if the proxy server requires authentication, proxy user ID
-p, --proxypass=<password>
   if the proxy server requires authentication, the proxy users password
-w, --warn=INTEGER
   warning level in microgray per hour
-c, --crit=INTEGER
   critical level in microgray per hour
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
$ua->agent('check_tokyo_radiation.pl/$Version (Manulife Japan Emergency Response -> frank_migge@manulife.japan)');
$ua->timeout($o_timeout);
$ua->env_proxy;
#$ua->max_redirect(1); # do not follow redirects

# prepare the HTTP request
my $req = HTTP::Request->new('GET');
   $req->url($o_checkurl);

# set proxy if requested
if (defined($o_proxyurl)) { $ua->proxy(['http'], $o_proxyurl); }

# set proxy authentication, if applicable
$req->proxy_authorization_basic ( $o_proxyuser, $o_proxypass ) if ( $o_proxyuser );

# force a fresh answer from the webserver (not a cached one)
$req->header(Pragma => "no-cache");
#$req->header(Pragma => "no-cache", Connection => "close");

# 1. get local time "seconds since epoch, UTC" into local_timestamp
(my $sec,my $min,my $hour,my $mday,my $mon,my $year,my $wday,
	my $yday,my $isdst)=localtime(time);
my $local_datestring = sprintf "%4d-%02d-%02d", $year+1900,$mon+1,$mday;
my $local_timestring = sprintf "%02d:59\n", $hour-1;
verb("Last Measure Time:  $local_datestring - $local_timestring\n");

# 2. send the request to the webserver
verb("HTTP request: ".$req->as_string);
my $res = $ua->request($req);

# Check if we could contact the remote side
if (! $res->is_success) {
  printf("ERROR: ".$res->status_line."\n");
  exit $ERRORS{"UNKNOWN"};
}

# 4. Get the HTML content
my $body = $res->content;

# 5. The website is often unreliable and sometimes just returns
# a empty page
if(length($body) == 0) {
  print "Tokyo radiation monitoring site returned no data : UNKNOWN\n";
  exit $ERRORS{"UNKNOWN"};
}

$body = decode_utf8($body);

my $stream = HTML::TokeParser->new(\$body);

my $i = 0;
my $measuredate;
my $maxvalue;
my $minvalue;
my $avgvalue;

while (my $token = $stream->get_tag("td") && $i < 4) {
  my $cell = $stream->get_trimmed_text;
  if($cell =~ /^[0-9]/ && $i == 0) { $measuredate = $cell; $i++; next; }
  if($cell =~ /^[0-9]/ && $i == 1) { $maxvalue = $cell; $i++; next; }
  if($cell =~ /^[0-9]/ && $i == 2) { $minvalue = $cell; $i++; next; }
  if($cell =~ /^[0-9]/ && $i == 3) { $avgvalue = $cell; $i++; next; }
}

$measuredate = encode_utf8($measuredate);
verb($maxvalue);

$exit_val=$ERRORS{"OK"};
if ( $maxvalue > $o_crit ) {
   print "Tokyo radiation $maxvalue microgray/hr > $o_crit : CRITICAL";
   $exit_val=$ERRORS{"CRITICAL"};
  }
if ( $maxvalue > $o_warn ) {
   # output warn error only if no critical was found
   if ($exit_val eq $ERRORS{"OK"}) {
     print "Tokyo radiation $maxvalue microgray/hr > $o_warn : WARNING"; 
     $exit_val=$ERRORS{"WARNING"};
   }
}
print "Tokyo radiation $maxvalue microgray/hr : OK" if ($exit_val eq $ERRORS{"OK"});
if (defined($o_perf)) {
   print " | time=$measuredate;max=$maxvalue;min=$minvalue;avg=$avgvalue";
}
print "\n";

exit $exit_val;
