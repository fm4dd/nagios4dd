// ----------------------------------------------------------------------------
// check_dbversion_postgresql.java 20130911 frank4dd version 1.0
// ----------------------------------------------------------------------------
// e-mail: support[at]frank4dd.com
// web:    http://nagios.fm4dd.com/
//
// This nagios plugin queries the PostgreSQL through "select version();"
// Supported are PostgreSQL versions 9.2 or newer
//
// Pre-requisites: PostgreSQL JDBC driver installed and DB user has select rights
// jdbc driver file e.g. postgresql-9.2-1003.jdbc4.jar
// ----------------------------------------------------------------------------
// Example Output:
// > java check_dbversion_postgresql 192.168.90.64 5432  postgres postgres "pass123" -d
//Version OK: PostgreSQL 9.3.2 on x86_64-unknown-linux-gnu, compiled by gcc (SUSE Linux)
// 4.7.2 20130108 [gcc-4_7-branch revision 195012], 64-bit|
//
// ----------------------------------------------------------------------------
// return codes are 'OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4
// ----------------------------------------------------------------------------
import java.sql.*;
import java.io.*;
import java.util.*;

class check_dbversion_postgresql {

  static int    debug   = 0;  // 'normal'=>0,'verbose'=>1 when -d parameter is given
  static String db_name = "";  // varchar(128)
  static int    bitsize = 0;  // int
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
      System.err.println("Usage: java check_dbversion_postgresql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> [-d]");
      System.err.println("Usage: java check_dbversion_postgresql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -f configfile");
      System.exit(-1);
    }
    // Check if we got -d for debug
    if (args.length == 6 && args[5].equals("-d")) { debug=1;}

    // Check if we got a config file to compare against
    if (args.length == 7 && args[5].equals("-f")) { 
      cfgfile=args[6];
      try {
         // Open the file
         FileInputStream fstream = new FileInputStream(cfgfile);
         // Convert our input stream to a DataInputStream
         BufferedReader in = new BufferedReader(new InputStreamReader(fstream));
     
         // Continue to read lines while there are still some left to read
         int counter = 0;
         while (in.ready()) {
           String line = in.readLine(); 
           line = line.trim();
           if (! line.startsWith("#")) { 
             // load config data and ignore comments
             cfgdata[counter] = line;
             counter++;
          }
	}
	in.close();
	fstream.close();
      } 
      catch (Exception e) { System.err.println("File input error"); }
    }


    dbUrl = "jdbc:postgresql://" + args[0] +":" + args[1] + "/" + args[2];
    if (debug == 1) { System.out.println("DB connect: " + dbUrl); }

    try {
      // use the JDBCtype 4 driver
      Class.forName("org.postgresql.Driver");
    } catch (ClassNotFoundException e) {
      System.err.println("Error: JDBC Driver Problem.");
      System.err.println (e);
      System.exit (3);
    }
    try {
      // open connection to database "jdbc:postgresql://destinationhost:port/dbname", "dbuser", "dbpassword"
      Connection connection = DriverManager.getConnection(dbUrl, args[3], args[4]);

      // build query
      query = "select version()";
      if (debug == 1) { System.out.println ("DB query: " + query); }

      // execute query
      Statement statement = connection.createStatement ();
      ResultSet rs = statement.executeQuery (query);

      while ( rs.next () ) {
        if (debug == 1) { 
          System.out.format ("Version: %s\n",         rs.getString(1)); // varchar(256) i.e. PostgreSQL xxx...
        }
        // get SQL data
        version = rs.getString(1);

        // Decode the received version string, field separator is '/'
        // PostgreSQL 9.3.2 on x86_64-unknown-linux-gnu, compiled by gcc (SUSE Linux)
        // 4.7.2 20130108 [gcc-4_7-branch revision 195012], 64-bit
        // Field order:
        // 1. Product, version and platform
        // 2. Compiler type and compilation date
        // 3. 32-bit or 64-bit system indicator.
    
        // We select 1, 3
        String delimiter = ",";
        String[] version;
        version = rs.getString(1).split(delimiter);

        prdname = version[0];
        release = version[1];
        b_level = version[2];
    
      }

      rs.close () ;
      statement.close () ;
      connection.close () ;

    } catch (java.sql.SQLException e) {
      System.err.println (e) ;
      System.exit (3) ; // Unknown
    }

    output = prdname + b_level;

    // If we have no config file, we are in reporting mode
    if ( cfgfile.equals("") ) {
      System.out.println("Version OK: " + output + "|" + perfdata);
      System.exit (0); // OK
    } else {
    //################################################################################
    //# We are in 'compliance' mode, we check the DB Version against the config file
    //################################################################################
      int counter=0;
      String required = "";
      String  dbgroup = "";
      String dbversion= "";
      String remarks = "";
      while(cfgdata[counter] != null) {
      StringTokenizer st = new StringTokenizer(cfgdata[counter], "|");
      if (st.hasMoreTokens()) { required   = st.nextToken(); }
      if (st.hasMoreTokens()) { dbgroup    = st.nextToken(); }
      if (st.hasMoreTokens()) { dbversion  = st.nextToken(); }
      if (st.hasMoreTokens()) { remarks    = st.nextToken(); }

        if( dbgroup.equals("pgsql") && dbversion.equals(output) && required.equals("approved")) {
          if(! remarks.equals("")) { perfdata = remarks; }
          System.out.println("Version OK: " + output + "|" + perfdata);
          System.exit (0); // OK
        }

        if( dbgroup.equals("pgsql") && dbversion.equals(output) && required.equals("obsolete")) {
          if(! remarks.equals("")) { perfdata = remarks; }
          System.out.println("Version WARN: " + output + " obsolete"  + "|" + perfdata);
          System.exit (1); // WARN
        }

        if( dbgroup.equals("pgsql") && dbversion.equals(output) && required.equals("med-vuln")) {
          if(! remarks.equals("")) { perfdata = remarks; }
          System.out.println("Version WARN: " + output + " vulnerable (low-medium)"  + "|" + perfdata);
          System.exit (1); // WARN
        }

        if( dbgroup.equals("pgsql") && dbversion.equals(output) && required.equals("crit-vuln")) {
          if(! remarks.equals("")) { perfdata = remarks; }
          System.out.println("Version CRITICAL: " + output + " vulnerable (high risk)"  + "|" + perfdata);
          System.exit (2); // CRITICAL
        }
        counter++;
      }
    //  the OS output is not listed, we don't know exactly if its good or bad.
    System.out.println("Version UNKNOWN: " + output + " unverified" + "|" + perfdata);
    System.exit (3); // UNKNOWN;
    }
  }
}
