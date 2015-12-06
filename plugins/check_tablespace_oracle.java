// ----------------------------------------------------------------------------
// check_tablespace_oracle.java 20100820 frank4dd version 1.0
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
// DB query: select  df.TABLESPACE_NAME, df.FILE_ID, ((df.BYTES+fs.BYTES)/1024) kbytes_max,
// (df.BYTES/1024) kbytes_used, round(((df.BYTES - fs.BYTES) / df.BYTES) * 100) usage_pct
// from ( select  TABLESPACE_NAME, sum(BYTES) BYTES, count(distinct FILE_ID) FILE_ID from
// dba_data_files group by TABLESPACE_NAME ) df, ( select TABLESPACE_NAME, sum(BYTES) BYTES
// from dba_free_space group by TABLESPACE_NAME) fs where df.TABLESPACE_NAME=fs.TABLESPACE_NAME
// order by df.TABLESPACE_NAME asc
//Name:               SYSAUX Files:  1 Space total:     374912 KB Space used:     317440 KB Space % used:  82 %
//Name:               SYSTEM Files:  1 Space total:     350208 KB Space used:     348160 KB Space % used:  99 %
//Name:                 UNDO Files:  1 Space total:     384384 KB Space used:     215040 KB Space % used:  21 %
//Name:                USERS Files:  1 Space total:     203136 KB Space used:     102400 KB Space % used:   2 %
// ----------------------------------------------------------------------------
import java.sql.*;

class check_tablespace_oracle {

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
      System.err.println("Syntax: java check_tablespace_oracle <db-ip> <db-port> <db-instance> <db-user> <db-pwd> <tablespace-name> <kbytes-warn> <kbytes-crit>");
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
      kbytes_warn = Integer.parseInt(args[6]);
      kbytes_crit = Integer.parseInt(args[7]);
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
        query = "select  df.TABLESPACE_NAME, df.FILE_ID, ((df.BYTES+fs.BYTES)/1024) kbytes_max, (df.BYTES/1024) kbytes_used, round(((df.BYTES - fs.BYTES) / df.BYTES) * 100) usage_pct from ( select  TABLESPACE_NAME, sum(BYTES) BYTES, count(distinct FILE_ID) FILE_ID from dba_data_files group by TABLESPACE_NAME ) df, ( select TABLESPACE_NAME, sum(BYTES) BYTES from dba_free_space group by TABLESPACE_NAME) fs where df.TABLESPACE_NAME=fs.TABLESPACE_NAME order by df.TABLESPACE_NAME asc";
      } else {
        query = "select  df.TABLESPACE_NAME, df.FILE_ID, ((df.BYTES+fs.BYTES)/1024) kbytes_max, (df.BYTES/1024) kbytes_used, round(((df.BYTES - fs.BYTES) / df.BYTES) * 100) usage_pct from ( select  TABLESPACE_NAME, sum(BYTES) BYTES, count(distinct FILE_ID) FILE_ID from dba_data_files where TABLESPACE_NAME = '" + tbspname + "' group by TABLESPACE_NAME) df, ( select TABLESPACE_NAME, sum(BYTES) BYTES from dba_free_space group by TABLESPACE_NAME) fs where df.TABLESPACE_NAME=fs.TABLESPACE_NAME order by df.TABLESPACE_NAME asc";
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
