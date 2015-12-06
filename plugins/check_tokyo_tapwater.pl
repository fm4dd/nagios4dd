#!/usr/bin/perl -w
####################### check_tokyo_radiation.pl #################
my $Version='1.0';
# Date    : Mar 26 2011
# Purpose : Nagios plugin to check the published Tokyo tapwater
#           radiation levels
# Author  : Frank Migge (support at frank4dd dot com)
# Help    : http://nagios/fm4dd.com/
# Licence : GPL - http://www.fsf.org/licenses/gpl.txt
#################################################################
#
# Help : ./check_tokyo_tapwater.pl -h
#
# This check retrieves the daily tapwater radiation data published
# at URL http://ftp.jaist.ac.jp/pub/emergency/monitoring.tokyo-eiken.go.jp/monitoring/w-past_data.html
# and checks it against warn and crit thresholds for I-131, Cs-134 and Cs-137
#
# Example data:
#    <tr>
#      <td align="center">2011/03/25</td>
#      <td align="center">31.8</td>
#      <td align="center">0.92</td>
#      <td align="center">1.22</td>
#      <td align="center">?@</td>
#    </tr>
    
use strict;
use Getopt::Long;
use LWP::UserAgent;
use HTML::TokeParser;
use Encode;

# Nagios specific
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# Globals
my $Name=$0;
my $o_checkurl  = "http://ftp.jaist.ac.jp/pub/emergency/monitoring.tokyo-eiken.go.jp/monitoring/w-past_data.html";
my $o_proxyurl  = undef; # web proxy URL
my $o_proxyuser = undef; # web proxy auth user id
my $o_proxypass = undef; # web proxy auth password
my $o_help      = undef; # wan't some help ?
my $o_verb      = undef; # verbose mode
my $o_version   = undef; # print version
my $o_warn      = undef; # warning level (3 values, comma separated)
my $o_crit      = undef; # critical level (3 values, comma separated)
my $o_timeout   = undef; # Timeout (Default 5)
my $o_perf      = undef; # Output performance data
my $exit_val    = undef;

my $warn_I_131;
my $warn_Cs_134;
my $warn_Cs_137;
my $crit_I_131;
my $crit_Cs_134;
my $crit_Cs_137;

# functions
sub p_version { print "check_tokyo_tapwater.pl version : $Version\n"; }

sub print_usage {
    print "Usage: $0 [-v] [-x <proxyurl>] [-u <proxyuser> -p <proxypass>] -w <warn I-131>,<warn Cs-134>,<warn Cs-137> -c <crit I-131>,<crit Cs-134>,<crit Cs-137> [-f] [-t <timeout>] [-V]\n";
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

This plugin queries the Tokyo tapwater radiation levels published hourly by MEXT against warning and critical thresholds given in becquerel per liter. The data URL is hardcoded inside this script and points to $o_checkurl.

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
-w, --warn=number,number,number
   warning level for I-131,Cs-134,Cs-137 in becquerel per liter
-c, --crit=number,number,number
   critical level for I-131,Cs-134,Cs-137 in becquerel per liter
-f, --perfparse
   Perfparse compatible output
-t, --timeout=number
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
    # extract the individual threshold levels for each element
    ($warn_I_131, $warn_Cs_134, $warn_Cs_137) = split ',', $o_warn;
    ($crit_I_131, $crit_Cs_134, $crit_Cs_137) = split ',', $o_crit;

    # sanity checks for warn and crit levels
    if ( isnnum($warn_I_131) || isnnum($warn_Cs_134) || isnnum($warn_Cs_137) )  {
       print "Warning levels: $warn_I_131, $warn_Cs_134, $warn_Cs_137\n";
       print "No numeric value for warning levels!\n";print_usage(); exit $ERRORS{"UNKNOWN"}
    }
    if ( isnnum($crit_I_131) || isnnum($crit_Cs_134) || isnnum($crit_Cs_137) )  {
       print "Critical levels: $crit_I_131, $crit_Cs_134, $crit_Cs_137\n";
       print "No numeric value for critical levels!\n";print_usage(); exit $ERRORS{"UNKNOWN"}
    }
    if ($warn_I_131 > $crit_I_131 || $warn_Cs_134 > $crit_Cs_134 || $warn_Cs_137 > $crit_Cs_137) 
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
$ua->agent('check_tokyo_tapwater.pl/$Version (Japan Emergency Response -> support@frank4dd.com)');
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
  print "Tokyo tapwater monitoring site returned no data : UNKNOWN\n";
  exit $ERRORS{"UNKNOWN"};
}

$body = decode_utf8($body);

my $stream = HTML::TokeParser->new(\$body);

my $i = 0;
my $measuredate;
my $I_131value;
my $Cs_134value;
my $Cs_137value;

while (my $token = $stream->get_tag("td") && $i < 4) {
  my $cell = $stream->get_trimmed_text;
  # get the latest value ( year 20xx)
  if($cell =~ /^20[0-9][0-9]/ && $i == 0) { $measuredate = $cell; $i++; next; }

  if($cell =~ /^[0-9]/ && $i == 1) { $I_131value = $cell; $i++; next; }
  if($cell =~ /(ND)/ && $i == 1)   { $I_131value = 0; $i++; next; }

  if($cell =~ /^[0-9]/ && $i == 2) { $Cs_134value = $cell; $i++; next; }
  if($cell =~ /(ND)/ && $i == 2)   { $Cs_134value = 0; $i++; next; }

  if($cell =~ /^[0-9]/ && $i == 3) { $Cs_137value = $cell; $i++; next; }
  if($cell =~ /(ND)/ && $i == 3)   { $Cs_137value = 0; $i++; next; }
}

$measuredate = encode_utf8($measuredate);
$exit_val=$ERRORS{"OK"};

if ( $I_131value >= $crit_I_131 || $Cs_134value >= $crit_Cs_134 || $Cs_137value >= $crit_Cs_137 ) {
   print "Tokyo tapwater I-131: $I_131value($crit_I_131)Bq/Kg, Cs-134: $Cs_134value($crit_Cs_134)Bq/Kg, Cs-137: $Cs_137value($crit_Cs_137)Bq/Kg = CRITICAL";
   $exit_val=$ERRORS{"CRITICAL"};
}

if ( $I_131value >= $warn_I_131 || $Cs_134value >= $warn_Cs_134 || $Cs_137value >= $warn_Cs_137 ) {
   # output warn error only if no critical was found
   if ($exit_val eq $ERRORS{"OK"}) {
     print "Tokyo tapwater I-131: $I_131value($warn_I_131)Bq/Kg, Cs-134: $Cs_134value($warn_Cs_134)Bq/Kg, Cs-137: $Cs_137value($warn_Cs_137)Bq/Kg = WARNING";
     $exit_val=$ERRORS{"WARNING"};
   }
}

print "Tokyo tapwater I-131: $I_131value($warn_I_131)Bq/Kg, Cs-134: $Cs_134value($warn_Cs_134)Bq/Kg, Cs-137: $Cs_137value($warn_Cs_137)Bq/Kg = OK" if ($exit_val eq $ERRORS{"OK"});

# add the perfdata if requested
if (defined($o_perf)) {
   print " | date=$measuredate;I-131=$I_131value;Cs-134=$Cs_134value;Cs-137=$Cs_137value";
}
print "\n";

exit $exit_val;
