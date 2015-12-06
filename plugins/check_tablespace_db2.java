// ----------------------------------------------------------------------------
// check_tablespace_db2.java 20100209 frank4dd version 1.0
// ----------------------------------------------------------------------------
// e-mail: support[at]frank4dd.com
// web:    http://nagios/fm4dd.com/
//
// This nagios plugin queries the DB2 TBSP_UTILIZATION administrative view.
// Supported are DB2 versions 9.x
//
// Pre-requisites: DB2 JDBC driver installed and DB user has these minimum rights:
// SELECT or CONTROL privilege on TBSP_UTILIZATION, SNAPTBSP, SNAPTBSP_PART views
// SELECT or CONTROL privilege on SYSCAT.TABLESPACES catalog view
// SYSMON, SYSCTRL, SYSMAINT, or SYSADM authority to access snapshot monitor data
// ----------------------------------------------------------------------------
// Example Output:
// > java check_tablespace_db2 192.168.90.64 50007  DBB3_H_Z SMLHSD3I "pass123" -d
// DB connect: jdbc:db2://192.168.90.64:50007/DBB3_H_Z
// DB query: select TBSP_NAME, TBSP_TOTAL_SIZE_KB, TBSP_USED_SIZE_KB, TBSP_UTILIZATION_PERCENT FROM SYSIBMADM.TBSP_UTILIZATION where TBSP_TOTAL_SIZE_KB > 0
// Name:           USERSPACE1 Files:  5 Space total:    5242880 KB Space used:    1559424 KB Space % used:  29 %
// Name:           USERSPACE2 Files:  1 Space total:    1048576 KB Space used:     351232 KB Space % used:  33 %
// Name:           USERSPACE3 Files:  1 Space total:    1048576 KB Space used:     359936 KB Space % used:  34 %
// Name:         SYSTOOLSPACE Files:  1 Space total:      32768 KB Space used:        704 KB Space % used:   2 %
// ----------------------------------------------------------------------------
import java.sql.*;

class check_tablespace_db2 {

  static int kbytes_warn = 0;  // the commandline argument for warning threshold of KB used
  static int kbytes_crit = 0;  // the commandline argument for critical threshold of KB used
  static int dfiles_total= 0;  // the returned number of container files
  static int kbytes_used = 0;  // the returned tablespace value of KB used
  static int kbytes_total= 0;  // the returned tablespace value of total KB available
  static int percent_used= 0;  // the returned tablespace value of space used in percent
  static int return_code = 0;  // 'OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4
  static int debug       = 0;  // 'normal'=>0,'verbose'=>1 when -d parameter is given
  static String output   = ""; // the plugin output string
  static String perfdata = ""; // the plugin perfdata output, currently unused
  static String tbspname = ""; // the tablespace to check
  static String dbUrl    = ""; // the access URL for the database to query
  static String query    = ""; // the SQL query to execute

  public static void main (String args[]) {
    if (args.length < 6) {
      System.err.println("Error: Missing Arguments.");
      System.err.println("Syntax: java check_tablespace_db2 <db-ip> <db-port> <db-instance> <db-user> <db-pwd> <tablespace-name> <kbytes-warn> <kbytes-crit>");
      System.err.println("        java check_tablespace_db2 <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -r <tablespace-name>");
      System.err.println("        java check_tablespace_db2 <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -d");
      System.exit(-1);
    }
    // Check if we got a particular tablespace to check for
    if (args.length == 6 && args[5].equals("-d")) { debug = 1;}

    dbUrl = "jdbc:db2://" + args[0] +":" + args[1] + "/" + args[2];
    if (debug == 1) { System.out.println("DB connect: " + dbUrl); }

    // Check if we just return the data without any values to compare to
    if (args.length == 7 && args[5].equals("-r")) {
      tbspname = args[6];
    }

    // Check if we got warn and crit values to check against
    if (args.length == 8) { 
      tbspname = args[5];
      kbytes_warn = Integer.parseInt(args[6]);
      kbytes_crit = Integer.parseInt(args[7]);
    }

    try {
      // use the JDBCtype 4 driver
      Class.forName("com.ibm.db2.jcc.DB2Driver");
    } catch (ClassNotFoundException e) {
      System.err.println("Error: JDBC Driver Problem.");
      System.err.println (e);
      System.exit (3);
    }
    try {
      // open connection to database "jdbc:db2://destinationhost:port/dbname", "dbuser", "dbpassword"
      Connection connection = DriverManager.getConnection(dbUrl, args[3], args[4]);

      // build query
      if (tbspname == "") {
        query = "select TBSP_NAME, TBSP_NUM_CONTAINERS, TBSP_TOTAL_SIZE_KB, TBSP_USED_SIZE_KB, TBSP_UTILIZATION_PERCENT FROM SYSIBMADM.TBSP_UTILIZATION where TBSP_TOTAL_SIZE_KB > 0";
      } else {
        query = "select TBSP_NAME, TBSP_NUM_CONTAINERS, TBSP_TOTAL_SIZE_KB, TBSP_USED_SIZE_KB, TBSP_UTILIZATION_PERCENT FROM SYSIBMADM.TBSP_UTILIZATION where TBSP_NAME = '" + tbspname + "'";
      }
      if (debug == 1) { System.out.println ("DB query: " + query); }

      // execute query
      Statement statement = connection.createStatement ();
      ResultSet rs = statement.executeQuery (query);

      while ( rs.next () ) {
        // get content from column "1 -4"
        if (debug == 1) { 
          System.out.format ("Name: %20s ", rs.getString (1));      // TBSP_NAME, VARCHAR(128)
          System.out.format ("Files: %2d ", rs.getInt(2));// TBSP_TOTAL_SIZE_KB, BIGINT
          System.out.format ("Space total: %10d KB ", rs.getInt(3));// TBSP_TOTAL_SIZE_KB, BIGINT
          System.out.format ("Space used: %10d KB ", rs.getInt(4)); // TBSP_USED_SIZE_KB, BIGINT
          System.out.format ("Space %% used: %3d %%\n", rs.getInt(5)); // TBSP_UTILIZATION_PERCENT, BIGINT
        }
        tbspname=rs.getString (1);
        dfiles_total=rs.getInt(2);
        kbytes_total=rs.getInt(3);
        kbytes_used=rs.getInt(4);
        percent_used=rs.getInt(5);
      }

      rs.close () ;
      statement.close () ;
      connection.close () ;

    } catch (java.sql.SQLException e) {
      System.err.println (e) ;
      System.exit (3) ; // Unknown
    }

    perfdata = tbspname + ": " +dfiles_total + " datafiles, used " + kbytes_used + " KB of " + kbytes_total + " KB total";
    output = tbspname + " " + percent_used + "% used" + "|" + perfdata;

    if ( (kbytes_warn != 0) && (kbytes_crit != 0) ) {
      if ( kbytes_used < kbytes_warn ) {
        System.out.println("Tablespace OK: " + output);
        System.exit (0); // OK
      }
      if ( kbytes_used >= kbytes_warn && kbytes_used < kbytes_crit ) {
        System.out.println("Tablespace WARN: "  + output);
        System.exit (1); // WARN
      }
      if ( kbytes_used  >= kbytes_crit ) {
        System.out.println("Tablespace CRIT: "  + output);
        System.exit (2); // CRIT
      }
    }
    if (args.length == 7 && args[5].equals("-r")) {
      System.out.println("Tablespace OK: " + output);
      System.exit (0); // OK
    }
  }
}
