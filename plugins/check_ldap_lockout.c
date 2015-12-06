/* ---------------------------------------------------------------------------- *
 * check_ldap_lockout v1.2, 20110314 frank4dd                                   *
 * see http://nagios.fm4dd.com/                                                 *
 *                                                                              *
 * This Nagios plugin connects to a Actice Directory LDAP using                 *
 * simple bind, checks if a domain user has been locked out and                 *
 * if so, it returns the date when the lockout happened.                        *
 *                                                                              *
 * Compile: gcc -o check_ldap_lockout check_ldap_lockout.c -lldap               *
 *                                                                              *
 * Changelog:                                                                   *
 * v1.2:  - a newly created AD user does not have the attribute "lockoutTime"   *
 * v1.1:  - For W2003 AD, we add a preference to switch off the ldap referals   *
 * ---------------------------------------------------------------------------- */
#define VERSION "1.2"
#include <stdio.h>
#include <stdlib.h>
#include <ldap.h>
#include <time.h>
#include <getopt.h>

enum { OK    = 0,
       ERROR = -1 };

enum { EXIT_OK        = 0,
       EXIT_WARNING   = 1,
       EXIT_CRITICAL  = 2,
       EXIT_UNKNOWN   = 3,
       EXIT_DEPENDENT = 4 };

char *progname = "check_ldap_lockout";
// global vars
int  debug          = 0;
int  auth_method    = LDAP_AUTH_SIMPLE;
int  ldap_version   = LDAP_VERSION3;
char *ldap_host     = "";  // "192.168.100.25"
int   ldap_port     = 389; // default
char *ldap_dn       = "";  // "ldapconnect@frank4dd.com";
char *ldap_pw       = "";  // "Eng1-ous";
char *base_dn       = "";  // "OU=User,DC=frank4dd,DC=com";
char *ldap_user     = "";  // "frank4dd";
int  timeout        = 5;   // LDAP timeout

void print_usage() {
  printf ("Usage: check_ldap_lockout [-h] | -H <ldap host> [-p <ldap port>] -U <ldap user> -P <ldap pass> -B <base DN> -C <account_name> [-v]\n");
  printf ("\n");
  exit(EXIT_UNKNOWN);
}

void print_help (void) {
  printf ("%s v%s\n", progname, VERSION);
  printf ("Copyright (c) 2010 Frank4DD (support@frank4dd.com)\n");
  printf ("check_ldap_lockout connects to a Actice Directory LDAP using simple bind and checks if a domain user has been locked out.\n");
  printf  ("\n");
  printf ("Usage: check_ldap_lockout [-h] | -H <ldap host> [-p <ldap port>] -u <ldap user> -p <ldap pass> -b <base DN> -c <account_name> [-v]\n");
  printf  ("\n");
  printf (" %s\n", "-h [--help]");
  printf ("    %s\n", "Returns this help message");
  printf (" %s\n", "-H [--host]");
  printf ("    %s\n", "ldap host to search, name or IP address");
  printf (" %s\n", "-p [--port]");
  printf ("    %s\n", "ldap port on host, if omitted defaults to tcp-389");
  printf (" %s\n", "-U [--user]");
  printf ("    %s\n", "ldap bind user DN");
  printf (" %s\n", "-P [--pass]");
  printf ("    %s\n", "ldap password (if required)");
  printf (" %s\n", "-B [--base]");
  printf ("    %s\n", "ldap base (eg. ou=my unit, o=my org, c=at");
  printf (" %s\n", "-C [--check]");
  printf ("    %s\n", "the AD account name to check for expiration");
  printf (" %s\n", "-V [--version]");
  printf ("    %s\n", "returns the plugin version");
  printf (" %s\n", "-v [--verbose]");
  printf ("    %s\n", "returns verbose plugin output for troubleshooting");
  exit (EXIT_OK);
}

int validate_arguments () {
  if (ldap_host==NULL || strlen(ldap_host)==0)
    printf("Error: Please specify the host name\n");

  if (base_dn==NULL)
    printf("Error: Please specify the LDAP base\n");
  return OK;
}

