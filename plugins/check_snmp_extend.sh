#!/bin/sh
# ###################################################################
# Nagios plugin to query script output via SNMP "extend" mechanism
# from remote servers.
# 
# Author Michal Ludvig <michal@logix.cz> (c) 2006
#        http://www.logix.cz/michal/devel/nagios
#	  
# 20081003 <support@frank4dd.com> http://nagios.fm4dd.com/
# separating out the SNMP community for greater flexibility
# ##################################################################
# check_snmp_extend.sh configuration example (Nagios 3.0.2)
# =========================================================
# Add the following lines into nagios' configuration, i.e.
# command.cfg, which in turn is included into nagios.cfg:
# 
# # 'check_snmp_extend' command definition
# # Syntax: check_snmp_extend.sh hostip community extend-name
# define command {
#   command_name  check_snmp_extend
#   command_line  $USER1$/check_snmp_extend.sh $HOSTADDRESS$ $ARG1$ $ARG2$
# }
# 
# Older versions of Net-SNMP do not support the "extend" keyword.
# There, use "exec" with check_snmp_exec.sh.

# include Nagios globals
. /home/app/nagios/libexec/utils.sh || exit 3

# print syntax if called without arguments
if [ ! $1 ]; then
  echo "  Syntax: check_snmp_extend.sh ipaddr community extend-name"
fi

SNMPGET=$(which snmpget)
test -x ${SNMPGET} || exit $STATE_UNKNOWN

# parse and validate the commandline arguments
HOST=$1
shift
COMMUNITY=$1
shift
NAME=$1

test "${HOST}" -a "${COMMUNITY}" -a "${NAME}" || exit $STATE_UNKNOWN

# do the SNMP query and strip of the return data
RESULT=$(snmpget -v2c -c ${COMMUNITY} -OvQ ${HOST} NET-SNMP-EXTEND-MIB::nsExtendOutputFull.\"${NAME}\" 2>&1)

STATUS=$(echo $RESULT | cut -d\  -f1)

# check if we got a Nagios conform message
case "$STATUS" in
	OK|WARNING|CRITICAL|UNKNOWN)
		RET=$(eval "echo \$STATE_$STATUS")
		;;
	*)
		RET=$STATE_UNKNOWN
		RESULT="UNKNOWN - SNMP returned unparsable status: $RESULT"
		;;
esac

echo $RESULT
exit $RET
