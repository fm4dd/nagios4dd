// ----------------------------------------------------------------------------
// check_tablespace_mysql.java 20160903 frank4dd version 1.2
// ----------------------------------------------------------------------------
// e-mail: support[at]frank4dd.com
// web:    http://nagios.fm4dd.com/
//
// This nagios plugin queries the size in information_schema.TABLES system table.
// Supported are MySQL Server versions 5.0 and up with engines MyISAM, InnoDB,
// and TocuDB.
//
// MyISAM: MySQL's default storage engine has no concept of tablespaces.
// We handle it as if there is exactly one tablespace and sum up all
// table sizes for a given database schema.
//
// Pre-requisites: MySQL JDBC driver installed and a valid DB user.
// ----------------------------------------------------------------------------
// Example Output:
// > java check_tablespace_mysql 192.168.0.1  3306 edacs root Secret1 -r
// Tablespace OK - 59.88 MB used|bytes_used=62783488;; datafiles=30
//
// > java check_tablespace_mysql 192.168.0.1  3306 edacs root Secret1 -d
// DB connect: jdbc:mysql://127.0.0.1:3306/edacs?user=root&password=Secret1
// File Name:       edacs_daystats Space used:         11 KB
// File Name:        edacs_mainlog Space used:       1520 KB
// ...
// File Name:        edacs_version Space used:          2 KB
//
// > java check_tablespace_mysql 192.168.0.1  3306 edacs root Secret1 50000000 70000000
// Tablespace WARN - 59.88 MB used|bytes_used=62783488;; datafiles=30
//
// Revision history:
// 20100922 initial release version 1.0
// 20160902 bugfix: type assignment (MySQL bigint->Java int) changed to Long
// 20160903 base count changed to bytes, adding function for human readable format
//          skip calculation for views, and change file count to table count

import java.sql.*;
import java.text.*;

class check_tablespace_mysql {

  static long bytes_warn  = 0;  // the commandline argument for warning threshold of bytes used
  static long bytes_crit  = 0;  // the commandline argument for critical threshold of bytes used
  static long bytes_used  = 0;  // the returned tablespace summary of used bytes
  static int  table_total = 0;  // the returned number of tables
  static int debug        = 0;  // 'normal'=>0,'verbose'=>1 when -d parameter is given
  static String tbltype   = ""; // the MySQL table type, e.g. "BASE TABLE", "VIEW"
  static String output    = ""; // the plugin output string
  static String perfdata  = ""; // the plugin perfdata output, returning bytes_used and # of datafiles
  static String tbspname  = ""; // the MySQL database to check
  static String dbUrl     = ""; // the access URL for the database to query
  static String query     = ""; // the SQL query to execute

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
      System.err.println("Syntax: java check_tablespace_mysql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> <bytes-warn> <bytes-crit>");
      System.err.println("        java check_tablespace_mysql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -r");
      System.err.println("        java check_tablespace_mysql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -d");
      System.exit(-1);
    }
    // Check if we need to enable debug
    if (args.length == 6 && args[5].equals("-d")) { debug = 1;}

    dbUrl = "jdbc:mysql://" + args[0] +":" + args[1] +"/" + args[2] + "?user=" + args[3] + "&password=" + args[4];
    if (debug == 1) { System.out.println("DB connect: " + dbUrl); }

    // Check if we just return the data without any values to compare to
    if (args.length == 6 && args[5].equals("-r")) {
    }

    // Check if we got warn and crit values to check against
    if (args.length == 7) {
      bytes_warn = Integer.parseInt(args[5]);
      bytes_crit = Integer.parseInt(args[6]);
    }

    // assign schema name
    tbspname = args[2];

    try {
      Class.forName("com.mysql.jdbc.Driver");
    } catch (ClassNotFoundException e) {
      System.err.println("Error: JDBC Driver Problem.");
      System.err.println (e);
      System.exit(3); // return UNKNOWN
    }
    try {
      // open connection to database "jdbc:mysql://destinationhost:port/dbname?dbuser&dbpassword"
      Connection connection = DriverManager.getConnection(dbUrl);

      // (1) query schema size in bytes from table "information_schema.TABLES"
      String query = "SELECT table_name, table_type, round (data_length + index_length) 'B size' FROM information_schema.TABLES WHERE table_schema = '" + tbspname + "'";

      // execute query
      Statement statement = connection.createStatement () ;
      ResultSet schema_sz = statement.executeQuery (query) ;

      // Loop through the result set
      while( schema_sz.next() ) {
        // display debug output if called with "-r" report parameter
        if (debug == 1) {
          System.out.format ("Table Name: %-25s ", schema_sz.getString(1)); // TABLE_NAME, varchar(64)
          System.out.format ("Table Type: %-15s ", schema_sz.getString(2)); // TABLE_TYPE, varchar(64)
          System.out.format ("Space used: %-15s\n", bytesToHuman(schema_sz.getLong(3))); // SIZE, BIGINT(unsigned)
        }

        tbltype = schema_sz.getString(2);

        // If the returned row is not a real table (e.g. a view), skip here
        if(! tbltype.contains("TABLE")) continue;

        // If the sum is going to overflow the datatype, create error
        if(bytes_used + schema_sz.getLong(3) > Long.MAX_VALUE) {
          System.out.println("Error: calculation overflow.|");
          System.exit(3); // Unknown
        }
        else {
          bytes_used = bytes_used + schema_sz.getLong(3);
        }
       
        table_total = table_total + 1;
      }
      schema_sz.close();
      statement.close();
      connection.close();

    } catch (java.sql.SQLException e) {
      System.err.println("Error: SQL Problem.");
      System.err.println(e) ;
      System.exit(3); // Unknown
    }

    perfdata ="bytes_used=" +  bytes_used + ";; table_count=" + table_total;
    output = bytesToHuman(bytes_used) + " used|" + perfdata;

    if ( (bytes_warn != 0) && (bytes_crit != 0) ) {
      if ( bytes_used < bytes_warn ) {
        System.out.println("OK - " + tbspname + " " + output);
        System.exit(0); // OK
      }
      if ( bytes_used >= bytes_warn && bytes_used < bytes_crit ) {
        System.out.println("WARN - " + tbspname + " " + output);
        System.exit(1); // WARN
      }
      if ( bytes_used  >= bytes_crit ) {
        System.out.println("CRIT - "   + tbspname + " " + output);
        System.exit(2); // CRIT
      }
    }
    if (args.length == 6 && args[5].equals("-r")) {
      System.out.println("OK - " + tbspname + " " + output);
      System.exit(0); // OK
    }
  }
}
