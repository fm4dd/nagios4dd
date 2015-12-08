# check_nagiostats.pl

## Man page for the Nagios plugin check_nagiostats.pl.pl

Update (c) 2010 Frank4DD<support[at]frank4dd.com>

### check_nagiostats.pl.pl

* * *

This plugin checks nagios performance data by parsing the nagios status.dat file, e.g. in /usr/local/nagios/var/status.dat.

Because it depends on being able to read the status.dat file, it can only run locally on the Nagios server itself.

#### Usage:

check_nagiostats.pl.pl [-v] -H <host> -C <snmp_community> [-2] | (-l login -x passwd [-X pass -L <authp>,<privp>]) [-p <port>] [-o <tz-offset>] -w <warn level> -c <crit level> [-f] [-t <timeout>] [-V]

#### Options:

-v, --verbose  
      print extra debugging information

-h, --help  
      print this help message

-s, --service_latency  
      checks the service with the max execution latency

-o, --host_latency  
      checks the host check with the max execution latency

-p, --hostcount  
      check number of monitored hosts

-r, --servicecount  
      check number of monitored services

-w, --warn=INTEGER  
      warning threshold

-c, --crit=INTEGER  
      critical threshold

-f, --file  
      provide an alternate file path to status.dat

#### Plugin Definition Example:

Below is an example of the plugin definition in the Nagios command.cfg file.

<pre># Check the # of monitored hosts w. check_nagiostats.pl
define command{
  command_name check_nagiosconf
  command_line $USER1$/check_nagiostats.pl -w $ARG1$ -c $ARG2$ -p
}</pre>

#### Plugin Usage Example:

The plugin with its most basic use, counting the number of monitored hosts

<pre>susie: ~ # cd /srv/app/nagios/libexec
# ./check_nagiostats.pl -w 50 -c 100 -p
OK: 3 Nagios host checks|count=3 </pre>

The plugin with -o, checking the max execution latency for host checks.

<pre># ./check_nagiostats.pl -w 50 -c 100 -o
OK: max latency: =0.000
avg latency: 0.000
min latency: =0.000|max=0.000s;50;100 avg=0.000s;50;100 min=0.000s;50;100</pre>
