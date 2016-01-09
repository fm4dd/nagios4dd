# check_ldap_lockout

## Man page for the Nagios plugin check_ldap_lockout

<div id="copyright">Update (c) 2010 Frank4DD<support[at]frank4dd.com></div>

### check_ldap_lockout

This plugin checks if a Windows domain user ID is locked out by querying the AD repository through LDAP. Many support teams cannot handle complex passwords even *with* writing them down. :-) As a result, batch jobs fail, application access is locked, or worse...

#### Dependencies:

The plugin is written in 'C' and depends on the OpenLDAP 'C' library and development headers. It can be compiled standalone, independend of other Nagios plugins. It supports only cleartext connections, LDAPS is not yet implemented.

<pre>fm@susie: ~ # rpm -q -a |grep openldap
openldap2-devel-2.4.12-7.16
openldap2-client-2.4.12-7.19.1</pre>

#### Compilation:

gcc -o check_ldap_lockout check_ldap_lockout.c -lldap

#### Usage:

`check_ldap_logout [-h] | -H <ldap host> [-p <ldap port>] -U <ldap user> -P <ldap pass> -B <base DN> -C <account_name> [-v]`

#### Options:

-h, --help  
      print this help message

-H, --host=HOSTNAME|IP  
      name or IP address of host to check

-p, --port=INTEGER  
      the LDAP server's TCP port number (Default: 389)

-U, --user=STRING  
      the LDAP bind user DN

-P, --pass=STRING  
      the LDAP bind users password

-B, --base=STRING  
      the LDAP base to search from (eg. ou=my unit, o=my org)

-C, --check=STRING  
      the the AD account name to check for lockout

-V, --version  
      prints version number

-v, --verbose  
      print extra debugging information

#### Plugin Definition Example:

Below is an example of the plugin definition in the Nagios command.cfg file.

<pre># check_ldap_lockout nagios plugin
define command{
  command_name check_ldap_lockout
  command_line $USER1$/check_ldap_lockout -H $HOSTADDRESS$ -U $ARG1$ -P $ARG2$ -B $ARG3$ -C $ARG4$
}</pre>

#### Plugin Usage Example:

The plugin with its most basic use, returning the account lockout status of the Windows account 'support' against a AD domain controller with IP 192.168.1.25, using the AD account 'ldap' for queries in domain 'frank4dd.com'.

<pre>susie: ~ # cd /srv/app/nagios/libexec
susie: ~ # ./check_ldap_lockout -H 192.168.1.25 -U ldap@frank4dd.com -P p@ssw0rd -B OU=User,DC=frank4dd,DC=com -C support
OK: Account support is active</pre>

A example query with a user being locked out:

<pre class="code">susie: ~ # ./check_ldap_lockout -H 192.158.1.25 -U ldap@frank4dd.com -P  p@ssw0rd -B OU=User,DC=frank4dd,DC=com -C support
CRITICAL: Account support locked out at Tue Dec 28 09:53:19 2010</pre>

A example query with verbose output for troubleshooting:

<pre>susie: ~ # cd /srv/app/nagios/libexec
susie: ~ # ./check_ldap_lockout -H 192.168.1.25 -U ldap@frank4dd.com -P p@ssw0rd -B OU=User,DC=frank4dd,DC=com -C support -v
Connecting to host [192.168.1.25] at port [389] with user [ldap@frank4dd.com] and pw [p@ssw0rd]
Generated LDAP handle.
Set LDAPv3 client version.
LDAP connection successful.
Using Search filter [(&(objectClass=user)(sAMAccountName=support))].
LDAP search successful.
LDAP search returned 1 objects.
Found object [CN=support,OU=IT_Department,OU=User,DC=frank4dd,DC=com]
Found attribute: [displayName] value [IT Support Account]
Found attribute: [lockoutTime] value [0]
Windows timestring converted to number [0]
OK: Account support is active</pre>
