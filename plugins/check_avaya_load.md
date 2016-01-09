# check_avaya_load.pl

## Man page for the Nagios plugin check_avaya_load.pl

Copyright (c) 2010 Frank4DD<support[at]frank4dd.com>

### check_avaya_load.pl

This plugin checks the CPU load of AVAYA S8xxx media servers, accessing Avaya's SNMP agent with [G3-AVAYA-MIB Version 5.1.1](avaya/g3mib.asn1). It returns the total CPU usage and idle values in percent, checked against warning and critical threshold values. When called with the -f option, it returns additional CPU usage details in the performance data section.

It requires SNMP access to the Avaya media server, which is configured in the management console. The plugin depends on Perl's Net::SNMP package, i.e. perl-SNMP-5.3.0.1-25.34.1.

### Usage:

`check_avaya_load.pl [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>]) [-p <port>] -w <warn level> -c <crit level> [-f] [-t <timeout>] [-V]`

### Options:

-v, --verbose<br>
      print extra debugging information

-h, --help<br>
      print this help message

-H, --hostname=HOST<br>
      name or IP address of host to check

-C, --community=COMMUNITY NAME<br>
      community name for the host's SNMP agent (implies v1 protocol)

-2, --v2c<br>
      Use snmp v2c

-l, --login=LOGIN ; -x, --passwd=PASSWD<br>
      Login and auth password for snmpv3 authentication<br>
      If no priv password exists, implies AuthNoPriv

-X, --privpass=PASSWD<br>
      Priv password for snmpv3 (AuthPriv protocol)

-L, --protocols=[authproto],[privproto]<br>
      [authproto]: Authentication protocol (md5|sha : default md5)a<br>
      [privproto]: Priv protocol (des|aes : default des)

-p, --port=PORT<br>
      SNMP port (Default 161)

-w, --warn=INTEGER<br>
      warning level for cpu in percent

-c, --crit=INTEGER<br>
      critical level for cpu in percent

-f, --perfparse<br>
      Perfparse compatible output

-t, --timeout=INTEGER<br>
      timeout for SNMP in seconds (Default: 5)

-V, --version<br>
      prints version number

### Plugin Definition Example:

Below is an example of the plugin definition in the Nagios command.cfg file.

```
# check_avaya_load nagios plugin
define command{
  command_name check_avaya_load
  command_line /srv/app/nagios/libexec/check_avaya_load.pl -H $HOSTADDRESS$ -t 60 -C $ARG1$ -f -w $ARG2$ -c $ARG3$
}
```

### Plugin Usage Example:

The plugin with its most basic use.

<pre class="code">susie: ~ # cd /srv/app/nagios/libexec
susie: ~ # ./check_avaya_load.pl -H 192.168.65.11 -C SECro -w 75 -c 95
Avaya CPU: 9% used, 91% free : OK</pre>

The plugin with the -f option, returning additional performance data.

<pre class="code">susie: ~ # cd /srv/app/nagios/libexec
susie: ~ # ./check_avaya_load.pl -H 192.168.65.11 -C SECro -w 75 -c 95 -f
Avaya CPU: 6% used, 94% free : OK | load_os=0; load_call=1; load_mgt=5; load_idle=94;</pre>
