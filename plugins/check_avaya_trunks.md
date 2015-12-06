# check_avaya_trunks.pl

## Man page for the Nagios plugin check_avaya_trunks.pl

Copyright (c) 2010 Frank4DD<support[at]frank4dd.com>

### check_avaya_trunks.pl

* * *

This plugin checks the call usage of PBX trunks on AVAYA VOIP S8xxx media servers, accessing Avaya's SNMP agent running with [G3-AVAYA-MIB Version 5.1.1](avaya/g3mib.asn1). It returns the current number of active trunk lines compared to the total number of lines. They are checked against warning and critical threshold values to identify capacity issues. The data can be graphed for historical trending.  
Nagios checks are typically run in 5 minute intervals. Much could happen in between checks, fo example when a lot of short calls are being made. AVAYA's SNMP data provides a different data set with absolute call peaks across all trunks, check_avaya_peaks is the plugin to monitor these.

This plugin requires SNMP access to the Avaya media server, which is configured in the management console. Fo SNMP queries it depends on Perl's Net::SNMP package, i.e. perl-SNMP-5.3.0.1-25.34.1.

### Usage:

* * *

`./check_avaya_trunk.pl [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>]) [-p <port>] -T <trunkgroup number> -w <warn level> -c <crit level> [-t <timeout>] [-V]`

### Options:

* * *

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

-L, --protocols=[authproto],[privproto]  
      [authproto]: Authentication protocol (md5|sha : default md5)  
      [privproto]: Priv protocol (des|aes : default des)

-p, --port=PORT  
      SNMP port (Default 161)

-w, --warn=INTEGER  
      warning number of active calls

-c, --crit=INTEGER  
      critical number of active calls

-T, --trunkgroup  
      the PBX trunk group number (TGN) to check for

-t, --timeout=INTEGER  
      timeout for SNMP in seconds (Default: 5)

-V, --version  
      prints version number

### Plugin Definition Example:

* * *

Below is an example of the plugin definition in the Nagios command.cfg file.

<pre># check_avaya_trunk nagios plugin
define command{
  command_name check_avaya_trunk
  command_line /srv/app/nagios/libexec/check_avaya_trunk.pl -H $HOSTADDRESS$ 
-t 60 -C $ARG1$ -f -w $ARG2$ -c $ARG3$
}</pre>

### Plugin Usage Example:

* * *

The plugin with its most basic use.

<pre>susie: ~ # cd /srv/app/nagios/libexec
susie: ~ # ./check_avaya_trunks.pl -H 192.168.65.11 -C NBNro -T 1 -w 40 -c 46
Avaya Trunk TGN 1 - 8 of 46 channels active: OK</pre>

Avaya media servers can be very slooow in responding to SNMP requests. Especially the smaller systems like the S8300 series. here is a example query timed, it took over one minute to walk and calculate. Please use it with care, lets push Avaya for more direct retrievable SNMP data that does not require these extensive MIB walks.

<pre>susie: ~ # time ./check_avaya_trunks.pl -H 192.168.230.16 -C NBNro -2 -T 1 -w 55 -c 66 -v -t 15
SNMP v2c login
Trunk 1: TGN 1, 23 channels, 0 active.
Trunk 1: TGN 1 23 channels, 0 active.
Avaya system 192.168.230.16 has 1 trunks with 0/23 active channels.
Avaya Trunk TGN 1 - 0 of 23 channels active: OK

**real	1m18.864s**</pre>
