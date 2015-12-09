# check_tablespace_db2

## Man page for the Nagios plugin check_tablespace_db2

Copyright (c) 2010 Frank4DD<support[at]frank4dd.com>

### check_tablespace_db2

* * *

This plugin checks the tablespace size of a specific IBM DB2 database against WARN and CRIT thresholds. It returns the total tablespace size, current size, space utilisation in percent and the number of data files belonging to this tablespace. The plugin can be called in 'reporting' mode, returning the space values withouth checking against a threshold. This is helpful if the tablespace only needs to be graphed as a trend over time.

It requires the database to be set up for accepting network connections and being reachable through that network port from Nagios. The plugin uses IBM's DB2 JDBC driver, this driver must be installed and found through the Java classpath on the server executing this plugin. [(JDBC installation example)](http://fm4dd.com/database/howto-install-IBMdb2-jdbc.htm)

#### Usage:

`java -classpath <path to check_tablespace_db2.class> check_tablespace_db2 <db-ip> <db-port> <db-instance> <db-user> <db-pwd> [-d]`  

`java -classpath <path to check_tablespace_db2.class> check_tablespace_db2 <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -r <tablespace-name>`  

`java -classpath <path to check_tablespace_db2.class> check_tablespace_db2 <db-ip> <db-port> <db-instance> <db-user> <db-pwd> <tablespace-name> <KB-warn> <KB-crit>`

#### Options:

[db-ip]  
      The IP address of the database server

[db-port]  
      The database network port, DB2 typically uses tcp port 50000

[db-instance]  
      The database instance name

[db-user]  
      The database user required for database login

[db-pwd]  
      The password of the database user. It can be enclosed in double-quotes to to accept special characters such as ;

-d  
      Enable debugging output, lists all available tablespaces

-r <tablespace>  
      Reporting tablespace size, always returns OK

<tablespace> <KB-warn> <KB-crit>  
      Set tablesapce name and alert thresholds for WARN and CRIT in Kbytes

#### Plugin Usage Example:

The plugin in 'reporting' mode, returns OK if the tablespace size could be fetched.

<pre># java -classpath /srv/app/nagios/libexec/ check_tablespace_db2 192.168.1.64 50000 DB2 db2admin "p@ssw0rd" -r
 USERSPACE1
Tablespace OK: USERSPACE1 11% used|USERSPACE1: 3 datafiles, used 732032 KB of 6291456 KB total</pre>

The plugin in 'check' mode, returns the status depending on the tablespace size exceeding the WARN and CRIT threshold values.

<pre># java -classpath /srv/app/nagios/libexec/ check_dbversion_db2 192.168.1.64 50000 DB2 db2admin "p@ssw0rd" USERSPACE1
 732032 732034
Tablespace WARN: USERSPACE1 11% used|USERSPACE1: 3 datafiles, used 732032 KB of 6291456 KB total</pre>

The plugin in 'debug' mode, listing all tablespaces configured for this database.

<pre># java -classpath /srv/app/nagios/libexec/ check_dbversion_db2 192.168.1.64 50000 DB2 db2admin "p@ssw0rd" -d
DB connect: jdbc:db2://192.168.1.64:50000/DB2
DB query: select TBSP_NAME, TBSP_NUM_CONTAINERS, TBSP_TOTAL_SIZE_KB, TBSP_USED_SIZE_KB,
 TBSP_UTILIZATION_PERCENT FROM SYSIBMADM.TBSP_UTILIZATION where TBSP_TOTAL_SIZE_KB > 0
Name:           USERSPACE1 Files:  3 Space total:    6291456 KB Space used:     732032 KB Space % used:  11 %
Name:         SYSTOOLSPACE Files:  1 Space total:      32768 KB Space used:       1776 KB Space % used:   5 %
Name:           USERSPACE2 Files:  5 Space total:   20971520 KB Space used:    1660416 KB Space % used:   7 %
Name:           USERSPACE3 Files:  4 Space total:   16777216 KB Space used:    2671616 KB Space % used:  15 %
Name:           USERSPACE4 Files:  2 Space total:    8388608 KB Space used:      29440 KB Space % used:   0 %
Name:           USERSPACE5 Files:  1 Space total:    1048576 KB Space used:        384 KB Space % used:   0 %
Name:           USERSPACE6 Files:  1 Space total:    1048576 KB Space used:      41600 KB Space % used:   3 %
Name:           USERSPACE7 Files:  1 Space total:    1048576 KB Space used:      53120 KB Space % used:   5 %
Name:           USERSPACE8 Files:  1 Space total:    1048576 KB Space used:      70016 KB Space % used:   6 %
Name:           USERSPACE9 Files:  1 Space total:    1048576 KB Space used:      77696 KB Space % used:   7 %
Name:          USERSPACE10 Files:  1 Space total:    1048576 KB Space used:     296448 KB Space % used:  28 %</pre>

#### Notes:

The plugin's .java source code file needs to be compiled into Java bytecode before it can be used, i.e. by calling:  
_javac check_tablespace_db2.java_.
