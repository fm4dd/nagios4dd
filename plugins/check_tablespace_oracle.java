// ----------------------------------------------------------------------------
// check_tablespace_oracle.java 20160904 frank4dd version 1.1
// ----------------------------------------------------------------------------
// e-mail: support[at]frank4dd.com
// web:     http://nagios.fm4dd.com/
//
// This nagios plugin queries the Oracle dba_free_space and dba_data_files
// system tables. Supported are Oracle versions 10g and up.
//
// Pre-requisites: Oracle JDBC driver installed and a valid DB user.
// ----------------------------------------------------------------------------
// Example Output:
// > java check_tablespace_oracle 127.0.0.1 1521 XE system test -d
// DB connect: jdbc:oracle:thin:system/test@127.0.0.1:1521:XE
// DB query: select  df.TABLESPACE_NAME, df.FILE_ID, ((df.BYTES+fs.BYTES)/1024) bytes_max,
// (df.BYTES/1024) bytes_used, round(((df.BYTES - fs.BYTES) / df.BYTES) * 100) usage_pct
// from ( select  TABLESPACE_NAME, sum(BYTES) BYTES, count(distinct FILE_ID) FILE_ID from
// dba_data_files group by TABLESPACE_NAME ) df, ( select TABLESPACE_NAME, sum(BYTES) BYTES
// from dba_free_space group by TABLESPACE_NAME) fs where df.TABLESPACE_NAME=fs.TABLESPACE_NAME
// order by df.TABLESPACE_NAME asc
// Name: SYSAUX               Files: 1, Space total:  706.62 MB, Space used:  670.00 MB, % used:  95 %
// Name: SYSTEM               Files: 1, Space total:  790.50 MB, Space used:  790.00 MB, % used: 100 %
// Name: UNDOTBS1             Files: 1, Space total:  215.56 MB, Space used:  215.00 MB, % used: 100 %
// Name: USERS                Files: 1, Space total:    8.62 MB, Space used:    5.00 MB, % used:  28 %
// ----------------------------------------------------------------------------
// Revision history:
// 20100820 initial release version 1.0
// 20160904 bugfix: 2TB overflow: Tablespace size type Integer changed to Long
//          base count changed to bytes, adding function for human readable format

import java.sql.*;
import java.text.*;

class check_tablespace_oracle {

  static long bytes_warn = 0;  // the commandline argument for warning threshold of B used
  static long bytes_crit = 0;  // the commandline argument for critical threshold of B used
  static long bytes_used = 0;  // the returned tablespace value of used space (in Bytes)
  static long bytes_total= 0;  // the returned tablespace value of total space available
  static int dfiles_total= 0;  // the returned number of tablespace files
  static int percent_used= 0;  // the returned tablespace value, current space used in percent
  static int debug       = 0;  // 'normal'=>0,'verbose'=>1 when -d parameter is given
  static String output   = ""; // the plugin output string
  static String perfdata = ""; // the plugin perfdata output
  static String tbspname = ""; // the tablespace to check
  static String dbUrl    = ""; // the access URL for the database to query
  static String query    = ""; // the SQL query to execute

  public static String floatForm (double d) {
     return new DecimalFormat("0.00").format(d);
  }

  public static String bytesToHuman (long size) {
    long Kb = 1  * 1024;
    long Mb = Kb * 1024;
    long Gb = Mb * 1024;
    long Tb = Gb * 1024;
    long Pb = Tb * 1024;
    long Eb = Pb * 1024;

    if (size <  Kb)                 return floatForm(size) + " Bytes";
    if (size >= Kb && size < Mb)    return floatForm((double)size / Kb) + " KB";
    if (size >= Mb && size < Gb)    return floatForm((double)size / Mb) + " MB";
    if (size >= Gb && size < Tb)    return floatForm((double)size / Gb) + " GB";
    if (size >= Tb && size < Pb)    return floatForm((double)size / Tb) + " TB";
    if (size >= Pb && size < Eb)    return floatForm((double)size / Pb) + " PB";
    if (size >= Eb)                 return floatForm((double)size / Eb) + " EB";

    return "Out of bounds"; // return overflow error, we won't calculate beyond EB
  }

