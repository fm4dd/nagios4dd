// ----------------------------------------------------------------------------
// check_dbversion_db2.java 20100209 frank4dd version 1.0
// ----------------------------------------------------------------------------
// e-mail: support[at]frank4dd.com
// web:    http://nagios.fm4dd.com/
//
// This nagios plugin queries the DB2 ENV_INST_INFO administrative view.
// The ENV_INST_INFO administrative view returns information about the current instance.
// Supported are DB2 versions 9.x
//
// Pre-requisites: DB2 JDBC driver installed and DB user has select rights
// jdbc driver files i.e. db2jcc.jar, db2jcc4.jar, db2jcc_license_cu.jar
// ----------------------------------------------------------------------------
// Example Output:
// > java check_dbversion_db2 192.168.90.64 50007  DBB3_H_Z SMDHSD3I "pass123" -d
// ----------------------------------------------------------------------------
// return codes are 'OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4
// ----------------------------------------------------------------------------
import java.sql.*;
import java.io.*;
import java.util.*;

class check_dbversion_db2 {

  static int    debug   = 0;  // 'normal'=>0,'verbose'=>1 when -d parameter is given
  static String db_name = "";  // varchar(128)
  static int    bitsize = 0;  // int
  static String release = "";  // varchar(128)
  static String s_level = "";  // varchar(128)
  static String b_level = "";  // varchar(128)
  static String temp_fix= "";  // varchar(128)
  static String fixpack = "";  // int
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
      System.err.println("Usage: java check_dbversion_db2 <db-ip> <db-port> <db-instance> <db-user> <db-pwd> [-d]");
      System.err.println("Usage: java check_dbversion_db2 <db-ip> <db-port> <db-instance> <db-user> <db-pwd> -f configfile");
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


    dbUrl = "jdbc:db2://" + args[0] +":" + args[1] + "/" + args[2];
    if (debug == 1) { System.out.println("DB connect: " + dbUrl); }

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
      query = "select INST_NAME, INST_PTR_SIZE, RELEASE_NUM, SERVICE_LEVEL, BLD_LEVEL, PTF, FIXPACK_NUM FROM SYSIBMADM.ENV_INST_INFO";
      if (debug == 1) { System.out.println ("DB query: " + query); }

      // execute query
      Statement statement = connection.createStatement ();
      ResultSet rs = statement.executeQuery (query);

      while ( rs.next () ) {
        if (debug == 1) { 
          System.out.format ("Name: %20s|",         rs.getString(1)); // varchar(128) i.e. DB2
          System.out.format ("32/64 Bit: %2d|",     rs.getInt(2));    // int          i.e. 64
          System.out.format ("SW Release: %10s|",   rs.getString(3)); // varchar(128) i.e. 06050107
          System.out.format ("ServiceLevel: %10s|", rs.getString(4)); // varchar(128) i.e. DB2 v9.5.400.576
          System.out.format ("BuildLevel: %10s|",   rs.getString(5)); // varchar(128) i.e. s090429
          System.out.format ("PTF: %10s|",          rs.getString(6)); // varchar(128) i.e. WR21450
          System.out.format ("Fixpack: %10s\n",     rs.getString(7)); // int          i.e. 4
        }
        // get content from column "1-7"
        db_name = rs.getString(1);
        bitsize = rs.getInt(2); 
        release = rs.getString(3);
        s_level = rs.getString(4);
        b_level = rs.getString(5);
        temp_fix= rs.getString(6);
        fixpack = rs.getString(7);
      }

      rs.close () ;
      statement.close () ;
      connection.close () ;

    } catch (java.sql.SQLException e) {
      System.err.println (e) ;
      System.exit (3) ; // Unknown
    }

    version =  s_level + " build " + b_level;
    output = version + " (" + bitsize + " bit), PTF: " + temp_fix + " FP: " + fixpack;

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

        if( dbgroup.equals("db2") && dbversion.equals(version) && required.equals("approved")) {
          if(! remarks.equals("")) { perfdata = remarks; }
          System.out.println("Version OK: " + version + "|" + perfdata);
          System.exit (0); // OK
        }

        if( dbgroup.equals("db2") && dbversion.equals(version) && required.equals("obsolete")) {
          if(! remarks.equals("")) { perfdata = remarks; }
          System.out.println("Version WARN: " + version + " obsolete"  + "|" + perfdata);
          System.exit (1); // WARN
        }

        if( dbgroup.equals("db2") && dbversion.equals(version) && required.equals("med-vuln")) {
          if(! remarks.equals("")) { perfdata = remarks; }
          System.out.println("Version WARN: " + version + " vulnerable (low-medium)"  + "|" + perfdata);
          System.exit (1); // WARN
        }

        if( dbgroup.equals("db2") && dbversion.equals(version) && required.equals("crit-vuln")) {
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
