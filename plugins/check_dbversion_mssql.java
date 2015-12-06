// ----------------------------------------------------------------------------
// check_dbversion_mssql.java 20100209 frank4dd version 1.0
// ----------------------------------------------------------------------------
// e-mail: support[at]frank4dd.com
// web:    http://nagios.fm4dd.com/
//
// This nagios plugin queries the MS-SQL builtin SERVERPROPERTY objects.
// The objects 'productversion', 'productlevel' and 'edition' are returned.
// Supported are MS-SQL server versions 2005, other versions may work also.
//
// Pre-requisites: MSSQL JDBC driver installed and DB user has select rights.
// jdbc driver files i.e. sqljdbc.jar, sql4jdbc.jar
// ----------------------------------------------------------------------------
// Example Output:
// > java check_dbversion_mssql 192.168.98.128 1433 mydb dbuser "password"
// Version OK: Microsoft SQL Server v9.00.3054.00 SP2, Standard Edition|
// ----------------------------------------------------------------------------
// return codes 'OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4
// ----------------------------------------------------------------------------
import java.sql.*;
import java.io.*;
import java.util.*;

class check_dbversion_mssql {

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
      System.err.println("Usage: java check_dbversion_mssql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> [-d]");
      System.err.println("Usage: java check_dbversion_mssql <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -f configfile");
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


    dbUrl = "jdbc:sqlserver://" + args[0] +":" + args[1] +";databaseName=" + args[2] + ";user=" + args[3] + ";password=" + args[4] + ";";
    if (debug == 1) { System.out.println("DB connect: " + dbUrl); }

    try {
      // use the JDBCtype 4 driver
      Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
    } catch (ClassNotFoundException e) {
      System.err.println("Error: JDBC Driver Problem.");
      System.err.println (e);
      System.exit (3);
    }
    try {
      // open connection to database "jdbc:sqlserver://destinationhost:port/dbname;user=dbuser;password=dbpassword;"
      Connection connection = DriverManager.getConnection(dbUrl);

      // build query
      query = "SELECT  convert(varchar(128), SERVERPROPERTY('ServerName')), convert(varchar(128), SERVERPROPERTY('productversion')), convert(varchar(128),SERVERPROPERTY ('productlevel')), convert(varchar(128), SERVERPROPERTY ('edition'))";
      if (debug == 1) { System.out.println ("DB query: " + query); }

      // execute query
      Statement statement = connection.createStatement ();
      ResultSet rs = statement.executeQuery (query);

      // get database information into performance data field
      DatabaseMetaData dbmd = connection.getMetaData();
      prdname = dbmd.getDatabaseProductName();

      while ( rs.next () ) {
        if (debug == 1) { 
          System.out.format ("Server Name: %20s|",     rs.getString(1)); // varchar(128) i.e. DB2
          System.out.format ("Product Version: %10s|", rs.getString(2)); // varchar(128) i.e. 06050107
          System.out.format ("Product Level: %10s|",   rs.getString(3)); // varchar(128) i.e. DB2 v9.5.400.576
          System.out.format ("Edition: %10s\n",        rs.getString(4)); // varchar(128) i.e. s090429
        }
        // get content from column "1-4"
        db_name = rs.getString(1);
        release = rs.getString(2);
        s_level = rs.getString(3);
        b_level = rs.getString(4);
      }

      rs.close () ;
      statement.close () ;
      connection.close () ;

    } catch (java.sql.SQLException e) {
      System.err.println (e) ;
      System.exit (3) ; // Unknown
    }

    version =  prdname + " v" + release + " " + s_level;
    output = version + ", " + b_level;

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
      String remarks  = "";
      while(cfgdata[counter] != null) {
      StringTokenizer st = new StringTokenizer(cfgdata[counter], "|");
      if (st.hasMoreTokens()) { required   = st.nextToken(); }
      if (st.hasMoreTokens()) { dbgroup    = st.nextToken(); }
      if (st.hasMoreTokens()) { dbversion  = st.nextToken(); }
      if (st.hasMoreTokens()) { remarks    = st.nextToken(); }

        if( dbgroup.equals("mssql") && dbversion.equals(version) && required.equals("approved")) {
          if(! remarks.equals("")) { perfdata = remarks; }
          System.out.println("Version OK: " + version + "|" + perfdata);
          System.exit (0); // OK
        }

        if( dbgroup.equals("mssql") && dbversion.equals(version) && required.equals("obsolete")) {
          if(! remarks.equals("")) { perfdata = remarks; }
          System.out.println("Version WARN: " + version + " obsolete"  + "|" + perfdata);
          System.exit (1); // WARN
        }

        if( dbgroup.equals("mssql") && dbversion.equals(version) && required.equals("med-vuln")) {
          if(! remarks.equals("")) { perfdata = remarks; }
          System.out.println("Version WARN: " + version + " vulnerable (low-medium)"  + "|" + perfdata);
          System.exit (1); // WARN
        }

        if( dbgroup.equals("mssql") && dbversion.equals(version) && required.equals("crit-vuln")) {
          if(! remarks.equals("")) { perfdata = remarks; }
          System.out.println("Version CRITICAL: " + version + " vulnerable (high risk)"  + "|" + perfdata);
          System.exit (2); // CRITICAL
        }
        counter++;
      }
    //  the OS version is not listed, we don't know exactly if its good or bad.
    System.out.println("Version UNKNOWN: "+version+ " unverified" + "|" + perfdata);
    System.exit (3); // UNKNOWN;
    }
  }
}
