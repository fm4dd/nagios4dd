# check_tablespace_mysql

## Man page for the Nagios plugin check_tablespace_mysql

Copyright (c) 2010 Frank4DD<support[at]frank4dd.com>

### check_tablespace_mysql

* * *

This plugin checks the tablespace size of a specific MySQL Server database against WARN and CRIT thresholds. It returns the current tablespace size and the number of data files belonging to this database. The plugin can be called in 'reporting' mode, returning the space values withouth checking against a threshold. This is helpful if the tablespace only needs to be graphed as a trend over time.

It requires the database to be set up for accepting network connections and being reachable through that network port from Nagios. The plugin uses the MySQL JDBC driver, this driver must be installed and found through the Java classpath on the server executing this plugin. [(JDBC installation example)](http://fm4dd.com/database/howto-install-MySQL-jdbc.htm)

#### Usage:

`java -classpath <path to check_tablespace_mysql.class> check_tablespace_mysql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -d`  

`java -classpath <path to check_tablespace_mysql.class> check_tablespace_mysql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -r`  

`java -classpath <path to check_tablespace_mysql.class> check_tablespace_mysql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> <KB-warn> <KB-crit>`

#### Options:

[db-ip]  
      The IP address of the database server

[db-port]  
      The database network port, MySQL typically uses tcp port 3306

[db-instance]  
      The database instance name

[db-user]  
      The database user required for database login

[db-pwd]  
      The password of the database user. It can be enclosed in double-quotes to to accept special characters such as ;

-d  
      Enable debugging output, lists all table sizes

-r  
      Reporting tablespace size, always returns OK

[KB-warn] [KB-crit]  
      Set alert thresholds for WARN and CRIT in Kbytes

#### Plugin Usage Example:

The plugin in 'reporting' mode, returns OK if the tablespace size could be fetched.

<pre># java -classpath /srv/app/nagios/libexec/ check_tablespace_mysql 192.168.98.128
 3306 edacs "edacsread" "dbpass" -r
Tablespace OK: edacs 4961 KBytes|edacs: 27 datafiles, 4961 KB</pre>

The plugin in 'check' mode, returns the status depending on the tablespace size exceeding the WARN and CRIT threshold values.

<pre># java -classpath /srv/app/nagios/libexec/ check_tablespace_mysql 192.168.98.128
 3306 edacs "edacsread" "dbpass" 4000 5000
Tablespace WARN: edacs 4961 KBytes|edacs: 27 datafiles, 4961 KB</pre>

The plugin in 'debug' mode, showing individual data file sizes for this database.

<pre># java -classpath /srv/app/nagios/libexec/ check_tablespace_mysql 192.168.98.128
 3306 edacs "edacsread" "dbpass" -d
DB connect: jdbc:mysql://192.168.98.128:3306/edacs?user=edacsread&password=dbpass
File Name:       edacs_daystats Space used:         11 KB
File Name:        edacs_mainlog Space used:       1520 KB
File Name:       edacs_monstats Space used:          2 KB
File Name:         edacs_remote Space used:         43 KB
File Name:         edacs_router Space used:          2 KB
File Name:        edacs_service Space used:          2 KB
File Name:        edacs_templog Space used:       3364 KB
File Name:          edacs_users Space used:         15 KB
File Name:        edacs_version Space used:          2 KB</pre>

#### Notes:

The plugin's .java source code file needs to be compiled into Java bytecode before it can be used, i.e. by calling:  
_javac check_tablespace_mysql.java_.
