# check_avaya_peak.pl

## Man page for the Nagios plugin check_avaya_peak.pl

Copyright (c) 2010 Frank4DD<support[at]frank4dd.com>

### check_avaya_peak.pl

Avaya S8xxx media servers provide call peak information through Avaya's SNMP agents g3-mib for data, voice, srv, media and overall call peak values. These are collected in hourly periods, so the published data is always refering to the last hour of operation. The peak values available seem to be the concurrent number of calls measured per second, and the total number of calls per hour. This plugin queries these last hours peak values and compares them against warning and critical thresholds. The values are returned from one of these rate groups:

*   g3callratedata
*   g3callratevoice
*   g3callratesrv
*   g3callratemedia
*   g3callratetotal

The returned data is most useful for graphing to identify trends in usage when used together with the trunk group call monitoring plugin. Without graphing, the plugin needs to run only once per hour, but for graphing we want to get data in 5 minute intervals. We can separately return and graph the concurrent calls peak or the total calls per hour.

This plugin requires SNMP access to the Avaya media server, which is configured in the management console. Fo SNMP queries it depends on Perl's Net::SNMP package, i.e. perl-SNMP-5.3.0.1-25.34.1.

### Usage:

`./check_avaya_peak.pl [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>]) [-p <port>] -R <rate type> -P <peak type> -w <warn level> -c <crit level> [-t <timeout>] [-f] [-V]`

### Options:

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

-R, --ratetype=data|voice|srv|media|total  
      the rate group to check for data: data, voice, srv, media or total

-P, --peaktype=concur|total  
      the type of peak data to return: concur=concurrent calls, total=total calls/h

-t, --timeout=INTEGER  
      timeout for SNMP in seconds (Default: 5)

-V, --version  
      prints version number

### Plugin Definition Example:

Below is an example of the plugin definition in the Nagios command.cfg file.

<pre># check_avaya_peak nagios plugin returns concurrency peak
define command{
  command_name check_avaya_cpeaks
  command_line /srv/app/nagios/libexec/check_avaya_peak.pl -H $HOSTADDRESS$ -t 60 -C $ARG1$ -R $ARG2$ -P concur -w $ARG3$ -c $ARG4$
}

# check_avaya_peak nagios plugin returns hourly total
define command{
  command_name check_avaya_tpeaks
  command_line /srv/app/nagios/libexec/check_avaya_peak.pl -H $HOSTADDRESS$ -t 60 -C $ARG1$ -R $ARG2$ -P total -w $ARG3$ -c $ARG4$
}</pre>

### Plugin Usage Example:

The plugin with its most basic use.

<pre>susie: ~ # cd /srv/app/nagios/libexec
susie: ~ # ./check_avaya_peak.pl -H 192.168.65.11 -C NBNro -w 300 -c 600 -R voice -P total -f
Avaya peaks for 'voice' at 1300 - 574 total calls 574 > 300 : WARNING | peakdata=574 peaktype=total ratetype=voice peaktime=13:48:00

# ./check_avaya_peak.pl -H 192.168.65.11 -C NBNro -w 580 -c 600 -R voice -P total -f
Avaya peaks for 'voice' at 1300 - 574 total calls : OK | peakdata=574 peaktype=total ratetype=voice peaktime=13:48:00

# ./srv/app/nagios/libexec/check_avaya_peak.pl -H 192.168.65.11 -C NBNro -w 440 -c 500 -R voice -P total -f
Avaya peaks for 'voice' at 1300 - 574 total calls 574 > 500 : CRITICAL | peakdata=574 peaktype=total ratetype=voice peaktime=13:48:00

# ./check_avaya_peak.pl -H 192.168.65.11 -C NBNro -w 10 -c 20 -R voice -P concur -f
Avaya peaks for 'voice' at 1300 - 11 concur calls 11 > 10 : WARNING | peakdata=11 peaktype=concur ratetype=voice peaktime=13:48:00

# ./check_avaya_peak.pl -H 192.168.65.11 -C NBNro -w 15 -c 20 -R voice -P concur -f
Avaya peaks for 'voice' at 1300 - 11 concur calls : OK | peakdata=11 peaktype=concur ratetype=voice peaktime=13:48:00

# ./check_avaya_peak.pl -H 192.168.65.11 -C NBNro -w 8 -c 10 -R voice -P concur -f
Avaya peaks for 'voice' at 1300 - 11 concur calls 11 > 10 : CRITICAL | peakdata=11 peaktype=concur ratetype=voice peaktime=13:48:00</pre>
