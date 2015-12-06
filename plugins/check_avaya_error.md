# check_avaya_error

## Man page for the Nagios plugin check_avaya_error

Updated (c) 2010 Frank4DD<support[at]frank4dd.com>

### check_avaya_error

* * *

This plugin checks the error logs of AVAYA S8xxx media servers through Avaya's SNMP agent with [G3-AVAYA-MIB Version 5.1.1](avaya/g3mib.asn1). It returns the port, date, time and alert names that have been recorded for server and communication manager logs.

It requires SNMP access to the Avaya media server, which is configured in the management console. The plugin depends on Perl's Net::SNMP package, i.e. perl-SNMP-5.3.0.1-25.34.1.

### Usage:

* * *

Usage: /srv/app/nagios/libexec/check_avaya_error.pl [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>]) [-p <port>] -S <SVL|CML> -E <errorlevel> [-t <timeout>] [-V]

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

-L, --protocols=<authproto>,<privproto>  
      <authproto> : Authentication protocol (md5|sha : default md5)  
      <privproto> : Priv protocole (des|aes : default des)

-p, --port=PORT  
      SNMP port (Default 161)

-S, --service=SERVICE  
      Please specify SVL (server logs) or CML (communication manager logs)

-E, --errorlevel=LEVEL  
      Please specify one of the following: MAJ, MIN, WRN or CRI

-t, --timeout=INTEGER  
      timeout for SNMP in seconds (Default: 5)

-V, --version  
      prints version number

### Plugin Definition Example:

* * *

Below is an example of the plugin definition in the Nagios command.cfg file.

    # check_avaya_error.pl nagios plugin
    define command{
      command_name check_avaya_alerts
      command_line /srv/app/nagios/libexec/check_avaya_error.pl -H $HOSTADDRESS$
    -t 60 -C $ARG1$ -S $ARG2$ -E $ARG3$
    }

### Plugin Usage Example:

* * *

The plugin with its most basic use, checking for critical alerts.

<pre class="code">susie: ~ # cd /srv/app/nagios/libexec
susie: ~ # ./check_avaya_error.pl -H 192.168.65.11 -C SECro -S CML -E CRI
OK: No Communications Manager Alerts (CRITICAL)</pre>

The plugin checking for server log warnings.

<pre class="code">susie: ~ # cd /srv/app/nagios/libexec
susie: ~ # ./check_avaya_error.pl -H 192.168.65.11 -C SECro -S CML -E WRN
WARNING: WARNING Alarmport: 01A11, MaintName: UDS1-BD, Date: 28.11\. Time: 22:17
WARNING Alarmport: 01B11, MaintName: UDS1-BD, Date: 28.11\. Time: 22:17
WARNING Alarmport: 02A11, MaintName: UDS1-BD, Date: 29.11\. Time: 15:32
WARNING Alarmport: 02A14, MaintName: UDS1-BD, Date: 29.11\. Time: 15:32
WARNING Alarmport: 02B11, MaintName: UDS1-BD, Date: 03.12\. Time: 12:08
WARNING Alarmport: 02B14, MaintName: UDS1-BD, Date: 28.11\. Time: 22:17
WARNING Alarmport: S00159, MaintName: DIG-IP-S, Date: 28.11\. Time: 22:21
WARNING Alarmport: S00246, MaintName: DIG-IP-S, Date: 28.11\. Time: 22:21
WARNING Alarmport: S00250, MaintName: DIG-IP-S, Date: 28.11\. Time: 22:21
WARNING Alarmport: S00386, MaintName: DIG-IP-S, Date: 28.11\. Time: 22:21
WARNING Alarmport: S00410, MaintName: DIG-IP-S, Date: 28.11\. Time: 22:21
WARNING Alarmport: S00483, MaintName: DIG-IP-S, Date: 28.11\. Time: 22:21
WARNING Alarmport: S00500, MaintName: DIG-IP-S, Date: 09.12\. Time: 10:50
WARNING Alarmport: S00503, MaintName: DIG-IP-S, Date: 28.11\. Time: 22:21
WARNING Alarmport: S00637, MaintName: DIG-IP-S, Date: 28.11\. Time: 22:21
WARNING Alarmport: S00653, MaintName: DIG-IP-S, Date: 13.12\. Time: 12:52
WARNING Alarmport: S00667, MaintName: DIG-IP-S, Date: 28.11\. Time: 22:21
WARNING Alarmport: S00806, MaintName: DIG-IP-S, Date: 03.12\. Time: 12:57
WARNING Alarmport: S00852, MaintName: DIG-IP-S, Date: 28.11\. Time: 22:21
WARNING Alarmport: S01074, MaintName: DIG-IP-S, Date: 28.11\. Time: 22:21
WARNING Alarmport: S01148, MaintName: DIG-IP-S, Date: 07.12\. Time: 13:21
WARNING Alarmport: S01172, MaintName: DIG-IP-S, Date: 28.11\. Time: 22:21
WARNING Alarmport: 01A0718, MaintName: AN-LN-PT, Date: 
29.11\. Time: 22:15
WARNING Alarmport: 02A0706, MaintName: AN-LN-PT, Date: 29.11\. Time: 22:16
WARNING Alarmport: 02A0707, MaintName: AN-LN-PT, Date: 29.11\. Time: 22:16
WARNING Alarmport: 02A0714, MaintName: AN-LN-PT, Date: 30.11\. Time: 22:15</pre>