/* process command-line arguments */
int process_arguments (int argc, char **argv) {
  int c;
  int option = 0;

  /* initialize the long option struct */
  static struct option longopts[] = {
    {"help",    no_argument,       0, 'h'},
    {"host",    required_argument, 0, 'H'},
    {"port",    required_argument, 0, 'p'},
    {"user",    required_argument, 0, 'U'},
    {"pass",    required_argument, 0, 'P'},
    {"base",    required_argument, 0, 'B'},
    {"check",   required_argument, 0, 'C'},
    {"version", no_argument,       0, 'V'},
    {"verbose", no_argument,       0, 'v'},
    {0, 0, 0, 0}
  };

  if (argc < 2) {
    printf("Error: No arguments provided.\n");
    print_usage();
  }
  while (1) { /* in the getopt list, a arg followed by : requires a value */
    c = getopt_long (argc, argv, "hVvH:p:U:P:B:C:", longopts, &option);
    if (c == -1 || c == EOF) break;
    switch (c) {
      case 'h':                                 /* help */
        print_help();
        break;
      case 'H':                                 /* host */
        ldap_host = optarg;
        break;
      case 'p':                                 /* port */
        ldap_port = atoi (optarg);
        break;
      case 'U':                                 /* user */
        ldap_dn = optarg;
        break;
      case 'P':                                 /* pass */
        ldap_pw = optarg;
        break;
      case 'B':                                 /* base */
        base_dn = optarg;
        break;
      case 'C':                                 /* check */
        ldap_user = optarg;
        break;
      case 'V':                                 /* version */
        printf ("%s v%s\n", progname, VERSION); 
        exit (EXIT_OK);
      case 'v':                                /* verbose */
        if (argc < 6) return ERROR;
        debug = 1;
        break;
     // default:
     //   printf("Error: Could not parse arguments\n");
     //   print_usage();
     //   break;
    }
  }
  c = optind;
  if (ldap_host == NULL && argv[c]) ldap_host = strdup (argv[c++]);
  if (base_dn == NULL && argv[c]) base_dn = strdup (argv[c++]);
  return validate_arguments();
}


