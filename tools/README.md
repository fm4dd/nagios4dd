# nagios4dd - tools

Nagios tools

A repeating task is to identify systems responding to SNMP on the network. Manually executing ping and snmpwalk for a larger number of IP becomes tiresome. Using a professional security scanner is overkill. 

1. find-snmp.pl

A small perl script 'find-snmp.pl' is lightweight and flexible to adapt, allowing us to check variations in SNMP communities with ease. I use it frequently to verify if a system has been SNMP-configured, or to scan a network for changes.

Below is a example run:

`susie:/home/fm/snmp-queries # ./find-snmp.pl 192.168.50 20 35`
`Checking 192.168.50.20... Host does not exist.`
`Checking 192.168.50.21... Host does not exist.`
`Checking 192.168.50.22... Host does not exist.`
`Checking 192.168.50.23... Host 192.168.50.23 alive... No-SNMP(1) No-SNMP(2) No-SNMP(3) No-SNMP(4) No-SNMP(5)`
`Checking 192.168.50.24... Host 192.168.50.24 alive... No-SNMP(1) No-SNMP(2) No-SNMP(3) No-SNMP(4) No-SNMP(5)`
Checking 192.168.50.25... Host does not exist.
Checking 192.168.50.26... Host does not exist.
Checking 192.168.50.27... Host does not exist.
Checking 192.168.50.28... Host does not exist.
Checking 192.168.50.29... Host does not exist.
Checking 192.168.50.30... Host does not exist.
Checking 192.168.50.31... Host 192.168.50.31 alive... Found: CISCO09F55203.fm4dd.com (SECro)
Checking 192.168.50.32... Host 192.168.50.32 alive... Found: CISCO09F55204.fm4dd.com (SECro)
Checking 192.168.50.33... Host does not exist.
Checking 192.168.50.34... Host does not exist.
Checking 192.168.50.35... Host does not exist.`

Enjoy.
For more resources on Nagios and SNMP, see http://nagios.fm4dd.com/