  public static void main (String args[]) {
    if (args.length < 6) {
      System.err.println("Error: Missing Arguments.");
      System.err.println("Syntax: java check_tablespace_oracle <db-ip> <db-port> <db-instance> <db-user> <db-pwd> <tablespace-name> <bytes-warn> <bytes-crit>");
      System.err.println("        java check_tablespace_oracle <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -r <tablespace-name>");
      System.err.println("        java check_tablespace_oracle <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -d");
      System.exit(-1);
    }
    // Check if we got a particular tablespace to check for
    if (args.length == 6 && args[5].equals("-d")) { debug = 1;}

    dbUrl = "jdbc:oracle:thin:" + args[3] + "/" + args[4] + "@" + args[0] +":" + args[1] +":" + args[2];
    if (debug == 1) { System.out.println("DB connect: " + dbUrl); }

    // Check if we just return the data without any values to compare to
    if (args.length == 7 && args[5].equals("-r")) {
      tbspname = args[6];
    }

    // Check if we got warn and crit values to check against
    if (args.length == 8) { 
      tbspname = args[5];
      bytes_warn = Long.parseLong(args[6]);
      bytes_crit = Long.parseLong(args[7]);
    }


    try {
      // use the Oracle JDBC driver
      Class.forName("oracle.jdbc.driver.OracleDriver");
    } catch (ClassNotFoundException e) {
      System.err.println("Error: JDBC Driver Problem.");
      System.err.println (e);
      System.exit (3);
    }
   try {
      // open connection to database "jdbc:oracle:thin:@destinationhost:port:dbname", "dbuser", "dbpassword"
      Connection connection = DriverManager.getConnection(dbUrl);

      // build query

      // table dba_data_files: TABLESPACE_NAME,  FILE_NAME, BYTES, MAXBYTES, AUTOEXTENSIBLE
      // dba_free_space: TABLESPACE_NAME,  FILE_ID, BYTES
      // Show free tablespace: Select tablespace_name, Sum(bytes/(1024)) "Total Free (KB) " From dba_free_space Group By tablespace_name; 
      // Show used tablespace: Select tablespace_name, Sum(bytes/(1024)) "Total Used (KB) " From dba_data_files Group By tablespace_name; 
      if (tbspname == "") {
        query = "select  df.TABLESPACE_NAME, df.FILE_ID, (df.BYTES+fs.BYTES) bytes_max, df.BYTES bytes_used, round(((df.BYTES - fs.BYTES) / df.BYTES) * 100) usage_pct from ( select  TABLESPACE_NAME, sum(BYTES) BYTES, count(distinct FILE_ID) FILE_ID from dba_data_files group by TABLESPACE_NAME ) df, ( select TABLESPACE_NAME, sum(BYTES) BYTES from dba_free_space group by TABLESPACE_NAME) fs where df.TABLESPACE_NAME=fs.TABLESPACE_NAME order by df.TABLESPACE_NAME asc";
      } else {
        query = "select  df.TABLESPACE_NAME, df.FILE_ID, (df.BYTES+fs.BYTES) bytes_max, df.BYTES bytes_used, round(((df.BYTES - fs.BYTES) / df.BYTES) * 100) usage_pct from ( select  TABLESPACE_NAME, sum(BYTES) BYTES, count(distinct FILE_ID) FILE_ID from dba_data_files where TABLESPACE_NAME = '" + tbspname + "' group by TABLESPACE_NAME) df, ( select TABLESPACE_NAME, sum(BYTES) BYTES from dba_free_space group by TABLESPACE_NAME) fs where df.TABLESPACE_NAME=fs.TABLESPACE_NAME order by df.TABLESPACE_NAME asc";
      }
      if (debug == 1) { System.out.println ("DB query: " + query); }

      // execute query
      Statement statement = connection.createStatement ();
      ResultSet rs = statement.executeQuery (query);

      while ( rs.next () ) {
        // get content from column "1 -4"
        if (debug == 1) {
          System.out.format ("Name: %-20s ", rs.getString (1));         // TBSP_NAME, VARCHAR2(30)
          System.out.format ("Files: %d, ", rs.getInt(2));             // TBSP File count, NUMBER
          System.out.format ("Space total: %10s, ", bytesToHuman(rs.getLong(3)));   // TBSP_TOTAL_SIZE in B, NUMBER
          System.out.format ("Space used: %10s, ", bytesToHuman(rs.getLong(4)));    // TBSP_USED_SIZE in B, NUMBER
          System.out.format ("%% used: %3d %%\n", rs.getInt(5)); // TBSP_UTILIZATION in PERCENT
        }
        tbspname=rs.getString (1);
        dfiles_total=rs.getInt(2);
        bytes_total=rs.getLong(3);
        bytes_used=rs.getLong(4);
        percent_used=rs.getInt(5);
      }

      rs.close () ;
      statement.close () ;
      connection.close () ;

    } catch (java.sql.SQLException e) {
      System.err.println (e) ;
      System.exit (3) ; // Unknown
    }

    perfdata = "bytes_used=" + bytes_used + ";; percent_used=" + percent_used + ";; datafiles=" + dfiles_total;
    output = tbspname + " " + percent_used + "% used (" + bytesToHuman(bytes_used) + "/" + bytesToHuman(bytes_total)+ ")|" + perfdata;

    if ( (bytes_warn != 0) && (bytes_crit != 0) ) {
      if ( bytes_used < bytes_warn ) {
        System.out.println("OK - " + output);
        System.exit (0); // OK
      }
      if ( bytes_used >= bytes_warn && bytes_used < bytes_crit ) {
        System.out.println("WARN - "  + output);
        System.exit (1); // WARN
      }
      if ( bytes_used  >= bytes_crit ) {
        System.out.println("CRIT - "  + output);
        System.exit (2); // CRIT
      }
    }
    if (args.length == 7 && args[5].equals("-r")) {
      System.out.println("OK - " + output);
      System.exit (0); // OK
    }
  }
}
