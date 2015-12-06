// ----------------------------------------------------------------------------
// check_tablespace_mysql.java 20100922 frank4dd version 1.0
// ----------------------------------------------------------------------------
// e-mail: support[at]frank4dd.com
// web:    http://nagios.fm4dd.com/
//
// This nagios plugin queries the information_schema.TABLES system table.
// Supported are MySQL Server versions 5.0 and up.
// MySQL's default storage engine MyISAM has no concept of tablespaces,
// 3 files are generated per table and can only be placed together per DB
// using the 'data-dir' path in the underlying filesystem. For our purpose,
// we handle it as if there is exactly one tablespace and sum up
// all datafile sizes for a given database.
// Consequently, there is no tablespace name parameter or list
// of available tablespaces.
//
// Pre-requisites: MySQL JDBC driver installed and a valid DB user.
// ----------------------------------------------------------------------------
// Example Output:
// > java check_tablespace_mysql 192.168.0.1  3306 edacs root Pillnitz1 -r
// Tablespace OK: edacs 4961 KBytes|edacs: 27 datafiles, 4961 KB
// > java check_tablespace_mysql 192.168.0.1  3306 edacs root Pillnitz1 -d
// DB connect: jdbc:mysql://127.0.0.1:3306/edacs?user=root&password=Pillnitz1
// File Name:       edacs_daystats Space used:         11 KB
// File Name:        edacs_mainlog Space used:       1520 KB
// File Name:       edacs_monstats Space used:          2 KB
// File Name:         edacs_remote Space used:         43 KB
// File Name:         edacs_router Space used:          2 KB
// File Name:        edacs_service Space used:          2 KB
// File Name:        edacs_templog Space used:       3364 KB
// File Name:          edacs_users Space used:         15 KB
// File Name:        edacs_version Space used:          2 KB
// > java check_tablespace_mysql 192.168.0.1  3306 edacs root Pillnitz1 4000 5000
// Tablespace WARN: edacs 4961 KBytes|edacs: 27 datafiles, 4961 KB

import java.sql.*;

class check_tablespace_mysql {

  static int kbytes_warn = 0;  // the commandline argument for warning threshold of KB used
  static int kbytes_crit = 0;  // the commandline argument for critical threshold of KB used
  static int dfiles_total= 0;  // the returned number of tablespace files
  static int kbytes_used = 0;  // the returned tablespace value of used KB
  static int kbytes_total= 0;  // the returned tablespace value of total KB available
  static int percent_used= 0;  // the returned tablespace value, current space used in percent
  static int return_code = 0;  // 'OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4
  static int debug       = 0;  // 'normal'=>0,'verbose'=>1 when -d parameter is given
  static String output   = ""; // the plugin output string
  static String perfdata = ""; // the plugin perfdata output, returning the KB values
  static String tbspname = ""; // the tablespace to check
  static String dbUrl    = ""; // the access URL for the database to query
  static String query    = ""; // the SQL query to execute

  public static void main (String args[]) {
    if (args.length < 6) {
      System.err.println("Error: Missing Arguments.");
      System.err.println("Syntax: java check_tablespace_mysql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> <kbytes-warn> <kbytes-crit>");
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
      kbytes_warn = Integer.parseInt(args[5]);
      kbytes_crit = Integer.parseInt(args[6]);
    }

    try {
      Class.forName("com.mysql.jdbc.Driver");
    } catch (ClassNotFoundException e) {
      System.err.println("Error: JDBC Driver Problem.");
      System.err.println (e);
      
      System.exit (3); // return UNKNOWN
    }
    try {
      // open connection to database "jdbc:mysql://destinationhost:port/dbname?dbuser&dbpassword"
      Connection connection = DriverManager.getConnection(dbUrl);

      // build query, here we use table "information_schema.TABLES"
      // size is returned in bytes, we convert it into KBytes
      String query = "SELECT table_name, round (data_length + index_length)/(1024) 'KB size' FROM information_schema.TABLES WHERE ENGINE=('MyISAM' || 'InnoDB' ) AND table_schema = '" + args[2] + "'";

      // execute query
      Statement statement = connection.createStatement () ;
      ResultSet rs = statement.executeQuery (query) ;

      // Loop through the result set
      while( rs.next() ) {
        // get content from column "1-2"
        if (debug == 1) {
          System.out.format ("File Name: %20s ", rs.getString (1)); // PHYSICAL_NAME, NVARCHAR(260)
          System.out.format ("Space used: %10d KB\n", rs.getInt(2)); // SIZE, INT, Current filesize in 8-KB pages
        }

        kbytes_used = kbytes_used + rs.getInt(2);
        dfiles_total = dfiles_total+3;
      }

      rs.close () ;
      statement.close () ;
      connection.close () ;

    } catch (java.sql.SQLException e) {
      System.err.println (e) ;
      System.exit (3) ; // Unknown
    }

    perfdata = args[2] + ": " + dfiles_total + " datafiles, " + kbytes_used + " KB";
    output = args[2] + " " + kbytes_used + " KBytes" + "|" + perfdata;

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
    if (args.length == 6 && args[5].equals("-r")) {
      System.out.println("Tablespace OK: " + output);
      System.exit (0); // OK
    }
  }
}
