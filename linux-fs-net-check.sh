#!/bin/bash
#Name    :  linux-fs-net-check.sh
#Owner	 :  root
#Date	 :  01/04/2019
#Version :  1
#Author  :  Rejmay Antony
#Permission : 750
#Intended for LINIX only
#This script must be executed on Linux servers before starting any activity,it will collect file system, network/route and IP address informations 
#this script can be used for validation of filesystem, network and IP address after any activity. 
#######################
#HOST check
#######################
if [ $(uname) != "Linux" ] > /dev/null
	then
		echo "\nNot an Linux machine, Aborting the program!!!" ; sleep 2
		exit
fi
#######################
#User check
#######################
if [ $(whoami) != root ] > /dev/null
	then
		echo "Permission Denied !!! Try using sudo to execute this script or switch to root"
	exit 1
fi
#######################
#Global Variables
#######################
DATE=$(date +%m.%d.%Y)
GREEN=$(echo -e  "\e[1;32mPASSED\e[0m")
AMBER=$(echo -e  "\e[1;33mWARNING\e[0m")
RED=$(echo -e  "\e[1;31mFAILED\e[0m")
HOST=$(hostname)
log_dir=/tmp/FS-NET-CHK
FS_INFO=$log_dir/fs_list.log
ROUTE=$log_dir/route_list.log
ROUTE_AFT=$log_dir/route-aft_list.log
IP_INFO=$log_dir/ip_list.log
IP_AFTR=$log_dir/ip_after_list.log
#######################
#Global Function
#######################
Usage ()
{
	echo "$0: option requires an argument pre OR post !!!" ; sleep 3
	echo "Usage:"
	echo "$0 pre | post"
	echo "pre   -   collects system details before reboot/any activity"
	echo "post  -   validates filesystems,IP address and network routs against the precheck log, fails if pre was not run"
	exit
}
IP_CON ()
{
	ip -o link show | awk -F ': ' '{print $2}' | sed 's/lo//' | tr "[ ]" "[\n]" | sed '/^$/d' | while read ENT
		do
			ifconfig ${ENT} | grep -w inet | awk '{print $2,$4}' | sed "s/^/$ENT /" 
		done
}
#######################
#Pre Check function
#######################
PRE ()
{
[[ ! -d $log_dir/ ]] && mkdir -p $log_dir

for FILE_LIST in $FS_INFO $ROUTE $IP_INFO $IP_AFTR
	do
		if [ -s $FILE_LIST ] > /dev/null
		then
			if [ ! -f ${FILE_LIST}_${DATE} ] > /dev/null
			then
				cp -p $FILE_LIST ${FILE_LIST}_${DATE}
			fi
		fi
	done
	
df -h | grep -vwE "tmpfs|devtmpfs" > $FS_INFO; sleep 2
netstat -nr | grep -E "[0-9]" | awk '{print $1"\t"$2"\t"$3"\t"$8}' > $ROUTE; sleep 2
IP_CON > $IP_INFO; sleep 2
echo $(date +%T) - Precheck Completes ; echo; sleep 2
echo ; echo "--> Logs stored at $log_dir directory"; sleep 2
}
#######################
#POST check Function
#######################
POST ()
{
LOGS=/tmp/${HOST}.post-fs-net-chk.${DATE}.log
FAILURE_LOGS=/tmp/${HOST}.post-fs-net-fail.log
[[ -f $LOGS ]] && cp -p $LOGS $LOGS_${DATE}
[[ -f $FAILURE_LOGS ]] && cp -p $FAILURE_LOGS $FAILURE_LOGS_${DATE}
[[ -d $log_dir/ ]] && IP_CON > $IP_AFTR

FILE_CHK ()
{
	if [ ! -r $1 ] > /dev/null
	then
		echo "\nFile $1 doesn't exist !!!" 
		echo "Precheck must be run before running post check" ; sleep 1
		return 1
	else
		$2
	fi
}

FS_MNT_CHK ()
{
	cat $FS_INFO | grep -vwE "tmpfs|devtmpfs"| sed '1d' | awk '{sub($5,"");print $0}' | while read LV GB_BLKS USED FREE MNT
	do
		df -h | awk '{print $NF}'| sed '1d' | grep -x $MNT > /dev/null
		if [ $? = 0 ] > /dev/null
		then
			df -h $MNT | grep -vwE "tmpfs|devtmpfs"| sed '1d' | awk '{sub($5,"");print $0}' | while read LV_N GB_BLKS_N USED_N FREE_N MNT_N
			do
				if [ $GB_BLKS != $GB_BLKS_N ] > /dev/null
				then
					echo "$AMBER Filesystem $MNT is mounted but has different size" ; sleep 2
					echo "BEFORE=${GB_BLKS}"
					echo "AFTER=${GB_BLKS_N}" ; sleep 2
				else
					if [ $LV = $LV_N ] > /dev/null
					then
						echo "$GREEN $MNT is MOUNTED" ; sleep 1
					else
						echo "$RED Mismatch in LV $LV_N and mount point $MNT_N, previous LV was $LV" ; sleep 2
						echo "BEFORE=$LV"
						echo "AFTER=$LV_N" 
					fi
				fi
		
			done
		else
			echo "$RED Filesystem $MNT is NOT mounted" ; sleep 1
		fi
	done
}

ROUTE_CHK ()
{
	netstat -nr | grep -E "[0-9]" | awk '{print $1"\t"$2"\t"$3"\t"$8}' > $ROUTE_AFT
	FAILURES=$(sdiff -s $ROUTE $ROUTE_AFT | awk '/|/ ; /</ ; />/ {print $0}' | wc -l)
	if [ $FAILURES -ge 1 ] > /dev/null
	then
		CHANGES=$(sdiff -s $ROUTE $ROUTE_AFT | grep "|" | wc -l)
		if [ $CHANGES -ge 1 ] > /dev/null
		then
			ROUT=$(sdiff -s $ROUTE $ROUTE_AFT | grep "|" | awk -F "|" '{print $2}' | awk '{print $2}')
			PREV_STAT=$(sdiff -s $ROUTE $ROUTE_AFT | grep "|" | awk -F "|" '{print $1}')
			CURR_STAT=$(sdiff -s $ROUTE $ROUTE_AFT | grep "|" | awk -F "|" '{print $2}')
			echo $AMBER $ROUT | tr "[\n]" "[ ]" ; print "route entries changed" 
			echo "\nPrevious route entries\n--------------------------------------------------"
			printf "%1s %8s %8s %8s\n%1s %8s %8s %8s\n" $PREV_STAT ; sleep 1
			echo "\nCurrent route entries\n--------------------------------------------------"
			printf "%1s %8s %8s %8s\n%1s %8s %8s %8s\n" $CURR_STAT ; sleep 1
		fi
		MISSING=$(sdiff -s $ROUTE $ROUTE_AFT | grep "<" | wc -l)
		if [ $MISSING -ge 1 ] > /dev/null
		then
			PREV_STAT=$(sdiff -s $ROUTE $ROUTE_AFT | grep "<" |sed 's/\<//')
			echo "\n$AMBER Route Missing since reboot\n--------------------------------------------------"
			printf "%1s %8s %8s %8s\n%1s %8s %8s %8s\n" $PREV_STAT ; sleep 1
		fi
		NEW_ROUTES=$(sdiff -s $ROUTE $ROUTE_AFT | grep ">" | wc -l)
		if [ $NEW_ROUTES -ge 1 ] > /dev/null
		then
			CURR_STAT=$(sdiff -s $ROUTE $ROUTE_AFT | grep ">" |sed 's/\>//')
			echo "\n$AMBER New Routes Available after reboot\n--------------------------------------------------"
			printf "%1s %8s %8s %8s\n%1s %8s %8s %8s\n" $CURR_STAT ; sleep 1
		fi
	else
		echo "$GREEN Route Validation" ; sleep 2
	fi
}

IP_CHECK ()
{
	cat $IP_INFO | while read INT IPADD NETMASK
	do
		if ( ifconfig $INT | grep -q $IPADD ) ; then
			ipchk=($(ifconfig $INT | grep -w $IPADD	| awk '{print $2,$4}'))
			if [ "$IPADD" = "${ipchk[0]}" -a "$NETMASK" = "${ipchk[1]}" ] ; then
				echo "$GREEN IP/NETMASK validation for $IPADD in $INT" ; sleep 1
			else
				echo "$RED IP/NETMASK validation failed for $IPADD in $INT" ; sleep 1
			fi
		else
			echo "$RED IP validation for $IPADD, not plumbed in interface $INT" ; sleep 1
		fi
	done
	echo "Checking Interface status" ; sleep 1
	for INTF in `ip -o link show | awk -F ': ' '{print $2}' | sed 's/lo//' | tr "[ ]" "[\n]" | sed '/^$/d'`
	do
		if [ "`ip -o link show $INTF | awk -F ': ' '{print $3}' | awk '{print $6,$7}'`" != "state UP" ] 
		then
			echo -e "$RED Interface $INTF status:  \e[1;31mDOWN\e[0m" ; sleep 1
		else
			echo -e "$GREEN Interface $INTF status: \e[1;32mUP\e[0m" ; sleep 1
		fi
	done
	
}

IP_CHK_AFTR ()
{
	if [ ! -s $IP_INFO ] > /dev/null
	then
		echo "\n$IP_INFO doesn't exits, precheck was not run"
		return 0
	else
		cat $IP_AFTR | awk '{print $1,$2}' | while read INT IPADD 
		do
			if ( ! cat $IP_INFO | grep -qw $IPADD ) ; then
				echo "$AMBER New IP $IPADD plumbed on $INT after reboot" ; sleep 1
			fi
		done
	fi
}
	
echo "==============================Validating FS mounts==============================" | tee -a $LOGS ; sleep 1
FILE_CHK $FS_INFO FS_MNT_CHK | tee -a $LOGS 

echo "==============================Validating Route==============================" | tee -a $LOGS ; sleep 1
FILE_CHK $ROUTE ROUTE_CHK | tee -a $LOGS
echo "==============================Validating IP Address==============================" | tee -a $LOGS; sleep 1 
FILE_CHK $IP_INFO IP_CHECK | tee -a $LOGS
FILE_CHK $IP_AFTR IP_CHK_AFTR | tee -a $LOGS
echo $(date +%T) - Postcheck Completes | tee -a $LOGS; echo
echo ; echo "--> Logs stored at $LOGS" | tee -a $LOGS
sleep 2
echo ;echo
cat $LOGS | egrep "FAILED|ERROR" > /dev/null
	if [ $? = 0 ] > /dev/null
	then
		echo -e "FAILED Post check,Please check the log file and fix the issue..!" | tee -a $LOGS $FAILURE_LOGS ; sleep 1
	else
		if ( grep -q WARNING $LOGS) ; then
			echo -e "PASSED Post check Validation with WARNINGS" | tee -a $LOGS ; sleep 1
		else
			if ( grep -q PASSED $LOGS ) ; then
				echo -e "PASSED Post check Validation" | tee -a $LOGS ; sleep 1
			else
				echo -e "FAILED Post check Validation" | tee -a $LOGS ; sleep 1
			fi		
		fi
	fi
}

case $1 in
  pre|Pre|PRE)
  PRE ;;

  post|Post|POST)
  POST ;;

  *)
    Usage ;;
esac

#EOF
