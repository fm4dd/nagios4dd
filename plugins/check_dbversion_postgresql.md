# check_dbversion_postgresql

## Man page for the Nagios plugin check_dbversion_postgresql

Copyright (c) 2014 Frank4DD<support[at]frank4dd.com>

### check_dbversion_postgresql

**Note: This plugin is not widely tested. Please consider feedback to improve it, or to confirm its OK. Thank You!**

This plugin tests the database software version through querying a specific PostgreSQL database. It can either simply return the version string (discovery mode), or compare it against a blacklist/whitelist version file to determine software version compliance (compliance mode). Since it executes a real database login, it can also be used to determine database up|down.

It requires the database to be set up for accepting network connections and being reachable through that network port from Nagios. The plugin uses the free PostgreSQL JDBC driver, this driver must be installed and found through the Java classpath on the server executing this plugin. [(JDBC installation example)](http://fm4dd.com/database/howto-install-PostgreSQL-jdbc.htm)

#### Usage:

`java -classpath <path to check_dbversion_postgresql.class> check_dbversion_postgresql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> [-d]`  

`java -classpath <path to check_dbversion_postgresql.class> check_tablespace_postgresql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -f configfile`

#### Options:

[db-ip]  
      The IP address of the database server

[db-port]  
      The database network port, PostgreSQL typically uses tcp port 5432

[db-instance]  
      The database instance name

[db-user]  
      The database user required for database login

[db-pwd]  
      The password of the database user. It can be enclosed in double-quotes to to accept special characters such as ;

-d  
      Enable debugging output

-f configfile  
      Compare the returned software version string against a blacklist/whitelist file

#### Configuration File Format:

The blacklist/whitelist file for comparing database versions against consists of database version lines separated into 4 columns. The column separator character is defined as '|'. The file can contain comment lines, identified through the first line character '#'.

**Column 1** contains one of the following strings 'approved', 'obsolete', 'med-vuln' or 'cri-vuln'. Versions marked 'approved' will return 'OK' (green) in Nagios. The marker 'approved' is meant for versions that are confirmed to be recent, without known vulnerabilities (yet) or otherwise desired by IT networks/management, i.e. for standardization. Versions marked 'obsolete' will return 'WARNING' (yellow). This is is meant for versions that are EOL, but not confirmed vulnerable yet. It is highly undesired to run these versions. Versions marked 'med-vuln' will return 'WARNING' (yellow). This is is meant for versions that are confirmed to have vulnerabilities who are either currently not applicable, or rated low to medium with compensations in place. We desire to upgrade these versions in a planned fashion. Versions marked 'crit-vuln' will return 'CRITICAL' (red). This is is meant for versions that are confirmed to be vulnerable with a high risk of immediate impact data loss or database access is compromised. These versions should be upgraded as soon as possible. Versions that are neither 'approved', 'obsolete' or 'vulnerable' will return 'UNKNOWN' (orange) in Nagios. This is meant as a note to check if this version is OK to run, so it can be categorized.

**Column 2** contains the DB vendor string, supported strings are 'postgresql', 'db2', 'mssql', 'mysql' and 'oracle'.

**Column 3** contains the DB Version string as returned by the plugin. This string must match exactly the plugins returned value. If unsure, run the plugin in discovery mode, i.e. without the -f <file>

**Column 4** contains a remarks string, i.e. reason for marked 'obsolete'. This column may be left empty, but it is a good idea to use it for information about this particular version, i.e. list vulnerabilities or the vendors end-of-life date.

#### Configuration File Example:

    ######################################################################
    # Below are the 'approved' versions we explicitly endorse for usage: #
    ######################################################################
    approved|pgsql|PostgreSQL 9.3.2 on x86_64-unknown-linux-gnu 64-bit|Installed from Source 20140124
    approved|sybase|Adaptive Server Enterprise v15.7 ase157sp101, 3439|Latest Version 15.7 SP1, 6 Jun 2013
    approved|mssql|Microsoft SQL Server v9.00.4285.00 SP2|Latest Release 9.00.3175 SP3 + Update 8, February 16th 2010
    approved|mysql|MySQL v5.0.67|Novell SLES11 software repository version of MySQL
    approved|db2|DB2 v9.7.0.1 build s091114|Latest Version 9.7 Fixpack 1, Release Date 24 Nov 2009
    approved|db2|DB2 v9.7.100.177 build s091114|Latest Windows 64bit Version 9.7 Fixpack 1, Release Date 24 Nov 2009
    ######################################################################
    # Below are the 'obsolete' versions we explicitly disapprove of:     #
    ######################################################################
    obsolete|mssql|Microsoft SQL Server v8.00.2055 SP4|SQL 2000 SP4 mainstream support end 4/8/2008, http://blogs.msdn.com/b/sqlreleaseservices/archive/2008/02/15/end-of-mainstream-support-for-sql-server-2005-sp1-and-sql-server-2000-sp4.aspx
    ######################################################################
    # Below are the 'med-vuln' versions with low to medium criticality   #
    ######################################################################
    med-vuln|db2|DB2 v9.7.0.441 build s090521|Needs 9.7.100.177 (FP-1) Build Level s091114, Release Date 24 Nov 2009, vulnerabilities listed here: http://www-01.ibm.com/support/docview.wss?rs=71&uid=swg21412182
    med-vuln|db2|DB2 v9.7.0.0 build s090521|Needs 9.7.0.1 (FP-1) Build Level s091114, Release Date 24 Nov 2009, vulnerabilities listed here: http://www-01.ibm.com/support/docview.wss?rs=71&uid=swg21412182
    med-vuln|oracle|Oracle v10.2.0.1.0|Vulnerable, latest patch release is v10.2.0.5.0, see http://www.oracle.com/technology/deploy/security/alerts.htm
    med-vuln|oracle|Oracle v10.2.0.3.0|Vulnerable, latest patch release is v10.2.0.5.0, see http://www.oracle.com/technology/deploy/security/alerts.htm
    ######################################################################
    # Below are the 'crit-vuln' versions confirmed for high criticality  #
    ######################################################################

#### Plugin Usage Example:

The plugin in 'discovery' mode, returns OK if the software version string could be fetched.

<pre># java -classpath /srv/app/nagios/libexec/ check_dbversion_postgresql 192.168.1.127 5432 postgres pgsql p0stpass
Version OK: PostgreSQL 9.3.2 on x86_64-unknown-linux-gnu 64-bit|</pre>

The plugin in 'compliance' mode, returns the status depending on the version string definition set in the supplied config file.

<pre># java -classpath /srv/app/nagios/libexec/ check_dbversion_postgresql 192.168.1.127 5432 postgres pgsql p0stpass -f
 /srv/app/nagios/libexec/check_dbversion.cfg
Version OK: PostgreSQL 9.3.2 on x86_64-unknown-linux-gnu 64-bit|Installed from Source 20140124</pre>

#### Notes:

The plugin queries PostgreSQL with the "SELECT version()"command. The PostgreSQL database responds with a version string containing 3 fields, separated by a comma. A string example is below.

`PostgreSQL 9.3.2 on x86_64-unknown-linux-gnu, compiled by gcc (SUSE Linux) 4.7.2 20130108 [gcc-4_7-branch revision 195012], 64-bit`

The plugin's .java source code file needs to be compiled into Java bytecode before it can be used, i.e. by calling:  
_javac check_dbversion_postgresql.java_.

By default, PostgreSQL is very restrictive, and does not allow remote network connections. Initially, only localhost (127.0.0.1) connections may work.