int main( int argc, char **argv ) {
  LDAP         *ldap;
  LDAPMessage  *answer, *entry;
  BerElement   *ber;
  int           ret = EXIT_UNKNOWN;
  int           result;
  double        windows_ts = 0;
  time_t        unix_ts;

  if (process_arguments (argc, argv) == ERROR) {
    printf("Error: Could not parse arguments\n");
    print_usage();
  }

  // scope can be either LDAP_SCOPE_SUBTREE or LDAP_SCOPE_ONELEVEL
  int  scope          = LDAP_SCOPE_SUBTREE;
  // the search filter, "(objectClass=*)" returns everything. Windows returns only
  // 1000 objects in one search. If to "wide", ldap_search_s returns "Size limit exceeded"
  char filter[1024];
  // The attribute list to be returned in a search, use NULL for getting all attributes
  char *attrs[]       = {"displayName", "lockoutTime", NULL};   
  // Specify if the search should return only attribute types (1), or both type and value (0)
  int  attrsonly      = 0;
  // entries_found holds the count of how many objects have been found in the LDAP search
  int  entries_found  = 0;
  // dn holds the DN name string of the object(s) returned by the search
  char *dn            = "";
  // attribute holds the attribute name of the object(s) attributes returned by the search
  char *attribute     = "";
  // values holds the attribute values of the object(s) attributes returned by the search
  int i;
  char **values;
  // lockout_ts holds the value returned for the attribute lockoutTime, which is a string
  // containing 8 bytes respresenting the time in nanoseconds since Jan, 1st, 1601
  char *lockout_ts    = NULL;
  
  /* First, we print out an informational message. */
  if(debug) {
    printf( "Connecting to host [%s] at port [%d] with user [%s] and pw [%s]\n", ldap_host, ldap_port, ldap_dn, ldap_pw);
  }
  
  /* STEP 1: Get a handle to an LDAP connection and set any session preferences. */
  /* to use ldaps, we need to call ldap_sslinit(char *host, int port, int secure); */
  if ( (ldap = ldap_init(ldap_host, ldap_port)) == NULL ) { 
    perror( "ldap_init failed" );
    exit( EXIT_FAILURE );
  } else {
    if(debug) printf("Generated LDAP handle.\n");
  }
  
  /* Use the LDAP_OPT_PROTOCOL_VERSION session preference to specify that the client is an LDAPv3 client. */
  result = ldap_set_option(ldap, LDAP_OPT_PROTOCOL_VERSION, &ldap_version);

  /* The library should implicitly *not* chase referrals. */
  result = ldap_set_option(ldap, LDAP_OPT_REFERRALS, LDAP_OPT_OFF);

  if ( result != LDAP_OPT_SUCCESS ) {
      ldap_perror(ldap, "ldap_set_option failed!");
      exit(EXIT_FAILURE);
  } else {
    if(debug) printf("Set LDAPv3 client version.\n");
  }
  
  ldap_set_option(ldap, LDAP_OPT_TIMEOUT, &timeout);

  /* STEP 2: Bind to the server. */
  // If no DN or credentials are specified, the client binds anonymously to the server */
  // result = ldap_simple_bind_s( ldap, NULL, NULL );
  result = ldap_simple_bind_s(ldap, ldap_dn, ldap_pw );

  if ( result != LDAP_SUCCESS ) {
    fprintf(stderr, "ldap_simple_bind_s: %s\n", ldap_err2string(result));
    exit(EXIT_FAILURE);
  } else {
    if(debug) printf("LDAP connection successful.\n");
  }
  
  /* STEP 3: Build the search filter string. */
  // The object search filter: check if a entry is a user,
  // and if the given account name matches sAMAccountName.
  snprintf(filter, sizeof(filter), "(&(%s)(sAMAccountName=%s))", "objectClass=user", ldap_user);
  if(debug)  printf("Using Search filter [%s].\n", filter);

  /* STEP 4: Do a LDAP search. */
  result = ldap_search_s(ldap, base_dn, scope, filter, attrs, attrsonly, &answer);
  if ( result != LDAP_SUCCESS ) {
    fprintf(stderr, "ldap_search_s: %s\n", ldap_err2string(result));
    exit(EXIT_FAILURE);
  } else {
    if(debug) printf("LDAP search successful.\n");
  }

  /* Return the number of objects found during the search */
  entries_found = ldap_count_entries(ldap, answer);
  if ( entries_found == 0 ) {
    fprintf(stderr, "LDAP search did not return any data.\n");
    exit(EXIT_FAILURE);
  } else {
    if(debug) printf("LDAP search returned %d objects.\n", entries_found);
  }

  /* cycle through all objects returned with our search */
  for ( entry = ldap_first_entry(ldap, answer);
        entry != NULL;
        entry = ldap_next_entry(ldap, entry)) {

    /* Print the DN string of the object */
    dn = ldap_get_dn(ldap, entry);
    if(debug) printf("Found object [%s]\n", dn);


   // cycle through all returned attributes
    for ( attribute = ldap_first_attribute(ldap, entry, &ber);
          attribute != NULL;
          attribute = ldap_next_attribute(ldap, entry, ber)) {

      /* Print the attribute name */
      if(debug) printf("Found attribute: [%s] ", attribute);
      if ((values = ldap_get_values(ldap, entry, attribute)) != NULL) {

        /* cycle through all values returned for this attribute */
        for (i = 0; values[i] != NULL; i++) {

          /* print each value of a attribute here */
          if(debug) printf("value [%s]\n", values[i] );

          /* check if the attribute is the lockoutTime */
          if(strcmp(attribute, "lockoutTime")==0) {
            lockout_ts = values[i];
            /* convert the lockout Windows timestring (8 bytes) to double */
            windows_ts = strtod(lockout_ts, NULL);
            if(debug) printf("Windows timestring converted to number [%.0f]\n", windows_ts);
            /* if the windows_ts value is 0 the account is active, otherwise it is locked */
          }
        }
        ldap_value_free(values);
      }
    }

    /* Check if we got a Windows lockout timestamp */
    if(windows_ts > 0) {
      /* convert Windows timestamp into a UNIX timestamp */
      unix_ts = ((windows_ts/(double) 10000000 - (double) 11644473600)+0.5);
      if(debug) printf("Windows timestamp converted to UNIX timestamp [%.0f]\n", unix_ts);
      printf("CRITICAL: Account %s locked out at %s", ldap_user, ctime(&unix_ts));
      ret = EXIT_CRITICAL;
    } else {
      printf("OK: Account %s is active\n", ldap_user);
      ret = EXIT_OK;
    }
    ldap_memfree(dn);
  }
  ldap_msgfree(answer);
  ldap_unbind(ldap);
  return(ret);
}
