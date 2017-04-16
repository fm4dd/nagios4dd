# nagios4dd - graph 

Nagios graph generation

1. process_perfdata.pl

This is a modified data collector script from PNP4Nagios v0.6.17 (2012). Its code has been merged with the data collector script from Nagiosgraph. It creates/updates the RRD data for both packages in parallel.

Below is a a sample log data output:

```
2017-04-17 07:49:02 [6694] [1] process_perfdata.pl-0.6.17 starting in BULK Mode called by Nagios
2017-04-17 07:49:02 [6694] [1] 0 lines processed
2017-04-17 07:49:02 [6694] [1] /srv/app/nagiosgraph/log/host-perfdata.log-PID-6694 deleted
2017-04-17 07:49:02 [6694] [1] PNP exiting (runtime 0.000241s) ...
2017-04-17 07:49:02 [6697] [1] process_perfdata.pl-0.6.17 starting in BULK Mode called by Nagios
2017-04-17 07:49:02 [6697] [1] PNP4Nagios: Found Performance Data for susie / nagios_hosts (count=3)
2017-04-17 07:49:02 [6697] [1] Nagiosgraph formatted: 1492382912||susie||nagios_hosts||OK: 3 Nagios host checks||count=3
2017-04-17 07:49:02 [6697] [1] Nagiosgraph RRD: Checking /srv/app/nagiosgraph/rrd/susie/nagios_hosts___Nagios_Config.rrd
2017-04-17 07:49:02 [6697] [1] Nagiosgraph RRD: Confirmed /srv/app/nagiosgraph/rrd/susie/nagios_hosts___Nagios_Config.rrd
2017-04-17 07:49:02 [6697] [1] Nagiosgraph RRD: Updated /srv/app/nagiosgraph/rrd/susie/nagios_hosts___Nagios_Config.rrd 1492382912
2017-04-17 07:49:02 [6697] [1] PNP4Nagios: Found Performance Data for susie / nagios_open_files (ProcCount=6FDs FDCount=58FDs ProcFDAvg=9FDs PerProcMaxFD=14FDs)
2017-04-17 07:49:02 [6697] [1] Nagiosgraph formatted: 1492382912||susie||nagios_open_files||UNIX_OPEN_FDS OK - nagios handling 58 files||ProcCount=6FDs FDCount=58FDs ProcFDAvg=9FDs PerProcMaxFD=14FDs
2017-04-17 07:49:02 [6697] [1] Nagiosgraph RRD: Checking /srv/app/nagiosgraph/rrd/susie/nagios_open_files___nagios_open_files.rrd
2017-04-17 07:49:02 [6697] [1] Nagiosgraph RRD: Confirmed /srv/app/nagiosgraph/rrd/susie/nagios_open_files___nagios_open_files.rrd
2017-04-17 07:49:02 [6697] [1] Nagiosgraph RRD: Updated /srv/app/nagiosgraph/rrd/susie/nagios_open_files___nagios_open_files.rrd 1492382912
2017-04-17 07:49:02 [6697] [1] PNP4Nagios: Found Performance Data for susie / db_querycache_kanji (qcache_hitrate=94.09%;60:;30: qcache_hitrate_now=94.29% selects_per_sec=0.03)
2017-04-17 07:49:02 [6697] [1] Nagiosgraph formatted: 1492382912||susie||db_querycache_kanji||OK - query cache hitrate 94.09%||qcache_hitrate=94.09%;60:;30: qcache_hitrate_now=94.29% selects_per_sec=0.03
2017-04-17 07:49:02 [6697] [1] Nagiosgraph RRD: Checking /srv/app/nagiosgraph/rrd/susie/db_querycache_kanji___query_cache.rrd
2017-04-17 07:49:02 [6697] [1] Nagiosgraph RRD: Confirmed /srv/app/nagiosgraph/rrd/susie/db_querycache_kanji___query_cache.rrd
2017-04-17 07:49:02 [6697] [1] Nagiosgraph RRD: Updated /srv/app/nagiosgraph/rrd/susie/db_querycache_kanji___query_cache.rrd 1492382912
2017-04-17 07:49:02 [6697] [1] 3 lines processed
...
2017-04-17 07:48:32 [6614] [1] /srv/app/nagiosgraph/log/host-perfdata.log-PID-6614 deleted
2017-04-17 07:48:32 [6614] [1] PNP exiting (runtime 0.004861s) ...
```

Enjoy.
For more resources on Nagios and SNMP, see http://nagios.fm4dd.com/
