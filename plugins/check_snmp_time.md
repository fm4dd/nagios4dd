# check_snmp_time

## Man page for the Nagios plugin check_snmp_time.pl

Update (c) 2010 Frank4DD<support[at]frank4dd.com>

### check_snmp_time.pl

* * *

This plugin checks the remote servers time and compares it against the local time on the Nagios server. With Nagios being sync'ed to NTP, this can identify systems that have no NTP set up, or NTP is wrongly configured. This plugin is particalry helpful if SNMP is already used to monitor the system.

The plugin depends on Perl's Net::SNMP package, i.e. perl-SNMP-5.3.0.1-25.34.1.

#### Usage:

`check_snmp_time.pl [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>]) [-p <port>] [-o <tz-offset>] -w <warn level> -c <crit level> [-f] [-t <timeout>] [-V]`

#### Options:

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

-o, --tzoffset=MINS  
      the remote systems timezone offset to the Nagios server, in minutes

-w, --warn=INTEGER  
      warning level for time difference in seconds

-c, --crit=INTEGER  
      critical level for time difference in seconds

-f, --perfparse  
      Perfparse compatible output

-t, --timeout=INTEGER  
      timeout for SNMP in seconds (Default: 5)

-V, --version  
      prints version number

#### Plugin Definition Example:

Below is an example of the plugin definition in the Nagios command.cfg file.

    # check_snmp_time.pl nagios plugin
    define command{
      command_name check_snmp_time
      command_line $USER1$/check_snmp_time.pl -H $HOSTADDRESS$ -C $ARG1$ -w $ARG2$ -c $ARG3$ -f
    }

#### Plugin Usage Example:

The plugin with its most basic use.

<pre>susie: ~ # cd /srv/app/nagios/libexec
susie: ~ # ./check_snmp_time.pl -H 192.168.98.109 -C NBNro -w 1 -c 20
192.168.98.109 clock is accurate to the second : OK</pre>

The plugin with the -f option, returning additional performance data.

<pre>susie: ~ # cd /srv/app/nagios/libexec
susie: ~ # ./check_snmp_time.pl -H 192.168.98.109 -C NBNro -w 1 -c 20 -f
192.168.98.109 clock is accurate to the second : OK | 
local=2010-12-14_19:27:26 remote=2010-12-14_19:27:26 offset=0</pre>
