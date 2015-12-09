# check_tablespace_mssql

## Man page for the Nagios plugin check_tablespace_mssql

Copyright (c) 2010 Frank4DD<support[at]frank4dd.com>

### check_tablespace_mssql

* * *

This plugin checks the tablespace size of a specific Microsoft SQL Server database against WARN and CRIT thresholds. It returns the current tablespace size and the number of data and log files belonging to this database. The plugin can be called in 'reporting' mode, returning the space values withouth checking against a threshold. This is helpful if the tablespace only needs to be graphed as a trend over time.

It requires the database to be set up for accepting network connections and being reachable through that network port from Nagios. The plugin uses Microsoft's JDBC driver, this driver must be installed and found through the Java classpath on the server executing this plugin. [(JDBC installation example)](http://fm4dd.com/database/howto-install-Microsoft-jdbc.htm)

#### Usage:

`java -classpath <path to check_tablespace_mssql.class> check_tablespace_mssql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -d`  

`java -classpath <path to check_tablespace_mssql.class> check_tablespace_mssql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -r`  

`java -classpath <path to check_tablespace_mssql.class> check_tablespace_mssql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> <KB-warn> <KB-crit>`

#### Options:

[db-ip]  
      The IP address of the database server

[db-port]  
      The database network port, SQL server typically uses tcp port 1433

[db-instance]  
      The database instance name

[db-user]  
      The database user required for database login

[db-pwd]  
      The password of the database user. It can be enclosed in double-quotes to to accept special characters such as ;

-d  
      Enable debugging output, lists all available tablespaces

-r  
      Reporting tablespace size, always returns OK

[KB-warn] [KB-crit]  
      Set alert thresholds for WARN and CRIT in Kbytes

#### Plugin Usage Example:

The plugin in 'reporting' mode, returns OK if the tablespace size could be fetched.

<pre># java -classpath /srv/app/nagios/libexec/ check_tablespace_mssql 192.168.98.128 1433 contacts "sa" "dbpass" -r
Tablespace OK: contacts 408947 KBytes|contacts: 1 datafiles, 1 logfiles, used 408947 KB total</pre>

The plugin in 'check' mode, returns the status depending on the tablespace size exceeding the WARN and CRIT threshold values.

<pre># java -classpath /srv/app/nagios/libexec/ check_tablespace_mssql 192.168.98.128 1433 contacts "sa" "dbpass" 300000
 500000
Tablespace WARN: contacts 408947 KBytes|contacts: 1 datafiles, 1 logfiles, used 408947 KB</pre>

The plugin in 'debug' mode, showing individual data file sizes for this database.

<pre># java -classpath /srv/app/nagios/libexec/ check_tablespace_mssql 192.168.98.128 1433 contacts "sa" "dbpass" -d
DB connect: jdbc:sqlserver://1192.168.98.128:1433;databaseName=contacts;user=sa; password=dbpass;
File Name: D:\SQLServer\Data\Contacts.mdf Space used:     400000 KB
File Name: D:\SQLServer\Data\Contacts_log.ldf Space used:       8947 KB</pre>

#### Notes:

The plugin's .java source code file needs to be compiled into Java bytecode before it can be used, i.e. by calling:  
_javac check_tablespace_mssql.java_.
