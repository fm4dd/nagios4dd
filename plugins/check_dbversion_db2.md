# check_dbversion_db2

## Man page for the Nagios plugin check_dbversion_db2

Copyright (c) 2010 Frank4DD<support[at]frank4dd.com>

### check_dbversion_db2

* * *

This plugin tests the database software version through querying a specific IBM DB2 database. It can either simply return the version string (discovery mode), or compare it against a blacklist/whitelist version file to determine software version compliance (compliance mode). Since it executes a real database login, it can also be used to determine database up|down.

It requires the database to be set up for accepting network connections and being reachable through that network port from Nagios. The plugin uses IBM's DB2 JDBC driver, this driver must be installed and found through the Java classpath on the server executing this plugin. [(JDBC installation example)](http://fm4dd.com/database/howto-install-IBMdb2-jdbc.htm)

### Usage:

* * *

`java -classpath <path to check_dbversion_db2.class> check_dbversion_db2 <db-ip> <db-port> <db-instance> <db-user> <db-pwd> [-d]` `java -classpath <path to check_dbversion_db2.class> check_tablespace_db2 <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -f configfile`

### Options:

* * *

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
      Enable debugging output

-f configfile  
      Compare the returned software version string against a blacklist/whitelist file

### Configuration File Format:

The blacklist/whitelist file for comparing database versions against consists of database version lines separated into 4 columns. The column separator character is defined as '|'. The file can contain comment lines, identified through the first line character '#'.

**Column 1** contains one of the following strings 'approved', 'obsolete', 'med-vuln' or 'cri-vuln'. Versions marked 'approved' will return 'OK' (green) in Nagios. The marker 'approved' is meant for versions that are confirmed to be recent, without known vulnerabilities (yet) or otherwise desired by IT networks/management, i.e. for standardization. Versions marked 'obsolete' will return 'WARNING' (yellow). This is is meant for versions that are EOL, but not confirmed vulnerable yet. It is highly undesired to run these versions. Versions marked 'med-vuln' will return 'WARNING' (yellow). This is is meant for versions that are confirmed to have vulnerabilities who are either currently not applicable, or rated low to medium with compensations in place. We desire to upgrade these versions in a planned fashion. Versions marked 'crit-vuln' will return 'CRITICAL' (red). This is is meant for versions that are confirmed to be vulnerable with a high risk of immediate impact data loss or database access is compromised. These versions should be upgraded as soon as possible. Versions that are neither 'approved', 'obsolete' or 'vulnerable' will return 'UNKNOWN' (orange) in Nagios. This is meant as a note to check if this version is OK to run, so it can be categorized.

**Column 2** contains the DB vendor string, supported strings are 'db2', 'mssql', 'mysql' and 'oracle'.

**Column 3** contains the DB Version string as returned by the plugin. This string must match exactly the plugins returned value. If unsure, run the plugin in discovery mode, i.e. without the -f <file>

**Column 4** contains a remarks string, i.e. reason for marked 'obsolete'. This column may be left empty, but it is a good idea to use it for information about this particular version, i.e. list vulnerabilities or the vendors end-of-life date.

### Configuration File Example:

