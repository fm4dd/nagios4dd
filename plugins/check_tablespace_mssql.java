// ----------------------------------------------------------------------------
// check_tablespace_mssql.java 20150924 frank4dd version 1.1
// ----------------------------------------------------------------------------
// e-mail: support[at]frank4dd.com
// web:    http://nagios.fm4dd.com/
//
// This nagios plugin queries the sys.database_files system table.
// Supported are Microsoft SQL Server versions 2005 and up.
// MSSQL has no concept of tablespaces, datafiles can be placed
// individually on the underlying filesystem. For our purpose,
// we handle it as if there is exactly one tablespace and sum up
// all datafile sizes for a given database.
// Consequently, there is no tablespace name parameter, or list
// of available tablespaces.
//
// Pre-requisites: MSSQL JDBC driver installed and a valid DB user.
// ----------------------------------------------------------------------------
// Example Output:
// > java check_tablespace_mssql 192.168.98.128 1433 contacts "sa" "dbpass" -r
// Tablespace OK: contacts 408947 KBytes|contacts: 1 datafiles, 1 logfiles, used 408947 KB
//
// > java check_tablespace_mssql 192.168.98.128 1433 contacts "sa" "dbpass" -d
// DB connect: jdbc:sqlserver://1192.168.98.128:1433;databaseName=contacts;user=sa;password=dbpass;
// File Name: D:\SQLServer\Data\Contacts.mdf Space used:     400000 KB
// File Name: D:\SQLServer\Data\Contacts_log.ldf Space used:       8947 KB
//
// > java check_tablespace_mssql 192.168.98.128 1433 contacts "sa" "dbpass" 300000 500000
// Tablespace WARN: contacts 408947 KBytes|contacts: 1 datafiles, 1 logfiles, used 408947 KB
// ----------------------------------------------------------------------------
import java.sql.*;

class check_tablespace_mssql {

  static int kbytes_warn = 0;  // the commandline argument for warning threshold of KB used
  static int kbytes_crit = 0;  // the commandline argument for critical threshold of KB used
  static int dfiles_total= 0;  // the returned number of tablespace files
  static int lfiles_total= 0;  // the returned number of log files
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
      System.err.println("Syntax: java check_tablespace_mssql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> <kbytes-warn> <kbytes-crit>");
      System.err.println("        java check_tablespace_mssql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -r");
      System.err.println("        java check_tablespace_mssql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -d");
      System.exit(-1);
    }
    // Check if we need to enable debug
    if (args.length == 6 && args[5].equals("-d")) { debug = 1;}

    dbUrl = "jdbc:sqlserver://" + args[0] +":" + args[1] +";databaseName=" + args[2] + ";user=" + args[3] + ";password=" + args[4] + ";";
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
      Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
    } catch (ClassNotFoundException e) {
      System.err.println("Error: JDBC Driver Problem.");
      System.err.println (e);
      
      System.exit (3); // return UNKNOWN
    }
    try {
      // open connection to database "jdbc:sqlserver://destinationhost:port;databaseName=dbname;user=dbuser;password=dbpassword;"
      Connection connection = DriverManager.getConnection(dbUrl);

      // build query, here we use table "sys.database_files"
      // size is returned in 8KB blocks, we convert into KB (size*8)
      String query = "SELECT physical_name, (size*8) kbytes From sys.database_files" ;

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

        if ( rs.getString(1).endsWith(".mdf") ) dfiles_total++;
        if ( rs.getString(1).endsWith(".ddf") ) dfiles_total++;
        if ( rs.getString(1).endsWith(".ldf") ) lfiles_total++;
        kbytes_used = kbytes_used + rs.getInt(2);
      }

      rs.close () ;
      statement.close () ;
      connection.close () ;

    } catch (java.sql.SQLException e) {
      System.err.println (e) ;
      System.exit (3) ; // Unknown
    }

    perfdata = args[2] + ": " + dfiles_total + " datafiles, " + lfiles_total + " logfiles, used " + kbytes_used + " KB";
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
