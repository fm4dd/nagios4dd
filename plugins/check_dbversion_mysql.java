// ----------------------------------------------------------------------------
// check_dbversion_mysql.java 20100209 frank4dd version 1.0
// ----------------------------------------------------------------------------
// e-mail: support[at]frank4dd.com
// web:    http://nagios.fm4dd.com/
//
// This nagios plugin logs in and queries the MySQL 'version' variables.
// Supported and tested are MySQL versions 5x, other versions should work also.
//
// Pre-requisites: MySQL JDBC driver installed and DB user has select rights.
// jdbc driver file i.e. mysql-connector-java-5.1.6-bin.jar
// ----------------------------------------------------------------------------
// Example Output:
// > java check_dbversion_mysql 192.168.98.128 1433 mydb dbuser "password"
// Version OK: MySQL v5.0.67|Novell SLES software repository version of MySQL
// ----------------------------------------------------------------------------
// return codes 'OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4
// ----------------------------------------------------------------------------
import java.sql.*;
import java.io.*;
import java.util.*;

class check_dbversion_mysql {

  static int debug       = 0;  // 'normal'=>0,'verbose'=>1 when -d parameter is given
  static String db_name = "";  // varchar(128)
  static String release = "";  // varchar(128)
  static String s_level = "";  // varchar(128)
  static String b_level = "";  // varchar(128)
  static String prdname = "";  // varchar(128)
  static String version = "";
  static String cfgfile = "";  // the returned tablespace value of space used in percent
  static String[] cfgdata = new String[1000];
  static String output   = ""; // the plugin output string
  static String perfdata = ""; // the plugin perfdata output, returning the KB values
  static String dbUrl    = ""; // the access URL for the database to query
  static String query    = ""; // the SQL query to execute

  public static void main (String args[]) {
    if (args.length < 5) {
      System.err.println("Error: Missing Arguments.");
      System.err.println("Usage: java check_dbversion_mysql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> [-d]");
      System.err.println("Usage: java check_dbversion_mysql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -f configfile");
      System.exit(-1);
    }
    // Check if we got -d for debug
    if (args.length == 6 && args[5].equals("-d")) { debug=1;}

    // Check if we got a config file to compare against
    if (args.length == 7 && args[5].equals("-f")) { 
      cfgfile=args[6];
      try {
         // Open the configuration file
         FileInputStream fstream = new FileInputStream(cfgfile);
         // Convert our input stream to a DataInputStream
         BufferedReader in = new BufferedReader(new InputStreamReader(fstream));
     
         // Continue to read lines while there are still some left to read
         int counter = 0;
         while (in.ready()) {
           String line = in.readLine(); 
           line = line.trim();
           // load config data while ignoring comment lines starting with #
           if (! line.startsWith("#")) { 
             cfgdata[counter] = line;
             counter++;
          }
	}
	in.close();
	fstream.close();
      } 
      catch (Exception e) { System.err.println("File input error"); }
    }

    dbUrl = "jdbc:mysql://" + args[0] +":" + args[1] +"/" + args[2] + "?user=" + args[3] + "&password=" + args[4];
    if (debug == 1) { System.out.println("DB connect: " + dbUrl); }

    try {
      // use the JDBC driver
      Class.forName("com.mysql.jdbc.Driver");
    } catch (ClassNotFoundException e) {
      System.err.println("Error: JDBC Driver Problem.");
      System.err.println (e);
      System.exit (3);
    }
    try {
      // open connection to database "jdbc:mysql://destinationhost:port/dbname?dbuser&dbpassword"
      Connection connection = DriverManager.getConnection(dbUrl);

      // build query
      query = "show variables where variable_name = 'hostname' or variable_name = 'version' or variable_name = 'version_comment' or variable_name = 'version_compile_machine'";
      if (debug == 1) { System.out.println ("DB query: " + query); }

      // execute query
      Statement statement = connection.createStatement ();
      ResultSet rs = statement.executeQuery (query);

      // get database information into performance data field
      DatabaseMetaData dbmd = connection.getMetaData();
      prdname = dbmd.getDatabaseProductName();

      while ( rs.next () ) {
        // get values from column "2"
        if (rs.getString(1).equals("hostname"))               { db_name = rs.getString(2); }
        if (rs.getString(1).equals("version"))                { release = rs.getString(2); }
        if (rs.getString(1).equals("version_comment"))        { s_level = rs.getString(2); }
        if (rs.getString(1).equals("version_compile_machine")){ b_level = rs.getString(2); }
      }
      if (debug == 1) { 
        System.out.format ("Server Name: %20s|Product Version: %10s|Version Comment: %10s|Architecture: %10s\n",
        db_name, release, s_level, b_level);
      }

      rs.close () ;
      statement.close () ;
      connection.close () ;

    } catch (java.sql.SQLException e) {
      System.err.println (e) ;
      System.exit (3) ; // return UNKNOWN
    }

    version =  prdname + " v" + release;
    output = version + ", " +s_level  + " " + b_level;

    // If we have no config file, we are in reporting mode
    if ( cfgfile.equals("") ) {
      System.out.println("Version OK: " + output + "|" + perfdata);
      System.exit (0); // return OK
    } else {
    // -------------------------------------------------------------------------------
    // We are in 'compliance' mode, we check the DB Version against the config file
    // -------------------------------------------------------------------------------
      int counter=0;
      String required = "";
      String  dbgroup = "";
      String dbversion= "";
      String remarks  = "";
      while(cfgdata[counter] != null) {
      StringTokenizer st = new StringTokenizer(cfgdata[counter], "|");
      if (st.hasMoreTokens()) { required   = st.nextToken(); }
      if (st.hasMoreTokens()) { dbgroup    = st.nextToken(); }
      if (st.hasMoreTokens()) { dbversion  = st.nextToken(); }
      if (st.hasMoreTokens()) { remarks    = st.nextToken(); }

        if( dbgroup.equals("mysql") && dbversion.equals(version) && required.equals("approved")) {
          if(! remarks.equals("")) { perfdata = remarks; }
          System.out.println("Version OK: " + version + "|" + perfdata);
          System.exit (0); // return OK
        }

        if( dbgroup.equals("mysql") && dbversion.equals(version) && required.equals("obsolete")) {
          if(! remarks.equals("")) { perfdata = remarks; }
          System.out.println("Version WARN: " + version + " obsolete"  + "|" + perfdata);
          System.exit (1); // return WARN
        }

        if( dbgroup.equals("mysql") && dbversion.equals(version) && required.equals("med-vuln")) {
          if(! remarks.equals("")) { perfdata = remarks; }
          System.out.println("Version WARN: " + version + " vulnerable (low-medium)"  + "|" + perfdata);
          System.exit (1); // return WARN
        }

        if( dbgroup.equals("mysql") && dbversion.equals(version) && required.equals("crit-vuln")) {
          if(! remarks.equals("")) { perfdata = remarks; }
          System.out.println("Version CRITICAL: " + version + " vulnerable (high risk)"  + "|" + perfdata);
          System.exit (2); // return CRITICAL
        }
        counter++;
      }
    //  the OS version is not listed, we don't know exactly if its good or bad.
    System.out.println("Version UNKNOWN: "+version+ " unverified" + "|" + perfdata);
    System.exit (3); // return UNKNOWN;
    }
  }
}
