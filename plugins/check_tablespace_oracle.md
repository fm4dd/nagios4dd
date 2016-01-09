# check_tablespace_oracle

## Man page for the Nagios plugin check_tablespace_oracle

Copyright (c) 2010 Frank4DD<support[at]frank4dd.com>

### check_tablespace_oracle

This plugin checks the tablespace size of a specific Oracle database against WARN and CRIT thresholds. It returns the total tablespace size, current size, space utilisation in percent and the number of data files belonging to this tablespace. The plugin can be called in 'reporting' mode, returning the space values withouth checking against a threshold. This is helpful if the tablespace only needs to be graphed as a trend over time.

It requires the database to be set up for accepting network connections and being reachable through that network port from Nagios. The plugin uses Oracle's JDBC driver, this driver must be installed and found through the Java classpath on the server executing this plugin. [(JDBC installation example)](http://fm4dd.com/database/howto-install-Oracle-jdbc.htm)

#### Usage:

`java -classpath <path to check_tablespace_oracle.class> check_tablespace_oracle <db-ip> <db-port> <db-instance> <db-user> <db-pwd> [-d]`  

`java -classpath <path to check_tablespace_oracle.class> check_tablespace_oracle <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -r <tablespace-name>`  

`java -classpath <path to check_tablespace_oracle.class> check_tablespace_oracle <db-ip> <db-port> <db-instance> <db-user> <db-pwd> <tablespace-name> <KB-warn> <KB-crit>`

#### Options:

[db-ip]  
      The IP address of the database server

[db-port]  
      The database network port, Oracle typically uses tcp port 1521

[db-instance]  
      The database instance name

[db-user]  
      The database user required for database login

[db-pwd]  
      The password of the database user. It can be enclosed in double-quotes to to accept special characters such as ;

-d  
      Enable debugging output, lists all available tablespaces

-r [tablespace]  
      Reporting tablespace size, always returns OK

[tablespace] [KB-warn> [KB-crit]  
      Set tablespace name and alert thresholds for WARN and CRIT in Kbytes

#### Plugin Usage Example:

The plugin in 'reporting' mode, returns OK if the tablespace size could be fetched.

<pre># java -classpath /srv/app/nagios/libexec/ check_tablespace_oracle 192.168.98.151 1521  ORADB system "p@ssw0rd" -r
 G02IND01
Tablespace OK: G02IND01 20% used|G02IND01: 3 datafiles, used 5120 KB of 9216 KB total</pre>

The plugin in 'check' mode, returns the status depending on the tablespace size exceeding the WARN and CRIT threshold values.

<pre># java -classpath /srv/app/nagios/libexec/ check_tablespace_oracle 192.168.98.151 1521  ORADB system "p@ssw0rd"
 G02IND01 5120 5121
Tablespace WARN: G02IND01 20% used|G02IND01: 3 datafiles, used 5120 KB of 9216 KB total</pre>

The plugin in 'debug' mode, listing all tablespaces configured for this database.

<pre># java -classpath /srv/app/nagios/libexec/ check_tablespace_oracle 192.168.1.151 1521  ORADB system "p@ssw0rd" -d
DB connect: jdbc:oracle:thin:system/p@ssw0rd@1192.168.1.151:1521:ORADB
DB query: select  df.TABLESPACE_NAME, df.FILE_ID, ((df.BYTES+fs.BYTES)/1024)
 kbytes_max, (df.BYTES/1024) kbytes_used, round(((df.BYTES - fs.BYTES) /
 df.BYTES) * 100) usage_pct from ( select  TABLESPACE_NAME, sum(BYTES) 
BYTES, count(distinct FILE_ID) FILE_ID from dba_data_files group by 
TABLESPACE_NAME ) df, ( select TABLESPACE_NAME, sum(BYTES) BYTES from 
dba_free_space group by TABLESPACE_NAME) fs where df.TABLESPACE_NAME=
fs.TABLESPACE_NAME order by df.TABLESPACE_NAME asc
Name:             G02IND01 Files:  3 Space total:       9216 KB Space used:       5120 KB Space % used:  20 %
Name:             G02IND02 Files:  3 Space total:       9280 KB Space used:       5120 KB Space % used:  19 %
Name:             G02IND03 Files:  3 Space total:       9280 KB Space used:       5120 KB Space % used:  19 %
Name:             G02IND04 Files:  3 Space total:       9280 KB Space used:       5120 KB Space % used:  19 %
Name:             G02IND05 Files:  3 Space total:       9216 KB Space used:       5120 KB Space % used:  20 %
Name:             G02IND06 Files:  3 Space total:       9216 KB Space used:       5120 KB Space % used:  20 %
Name:             G02IND07 Files:  3 Space total:       9216 KB Space used:       5120 KB Space % used:  20 %
Name:             G02IND08 Files:  3 Space total:       9088 KB Space used:       5120 KB Space % used:  23 %
Name:             G02IND09 Files:  2 Space total:      39552 KB Space used:      20480 KB Space % used:   7 %
Name:             G02TAB01 Files:  1 Space total:       8960 KB Space used:       5120 KB Space % used:  25 %</pre>

#### Notes:

The plugin's .java source code file needs to be compiled into Java bytecode before it can be used, i.e. by calling:  
_javac check_tablespace_oracle.java_.
