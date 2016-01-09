# check_http_time

## Man page for the Nagios plugin check_http_time.pl

Update (c) 2010 Frank4DD<support[at]frank4dd.com>

### check_http_time.pl

This plugin checks the remote servers time and compares it against the local time on the Nagios server. With Nagios being sync'ed to NTP, this can identify systems that have no NTP set up, or NTP is wrongly configured. This plugin is particularly helpful if HTTP is the only way to reach the server due to firewall or network restrictions.

The plugin depends on Perl's LWP package, i.e. perl-libwww-perl-5.830-2.2.i586

#### Usage:

`check_http_time.pl [-v] -d <checkurl> [-x <proxyurl>] [-u <proxyuser> -p <proxypass>] -w <warn level> -c <crit level> [-f] [-t <timeout>] [-V]`

#### Options:

-v, --verbose  
      print extra debugging information

-h, --help  
      print this help message

-d, --checkurl=DESTINATION-URL  
      URL of the host to check, i.e. http://www.hp.com

-x, --proxyurl=PROXY-URL  
      if the request should go through a proxy, add the proxy URL

-u, --proxyuser=LOGIN ; -x, --proxypass=PASSWD  
      Login and auth password for the proxy, if necessary

-w, --warn=INTEGER  
      warning level for time difference in seconds

-c, --crit=INTEGER  
      critical level for time difference in seconds

-f, --perfparse  
      Perfparse compatible output

-t, --timeout=INTEGER  
      timeout in seconds (Default: 5)

-V, --version  
      prints version number

#### Plugin Definition Example:

Below is an example of the plugin definition in the Nagios command.cfg file.

<pre># check_http_time.pl nagios plugin
define command{
  command_name check_http_time
  command_line $USER1$/check_http_time.pl -d $ARG1$ -w $ARG2$ -c $ARG3$ $ARG4$
}</pre>

#### Plugin Usage Example:

The plugin with its most basic use.

<pre>susie: ~ # cd /srv/app/nagios/libexec
susie: ~ # ./check_http_time.pl -d http://www.google.com -w 3 -c 6
http://www.google.com clock is accurate to the second : OK</pre>

The plugin with the -f option, returning additional performance data.

<pre>susie: ~ # cd /srv/app/nagios/libexec
susie: ~ # /srv/app/nagios/libexec/check_http_time.pl -d http://www.hp.com -w 3 -c 6 -f
http://www.hp.com clock is accurate to the second : OK | 
local=2010-12-25_19:39:33 remote=2010-12-25_19:39:33 offset=0</pre>
