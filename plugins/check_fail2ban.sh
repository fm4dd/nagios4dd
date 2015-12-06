#!/bin/bash
# ########################################################
# Written by Andor Westphal andor.westphal@gmail.com     #
# Created: 2013-02-22   (version 1.0)                    #
# Modified:2013-03-12   (version 1.1)                    #
# Modified:2015-03-29   (version 1.2) http://fm4dd.com/  #
# === public@frank4dd.com ===                            #
#                                                        #
# checks the count of active jails                       #
# checks for banned IP's                                 #
# integrated performance data for banned IPs             #
#                                                        #
# NOTE: To run the fail2ban-client, Nagios needs access  #
# to /var/run/fail2ban/fail2ban.sock. I configured below:#
# setfacl -m u:nagios:rwx /var/run/fail2ban/fail2ban.sock#
# ########################################################
STATUS_OK="0"
STATUS_WARNING="1"
STATUS_CRITICAL="2"
STATUS_UNKNOWN="3"
fail2ban_client=$(which fail2ban-client)

# #####################################################################
# Program usage
# #####################################################################
print_usage() {
PROGPATH=`dirname $0`
echo "Usage: $PROGPATH/check_fail2ban.sh -h for help (this message)
   -w <your warnlevel>
   -c <your critlevel>
Example: $PROGPATH/check_fail2ban.sh -w 10 -c 20"
}

# #####################################################################
# Check if fail2ban is running
# #####################################################################
ps_state=$(ps aux |grep "fail2ban.sock" |grep -v grep| wc -l)

if [ "$ps_state" -lt "1" ]; then
        echo "Error: Process is not running."
        exit $STATUS_CRITICAL
fi

# #####################################################################
# Check if commandline arguments are given
# #####################################################################
if [ -z "$1" ];then
        echo "Error: No arguments found."
        print_usage
        exit $STATUS_UNKNOWN
fi

# #####################################################################
# Process commandline arguments
# #####################################################################
while test -n "$1"; do
    case "$1" in
        -w)
            warn=$2
            shift
            ;;
        -c)
            crit=$2
            shift
            ;;
        -h)
            print_usage
            exit $STATUS_UNKNOWN
            ;;
        *)
            echo "Error: Unknown argument $1"
            print_usage
            exit $STATUS_UNKNOWN
            ;;
    esac
  shift
done

# #####################################################################
# Error handling for missing arguments
# #####################################################################
if [ -z ${crit} ] ||  [ -z ${warn} ]; then
        echo "Error: missing arguments."
        print_usage
        exit $STATUS_UNKNOWN
fi

# #####################################################################
# Main program
# #####################################################################
bcount=0            # total of blocked IP
long_out=""         # long output
add_perf=""         # extra perf data

# #####################################################################
# Run the fail2ban-client, and return the count of operating jails
# #####################################################################
jail_count=$($fail2ban_client status|grep "Number" |cut -f 2)

if [ "$jail_count" -lt "1" ]; then
        echo "Error: No operating jail."
        exit $STATUS_CRITICAL
fi

# #####################################################################
# Run the fail2ban-client, and generate the list of operating jails
# #####################################################################
jail_list=$($fail2ban_client status|grep "list" |cut -f 3 |tr -d ,)

# #####################################################################
# Cycle through all jails, count blocked IP, and build output strings
# #####################################################################
for jail in $jail_list; do
  # Calculate the total of blocked IP
  ip_list=( $($fail2ban_client status $jail|grep "IP list" |cut -f 2) )
  bcount=$((bcount+${#ip_list[@]}))
  # Generate the LONGSERVICEOUTPUT string
  long_out=$long_out"jail $jail blocks ${#ip_list[@]} IP(s): ${ip_list[@]}\n"
  # Generate the additional performance data
  add_perf=$add_perf" $jail=${#ip_list[@]};;;;"
done

if [ "$bcount" -ge ${warn} ] && [ "$bcount" -lt ${crit} ]; then
        State="WARNING"
elif [ "$bcount" -ge ${warn} ];then
        State="CRITICAL"
else
        State="OK"
fi

# #####################################################################
# Define the SERVICEOUTPUT string, format: SERVICE STATUS: Info text
# #####################################################################
OUTPUT="${State}: ${bcount} banned IP(s) in ${jail_count} active jails"

# #####################################################################
# Add SERVICEPERFDATA
# format: 'label'=value[unit-of-measure];[warn];[crit];[min];[max]
# #####################################################################
OUTPUT="$OUTPUT|banned_IP=${bcount};${warn};${crit};;"

# #####################################################################
# Add LONGSERVICEOUTPUT, format: jail_name
# #####################################################################
OUTPUT="$OUTPUT\n$long_out"

# #####################################################################
# Add performance data
# format: 'label'=value[unit-of-measure];[warn];[crit];[min];[max]
# #####################################################################
OUTPUT="$OUTPUT|$add_perf"

echo -e $OUTPUT

# #####################################################################
# Set the program return code
# #####################################################################
if [ ${State} == "WARNING" ];then 
        exit ${STATUS_WARNING}
elif [ ${State} == "CRITICAL" ];then 
        exit ${STATUS_CRITICAL}
elif [ ${State} == "UNKNOWN" ];then 
        exit ${STATUS_UNKNOWN}
else
        exit ${STATUS_OK}
fi
