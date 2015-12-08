# check_snmp_aixload

## Man page for the Nagios plugin check_snmp_aixload.pl

Update (c) 2010 Frank4DD<support[at]frank4dd.com>

### check_snmp_aixload.pl

* * *

This plugin checks the CPU load on AIX systems through the AIX MIB value "aixSeCPUUtilization". This plugin is particulary helpful if SNMP is already used to monitor the system.

We used to monitor AIX load through check_snmp_load.pl, using the parameter -T stand (type standard). This worked fine retrieving the number of CPU cores and the 1 minute load average from the Host mibs values under "hrProcessorLoad". When IBM released thew AIX OS update OS update to TL11 SP4 and we upgraded, our CPU monitoring broke and phantastic load values were returned by IBM's AIX SNMP daemon.

In order get correct CPU load values again, I created this plugin to query aixmibd's value "aixSeCPUUtilization" instead.

The plugin depends on Perl's Net::SNMP package, i.e. perl-SNMP-5.3.0.1-25.34.1.

#### Usage:

`check_snmp_aixload.pl [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>]) [-p <port>] -w <warn level> -c <crit level> [-f] [-t <timeout>] [-V]`

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

<pre># check_snmp_time.pl nagios plugin
define command{
  command_name check_snmp_aixload
  command_line $USER1$/check_snmp_aixload.pl -H $HOSTADDRESS$ -C $ARG1$ -w $ARG2$ -c $ARG3$
}</pre>

#### Plugin Usage Example:

The plugin with its most basic use.

<pre>susie: ~ # ./check_snmp_aixload.pl -H 192.168.16.70 -C NBNro -w 10 -c 90
CPU used 14.0% (>10) : WARNING</pre>
