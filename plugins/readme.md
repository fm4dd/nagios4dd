# Nagios Plugin List

Copyright (c) 2010 Frank4DD<support[at]frank4dd.com>

### Introduction

* * *

This is a set of Nagios plugins I developed or modified for the enterprise monitoring environments. All are made available under the GPL license for free re-use and further improvements.

The plugins have been tested to be working since Nagios version 3.x, and work with the latest Nagios versions under 4.x

### Operating System Monitoring Plugins

* * *

| # | Name | Ver. | Description | Usage |
|---|------|------|-------------|-------|
| 1 | [check_aix_update.pl](check_aix_update.pl) | 1.0 | Checks the patch update status on IBM AIX servers | [howto](/howto/aix-patch-update-monitoring.htm) |
| 2 | [win_update_trapsend.vbs](win_update_trapsend.vbs) | 1.0 | Checks the patch update status on Windows servers | [howto](/howto/windows-patch-update-monitoring.htm) |
| 3 | [check_rug_update.pl](check-rug-update.pl) | 1.1 | Checks the patch update status on SLES Linux servers | [howto](/howto/sles10-patch-update-monitoring.htm) |
| 4 | [check-rum-update.pl](check-rum-update.pl) | 1.0 | Checks the patch update status on OpeSUSE servers | [howto](/howto/opensuse-patch-update-monitoring.htm) |
| 5 | [check_zypper_update.pl](check-zypper-update.pl) | 1.0 | Checks the patch update status on OpenSUSE/SLES servers | [howto](/howto/sles10-patch-update-monitoring.htm) |
| 6 | [check_snmp_time.pl](check_snmp_time.pl) | 1.1 | Checks the operating systems time difference against Nagios server time | [manual](check_snmp_time.htm) |
| 7 | [check_snmp_aixload.pl](check_snmp_aixload.pl) | 1.0 | Reports IBM's AIX CPU load | [manual](check_snmp_aixload.htm) |

### Network, Firewall and PBX Device Monitoring Plugins

* * *

| # | Name | Ver. | Description | Usage |
|---|------|------|-------------|-------|
| 8 | [check_snmp_patchlevel.pl](check_snmp_patchlevel.pl) | 1.2 | Checks the Cisco OS version against a compliance list | [manual](check_snmp_patchlevel.md) |
| 9 | [check_avaya_load.pl](check_avaya_load.pl) | 1.0 | Checks the CPU load on Avaya VOIP PBX media servers | [manual](check_avaya_load.md) |
| 10 | [check_avaya_error.pl](check_avaya_error.pl) | 1.2 | Checks the error logs on Avaya VOIP PBX media servers | [manual](check_avaya_error.md) |
| 11 | [check_avaya_trunks.pl](check_avaya_trunks.pl) | 1.0 | Checks the call utilization of a trunk group on Avaya VOIP PBX media servers | [manual](check_avaya_trunks.md) |
| 12 | [check_avaya_peak.pl](check_avaya_peak.pl) | 1.0 | Checks the hourly peak call number on Avaya VOIP PBX media servers | [manual](check_avaya_peak.md) |
| 13 | [check_asa_sessions.pl](check_asa_sessions.pl) | 0.2 | Checks All, or IpSec, SslVPN and WebVPN sessions in a Cisco ASA | [manual](check_asa_sessions.md) |

### Database Monitoring Plugins

* * *

| # | Name | Ver. | Description | Usage |
|---|------|------|-------------|-------|
| 14 | [check_dbversion_db2.java](check_dbversion_db2.java) | 1.0 | Checks the DB2 software version against a compliance list | [manual](check_dbversion_db2.htm) |
| 15 | [check_dbversion_mssql.java](check_dbversion_mssql.java) | 1.0 | Checks the SQL server software version against a compliance list | [manual](check_dbversion_mssql.htm) |
| 16 | [check_dbversion_oracle.java](check_dbversion_oracle.java) | 1.0 | Checks the Oracle software version against a compliance list | [manual](check_dbversion_oracle.htm) |
| 17 | [check_dbversion_mysql.java](check_dbversion_mysql.java) | 1.0 | Checks the MySQL software version against a compliance list | [manual](check_dbversion_mysql.htm) |
| 18 | [check_dbversion_sybase.java](check_dbversion_sybase.java) | 1.0 | Checks the Sybase software version against a compliance list | [manual](check_dbversion_sybase.htm) |
| 19 | [check_dbversion_postgresql.java](check_dbversion_postgresql.java) | 1.0 | Checks the PostgreSQL software version against a compliance list | [manual](check_dbversion_postgresql.htm) |
| 20 | [check_tablespace_db2.java](check_tablespace_db2.java) | 1.0 | Checks DB2 tablespace sizes against warn and crit thresholds | [manual](check_tablespace_db2.htm) |
| 21 | [check_tablespace_mssql.java](check_tablespace_mssql.java) | 1.0 | Checks SQL Server tablespace sizes against warn and crit thresholds | [manual](check_tablespace_mssql.htm) |
| 22 | [check_tablespace_oracle.java](check_tablespace_oracle.java) | 1.0 | Checks Oracle tablespace sizes against warn and crit thresholds | [manual](check_tablespace_oracle.htm) |
| 23 | [check_tablespace_mysql.java](check_tablespace_mysql.java) | 1.0 | Checks MySQL tablespace sizes against warn and crit thresholds | [manual](check_tablespace_mysql.htm) |

### Web Monitoring Plugins

* * *

| # | Name | Ver. | Description | Usage |
|---|------|------|-------------|-------|
| 24 | [check_apachestatus.pl](check_apachestatus.pl) | 1.6 | Checks the apache sessions through the mod_status module | [howto](/howto/apache-session-monitoring-nagios.htm) |
| 25 | [check_http.c](check_http.c) | 2.0 | Checks HTTP/S (SSL) websites through a proxy using the CONNECT method | [howto](/howto/monitor-ssl-websites-through-proxy.htm) |
| 26 | [check_http_time.pl](check_http_time.pl) | 1.0 | Checks the remote web server time difference against Nagios server time | [manual](check_http_time.htm) |

### Other Monitoring Plugins

* * *

| # | Name | Ver. | Description | Usage |
|---|------|------|-------------|-------|
| 27 | [check_ldap_lockout.c](check_ldap_lockout.c) | 1.2 | Checks if a given Windows domain user has been locked out (to many wrong password entries) | [manual](check_ldap_lockout.htm) |
| 28 | [check_tokyo_radiation.pl](check_tokyo_radiation.pl) | 1.1 | Checks Tokyo air radiation levels published by Tokyo Metropolitan Government | [howto](/howto/nagios-monitoring-2011-tokyo-radiation.htm) |
| 29 | [check_tokyo_tapwater.pl](check_tokyo_tapwater.pl) | 1.0 | Checks Tokyo tapwater radiation levels published by Tokyo Metropolitan Government | [howto](/howto/nagios-monitoring-2011-tokyo-radiation.htm) |
| 30 | [check_tokyo_power.pl](check_tokyo_power.pl) | 1.0 | Checks Tokyo metropolitan electric power consumption published by Tepco | [howto](/howto/nagios-monitoring-2011-tokyo-radiation.htm) |
| 31 | [check_fail2ban.sh](check_fail2ban.sh) | 1.2 | Monitors the number of IP's blocked by fail2ban, and gives feedback on brute-force attacks | [manual](check_fail2ban.htm) |
| 32 | [check_nagiostats.pl](check_nagiostats.pl) | 1.0 | Checks Nagios plugin execution time, and host or service config totals. | [manual](check_nagiostats.htm) |
