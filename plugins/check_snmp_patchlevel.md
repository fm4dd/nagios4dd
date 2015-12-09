# check_snmp_patchlevel.pl

## Man page for the Nagios plugin check_snmp_patchlevel.pl

Copyright (c) 2010 Frank4DD<support[at]frank4dd.com>

### check_snmp_patchlevel.pl

* * *

This plugin tests the OS software version through querying the SNMP sysDescr value (SNMPv2-MIB::sysDescr.0, OID .1.3.6.1.2.1.1.1.0). Although this value is very differently set by IT vendors, we can use it to determine and monitor Cisco network devices. Cisco thankfully provides a consistent format we can parse for compliance checks. Currently implemented are Cisco IOS devices, as well as PIX (obsolete by now) and ASA firewalls. The plugin can either simply return the version string (discovery mode), or compare it against a blacklist/whitelist version file to determine software version compliance (compliance mode).

The plugin depends on Perl's Net::SNMP package, i.e. perl-SNMP-5.3.0.1-25.34.1.

#### Usage:

`./check_snmp_patchlevel.pl -H <host> [-v snmp version 1|2] -g <ios|asa|pix> [-C community]`  

`./check_snmp_patchlevel.pl -H <host> [-v snmp version 1|2] -g <ios|asa|pix> [-C community] [-f <config file>]`

#### Options:

-H  
      The IP address of the device

-v, --snmp-version [1|2]  
      The SNMP version to use: 1 or 2c

-g, --devicegroup=[ios|asa|pix]  
      OS version string to expect: ios = Cisco IOS devices, asa = Cisco ASA Appliances, pix = Cisco PIX Firewalls 

-C, --community=community  
      SNMP read community string (default public)

-f configfile  
      Compare the returned software version string against a blacklist/whitelist file

#### Configuration File Format:

The blacklist/whitelist file for comparing software versions against a set of approves versions. The file format defines version lines separated into 4 columns. The column separator character is defined as '|'. The file can contain comment lines, identified through the first line character '#'.

**Column 1** contains one of the following strings 'approved', 'obsolete', 'med-vuln' or 'cri-vuln'. Versions marked 'approved' will return 'OK' (green) in Nagios. The marker 'approved' is meant for versions that are confirmed to be recent, without known vulnerabilities (yet) or otherwise desired by IT networks/management, i.e. for standardization. Versions marked 'obsolete' will return 'WARNING' (yellow). This is is meant for versions that are EOL, but not confirmed vulnerable yet. It is highly undesired to run these versions. Versions marked 'med-vuln' will return 'WARNING' (yellow). This is is meant for versions that are confirmed to have vulnerabilities who are either currently not applicable, or rated low to medium with compensations in place. We desire to upgrade these versions in a planned fashion. Versions marked 'crit-vuln' will return 'CRITICAL' (red). This is is meant for versions that are confirmed to be vulnerable with a high risk of immediate impact. These versions should be upgraded as soon as possible. Versions that are neither 'approved', 'obsolete' or 'vulnerable' will return 'UNKNOWN' (orange) in Nagios. This is meant as a note to check if this version is OK to run, so it can be categorized.

**Column 2** contains the device string, supported strings for Cisco are 'ios', 'asa', and 'pix'.

**Column 3** contains the Version string as returned by the plugin. This string must match exactly the plugins returned value. If unsure, run the plugin in discovery mode, i.e. without the -f <file>

**Column 4** contains a remarks string, i.e. reason for marked 'obsolete'. This column may be left empty, but it is a good idea to use it for information about this particular version, i.e. list vulnerabilities or the vendors end-of-life date.

#### Configuration File Example:

<pre>#####################################################################
# Below are the 'approved' versions we explicitly endorse for usage: #
######################################################################
approved|ios|12.4(6)T11|For all internal routers
approved|ios|12.1(22)EA12|
approved|ios|12.4(23)|
approved|ios|12.2(37)EY|for the 2950 switches in SO
approved|asa|8.0(4)|
approved|asa|8.0(4)6|
approved|pix|8.0(4)|
######################################################################
# Below are the 'obsolete' versions we explicitly disapprove of:     #
######################################################################
obsolete|pix|7.2(2)|end-of-maintenance 2009-07-28
obsolete|pix|6.3(5)|end-of-maintenance 2009-07-28
obsolete|ios|12.2(35)SE5|end-of-maintenance date 2007-12-12
obsolete|ios|12.2(35)SE|end-of-maintenance date 2007-12-12
obsolete|ios|12.1(27b)E3|end-of-maintenance date 2008-03-15
obsolete|ios|12.1(22)EA9|end-of-maintenance date 2008-03-15
######################################################################
# Below are the 'med-vuln' versions with low to medium criticality   #
######################################################################
med-vuln|ios|12.4(7a)|multiple DOS confirmed
med-vuln|ios|12.4(6)T8|multiple DOS confirmed (Voice, Stack)
med-vuln|ios|12.4(9)T4|SSH DOS confirmed, replaced with 12.4(15)T5
med-vuln|ios|12.4(15)T1|SSH DOS confirmed, replaced with 12.4(15)T5
med-vuln|ios|12.4(10a)|SSH DOS confirmed, replaced with 12.4(18b)

######################################################################
# Below are the 'crit-vuln' versions confirmed for high criticality  #
######################################################################</pre>

#### Plugin Usage Example:

The plugin in 'discovery' mode, returns OK if the software version string could be fetched.

<pre>susie: ~ # ./check_snmp_patchlevel.pl -H 192.168.203.4 -g ios -C SECro
IOS Version: 12.1(22)EA9 | Cisco Internetwork Operating System Software
IOS (tm) C2950 Software (C2950-I6Q4L2-M), Version 12.1(22)EA9, RELEASE SOFTWARE (fc1)
Copyright (c) 1986-2006 by cisco Systems, Inc.
Compiled Fri 01-Dec-06 18:02 by weiliu</pre>

The plugin in 'compliance' mode, returns the status depending on the version string definition set in the supplied config file.

<pre>susie: ~ # ./check_snmp_patchlevel.pl -H 192.168.203.4 -g ios -C SECro -f  ./check_snmp_patchlevel.cfg
IOS Version: 12.1(22)EA9 obsolete | Remarks: end-of-maintenance date 2008-03-15 Data:
 Cisco Internetwork Operating System Software
IOS (tm) C2950 Software (C2950-I6Q4L2-M), Version 12.1(22)EA9, RELEASE SOFTWARE (fc1)
Copyright (c) 1986-2006 by cisco Systems, Inc.
Compiled Fri 01-Dec-06 18:02 by weiliu</pre>
