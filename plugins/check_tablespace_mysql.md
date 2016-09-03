# check_tablespace_mysql

## Man page for the Nagios plugin check_tablespace_mysql

Copyright (c) 2010 Frank4DD<support[at]frank4dd.com>

### check_tablespace_mysql

This plugin checks the schema size of a specific MySQL Server database against WARN and CRIT thresholds. It returns the current database size and the number of tables belonging to this database. The plugin can be called in 'reporting' mode, returning the space values withouth checking against a threshold. This is helpful if the size only needs to be graphed as a trend over time.

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
      Set alert thresholds for WARN and CRIT in bytes

#### Plugin Usage Example:

The plugin in 'reporting' mode, returns OK if the tablespace size could be fetched.

<pre># java -classpath /srv/app/nagios/libexec/ check_tablespace_mysql 192.168.98.128 3306 edacs "edacsread" "dbpass" -r
OK - edacs 59.88 MB used|bytes_used=62783488;; table_count=9</pre>

The plugin in 'check' mode, returns the status depending on the tablespace size exceeding the WARN and CRIT threshold values.

<pre># java -classpath /srv/app/nagios/libexec/ check_tablespace_mysql 192.168.98.128 3306 edacs "edacsread" "dbpass"
 40000000 70000000
WARN - Schema edacs 59.88 MB used|bytes_used=62783488;; table_count=9</pre>

The plugin in 'debug' mode, showing individual table sizes for this database.

<pre># java -classpath /srv/app/nagios/libexec/ check_tablespace_mysql 192.168.98.128 3306 edacs "edacsread" "dbpass" -d
DB connect: jdbc:mysql://192.168.98.128:3306/edacs?user=edacsread&password=dbpass
Table Name: edacs_daystats            Table Type: BASE TABLE      Space used: 80.00 KB
Table Name: edacs_mainlog             Table Type: BASE TABLE      Space used: 26.70 MB
Table Name: edacs_monstats            Table Type: BASE TABLE      Space used: 16.00 KB
Table Name: edacs_remote              Table Type: BASE TABLE      Space used: 352.00 KB
Table Name: edacs_router              Table Type: BASE TABLE      Space used: 16.00 KB
Table Name: edacs_service             Table Type: BASE TABLE      Space used: 16.00 KB
Table Name: edacs_templog             Table Type: BASE TABLE      Space used: 32.64 MB
Table Name: edacs_users               Table Type: BASE TABLE      Space used: 48.00 KB
Table Name: edacs_version             Table Type: BASE TABLE      Space used: 16.00 KB
Table Name: v_edacs                   Table Type: VIEW            Space used: 0.00 Bytes</pre>

Nagios Graph:

Visualizing the tablespace can identify a trend in growth to determine the need for additional storage.

![](images/check_tablespace_mysql-example1.png)

#### Notes:

The plugin's .java source code file needs to be compiled into Java bytecode before it can be used, i.e. by calling:  
_javac check_tablespace_mysql.java_.