* * *

    ######################################################################
    # Below are the 'approved' versions we explicitly endorse for usage: #
    ######################################################################
    approved|db2|DB2 v9.5.0.5 build s091123|Latest Version 9.5 Fixpack 5, Release Date 14 Dec 2009
    approved|mssql|Microsoft SQL Server v9.00.4285.00 SP2|Latest Release 9.00.3175 SP3 + Update 8, February 16th 2010
    approved|mysql|MySQL v5.0.67|Novell SLES11 software repository version of MySQL
    approved|mysql|MySQL v5.0.26|Novell SLES10 SP3 software repository version of MySQL
    approved|db2|DB2 v9.7.0.1 build s091114|Latest Version 9.7 Fixpack 1, Release Date 24 Nov 2009
    approved|db2|DB2 v9.7.100.177 build s091114|Latest Windows 64bit Version 9.7 Fixpack 1, Release Date 24 Nov 2009
    ######################################################################
    # Below are the 'obsolete' versions we explicitly disapprove of:     #
    ######################################################################
    obsolete|mssql|Microsoft SQL Server v8.00.818 SP3|SQL 2000 SP3 retired 7/10/2007, http://support.microsoft.com/lifecycle/?p1=2852
    obsolete|mssql|Microsoft SQL Server v8.00.760 SP3|SQL 2000 SP3 retired 7/10/2007, http://support.microsoft.com/lifecycle/?p1=2852
    obsolete|mssql|Microsoft SQL Server v8.00.2055 SP4|SQL 2000 SP4 mainstream support end 4/8/2008, http://blogs.msdn.com/b/sqlreleaseservices/archive/2008/02/15/end-of-mainstream-support-for-sql-server-2005-sp1-and-sql-server-2000-sp4.aspx
    ######################################################################
    # Below are the 'med-vuln' versions with low to medium criticality   #
    ######################################################################
    med-vuln|db2|DB2 v9.7.0.441 build s090521|Needs 9.7.100.177 (FP-1) Build Level s091114, Release Date 24 Nov 2009, vulnerabilities listed here: http://www-01.ibm.com/support/docview.wss?rs=71&uid=swg21412182
    med-vuln|db2|DB2 v9.5.400.576 build s090429|Needs 9.5.0.5 (FP-5) Build level s091123, Release Date 14 Dec 2009, vulnerabilities listed here: http://www-01.ibm.com/support/docview.wss?rs=71&uid=swg21412902
    med-vuln|db2|DB2 v9.5.0.3 build s081210|Needs 9.5.0.5 (FP-5) Build level s091123, Release Date 14 Dec 2009, vulnerabilities listed here: http://www-01.ibm.com/support/docview.wss?rs=71&uid=swg21412902
    med-vuln|db2|DB2 v9.7.0.0 build s090521|Needs 9.7.0.1 (FP-1) Build Level s091114, Release Date 24 Nov 2009, vulnerabilities listed here: http://www-01.ibm.com/support/docview.wss?rs=71&uid=swg21412182
    med-vuln|mssql|Microsoft SQL Server v9.00.4053.00 SP3|Dec 15,2008 release, missing later patches, http://sqlserverbuilds.blogspot.com/
    med-vuln|mssql|Microsoft SQL Server v9.00.3077.00 SP2| SP2 + GDR Hotfix for MS09-004, February 10th 2009, http://sqlserverbuilds.blogspot.com/
    med-vuln|mssql|Microsoft SQL Server v9.00.3054.00 SP2|Re-released SP2 + GDR2 Hotfix, April 2008, http://sqlserverbuilds.blogspot.com/
    med-vuln|oracle|Oracle v10.2.0.1.0|Vulnerable, latest patch release is v10.2.0.5.0, see http://www.oracle.com/technology/deploy/security/alerts.htm
    med-vuln|oracle|Oracle v10.2.0.3.0|Vulnerable, latest patch release is v10.2.0.5.0, see http://www.oracle.com/technology/deploy/security/alerts.htm
    ######################################################################
    # Below are the 'crit-vuln' versions confirmed for high criticality  #
    ######################################################################

### Plugin Usage Example:

* * *

The plugin in 'discovery' mode, returns OK if the software version string could be fetched.

<pre>susie: ~ # java -classpath /srv/app/nagios/libexec/ check_dbversion_db2 192.168.1.64 50000 DB2 db2admin "p@ssw0rd"
Version OK: DB2 v9.5.0.3 build s081210 (64 bit), PTF: U823474 FP: 3|</pre>

The plugin in 'compliance' mode, returns the status depending on the version string definition set in the supplied config file.

<pre>susie: ~ # java -classpath /srv/app/nagios/libexec/ check_dbversion_db2 192.168.1.64 50000 DB2 db2admin "p@ssw0rd" -f
 /srv/app/nagios/libexec/check_dbversion.cfg  
Version WARN: DB2 v9.5.0.3 build s081210 vulnerable (low-medium)|Needs 9.5.0.5 (FP-5) Build level s091123, Release Date
 14 Dec 2009, vulnerabilities listed here: http://www-01.ibm.com/support/docview.wss?rs=71&uid=swg21412902</pre>

### Notes:

* * *

The plugin's .java source code file needs to be compiled into Java bytecode before it can be used, i.e. by calling:  
_javac check_dbversion_db2.java_.
