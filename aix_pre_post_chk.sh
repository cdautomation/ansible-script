#!/bin/ksh
#Name    :  aix_pre_post_chk.ksh
#Owner	 :  root
#Date	 :  
#Version :  2
#Author  :  Rejmay Antony
#Permission : 750
#Intended for AIX only
#
#Collects and verifies System details against the logs saved in /tmp
#
#This script must be executed before starting any activity in the server such
#as taking mksysb or shutting down cluster services like HACMP/GPFS
# 
#	USAGE :
#		Pass the required Arguments pre|Post|PRE (Before Reboot) OR post|Post|POST (After Reboot)
#		pre|Pre|PRE - Collects systems details before reboot
#		post|Post|POST - Compares and reports for FAILURE if any post reboot.
#
#Log file /tmp/<hostname>.prechk_*.log contains pre check logs 
#which can be used for reference post reboot.
#**********************
#HOST check
#**********************
if [ $(uname) != "AIX" ] > /dev/null
	then
		echo "\nNot an AIX machine, Aborting the program!!!" ; sleep 2
		exit
fi

#**********************
#User check
#**********************
if [ $(whoami) != root ] > /dev/null
	then
		echo "Permission Denied !!! Try using sudo to execute this script or switch to root"
	exit 1
fi

#****************************************************************************************
#Defining Global Variables
#****************************************************************************************

 MIN_OS=610007					#For DISK_DETAILS function (lspv -u won't work in version less than 6.1 TL7)
 DATE=$(date +%m.%d.%Y)
 HOST=$(hostname)
 BOLD=$(tput smso)
 UNBOLD=$(tput rmso)
 UID=$(who -m|awk '{ print $1 }')
 GREEN=$(echo "\033[32mPASSED\033[0m")
 AMBER=$(echo "\033[33mWARNING\033[0m")
 RED=$(echo "\033[31mFAILED\033[0m")
 NAME=$(lsuser -a gecos $UID | awk -F "=" '{print $NF}')
 OSLEVEL=$(oslevel | awk '{FS=OFS="."} {print $1,$2}')
 log_dir=/tmp/precollect
 HOST_FILE=$log_dir/host_name
 FS_INFO=$log_dir/fs_list.log
 ROUTE=$log_dir/route_list.log
 ROUTE_AFT=$log_dir/route-aft_list.log
 DATE_INFO=$log_dir/date.log
 IP_INFO=$log_dir/ip_list.log
 IP_AFTR=$log_dir/ip_after_list.log
 ACTIV_VG=$log_dir/vg.list
 ADAPTR=$log_dir/adapters.list
 PROC_BFR=$log_dir/proc.list
 PROC_AFTR=$log_dir/proc.aftr
 PRE_DISK=$log_dir/pre_disk.list
 POST_DISK=$log_dir/post_disk.list
 DISK_PATH_BEFORE=$log_dir/pre_disk_path.list
 DISK_PATH_AFTER=$log_dir/post_disk_path.list
 ADAPT_BEFORE=$log_dir/adapters_before.list
 ADAPT_AFTER=$log_dir/adapters_after.list
 
 #****************************************************************************************
 #	Defining Global Functions
 #****************************************************************************************
 
 Usage ()
{
	echo "$0: option requires an argument pre OR post !!!" ; SLEEP
	echo "\nUsage:"
	echo "\t$0 pre | post"
	echo "\tpre   -   collects system details before reboot/any activity"
	echo "\tpost  -   validates system integrity against the precheck log, fails if pre was not run\n"
	exit
}

SLEEP ()
{
	perl -e 'select(undef,undef,undef,.5)'
}

SLEEP_LESS ()
{
	perl -e 'select(undef,undef,undef,.3)'
}

IP_CON ()
{
	ifconfig -l | sed 's/lo0//' | tr "[ ]" "[\n]" | sed '/^$/d' | while read ENT
		do
			netmask=$(lsattr -El $ENT -a netmask -F value)
			ifconfig ${ENT} | grep -w inet | awk '{print $2,$4}' | sed "s/^/$ENT /" 
		done
}

dots ()
{
	while :; do
		printf "."
		SLEEP
	done &
}

EXEC_BY ()
{
	[[ -s $LOGS ]] && cp $LOGS ${LOGS}_bkp
	echo "\n--------Script Executed by--------" > $LOGS
	echo "UID  : $UID" >> $LOGS
	echo "Name : $NAME" >> $LOGS
	echo "Time : `date +%T-%m/%d/%y`" >> $LOGS
	echo "----------------------------------" >> $LOGS
}

#****************************************************************************************
# PRE CHECK Function starts
#****************************************************************************************
#This section of the script covers the prechecks performed in the system 
#Displays outputs in the foreground and logs in /tmp

PRE_CHK ()
{
#PRE Check function begin
#*************************************************************************************
#                               Defining Variables                                   *
#*************************************************************************************

 LOGS=/tmp/${HOST}.prechk_${DATE}.log
 MODEL=$(uname -M | cut -d "," -f2)
 MPIO_CNT=$(lslpp -l |egrep "Dynamic|sddpcm|EMCpower" | wc -l)
 MPIO=$(lslpp -L | egrep "Hitachi.aix|Dynamic|sddpcm|EMCpower" | sed 's/for//' | awk '{OFS="_"} {print $5,$6,$7}')

#*************************************************************************************
#
#------------------------------------------
#Calling Precheck twice on the same day ?
#------------------------------------------
if [ -a "$LOGS" ]
    then
     echo ; istat $LOGS | grep modified
     echo "$AMBER Precheck was already run today, run it again ? Overwrites the existing log file !!!"
      while :;
		do
			echo "\"y\" OR \"n\": \c"
			read ANS
				case $ANS in
					y|Y|yes|YES) echo "\nContinue...."; sleep 1 ; break ;;
					n|N|no|NO) echo "\nExiting !!!\n" ; exit ;;
					*) echo "\nPlease type Yes|y or No|n"
					continue ;;
				esac
		done
fi

#------------------------------------------
#Defining Functions under PRE_CHK function
#------------------------------------------

EXEC_CMD ()
{
  cmd=$*

  echo ========================================================================
  echo Command : $cmd
  echo ========================================================================

  $cmd
  echo
}

EXEC_BY					####Capturing UID using global function

#------------------------------------------
#Collecting VIO specific details
#------------------------------------------

VIO_CHECK ()
{
# VIO check function begin
#Collecting VIO server details 
 if ( lslpp -L | grep -q ios.cli.rte )
	then
		clear
		echo "\n********************************************************************"
		echo "          !!! ATTENTION !!! This is a VIO SERVER"
		echo "********************************************************************"
		echo ; sleep 2
		IOSCMD=/usr/ios/cli/ioscli

		if ( lsdev -Ccadapter | grep -q "Virtual FC Server Adapter" ) ; then
			NPIV=yes
		fi

		echo [$(date +%T)] Collecting VIOS details !!!
	CMD="$IOSCMD ioslevel"
	EXEC_CMD $CMD
	CMD="$IOSCMD lsmap -all -net"
	EXEC_CMD $CMD

		if [ "$NPIV" = yes ] >> /dev/null
		then
			CMD="$IOSCMD lsmap -all -npiv"
			EXEC_CMD $CMD
			CMD="$IOSCMD lsmap -all -field name physloc clntname fc status vfcclient -fmt : -npiv"
			EXEC_CMD $CMD
			CMD="$IOSCMD lsnports"
			EXEC_CMD $CMD
		fi
	VSCSI=$(lsdev | grep "Virtual SCSI Server Adapter" | head | wc -l)
		if [ $VSCSI -ge 1 ] ; then
			CMD="$IOSCMD lsmap -all"
			EXEC_CMD $CMD
		fi


	$IOSCMD lsmap -all -net -fmt : | grep Available | awk -F ":" '{print $3,$4}' | sort -u | while read SEA REAL
		do
			if [[ "$SEA" != "" && "$REAL" != "" ]] >> /dev/null
			then
				echo ; echo
				echo SEA $SEA details
				CMD="$IOSCMD entstat -all $SEA" 
				EXEC_CMD $CMD
				CMD="lsattr -El $SEA" 
				EXEC_CMD $CMD
				echo ; echo
				echo REAL adapter $REAL of SEA $SEA details
				CMD="lsattr -El $REAL"
				EXEC_CMD $CMD
				echo Physical Adapters attributes of Real Adapter $REAL 
				for PHY_ADAP in `lsattr -El $REAL -a adapter_names,backup_adapter -F value | grep -v NONE | tr "[,]" "[ ]"`
				do
					CMD="lsattr -El $PHY_ADAP"
					EXEC_CMD $CMD
				done
				entstat -d $SEA | grep -E "VLAN ID:|VLAN Tag IDs:" | awk -F ":" '{print $2}'|grep -E "[0-9]" > $log_dir/SEA_$SEA
			fi
		done

	echo
	echo [$(date +%T)] END of VIOS details !!!
	
fi
# VIO check function ends
}

MPIO_CMD ()
{
#Multipath Checking function begin
for MPIO_TYPE in $MPIO
do
	if [ "$MPIO_TYPE" = IBM_SDD_PCM ] > /dev/null
	then 
		CMD="pcmpath query adapter"
		EXEC_CMD $CMD
		CMD="pcmpath query wwpn"
		EXEC_CMD $CMD
		CMD="pcmpath query device"
		EXEC_CMD $CMD
		CMD="pcmpath query version"
		EXEC_CMD $CMD
	fi
done
#Multipath Checking function ends
}

EXEC_MPIO ()
{
#Exicuting Multipath checking function begin
if [ "$MPIO_CNT" -ge 1 ] > /dev/null
then
	MPIO_CMD
fi
#Exicuting Multipath checking function ends
}

DISK_DETAILS ()
{
#Collecting disk details function begin
	LSPV_OPT ()
	{
		CURRENT_OS=$(oslevel -r | tr -d "-")
		if [ "$CURRENT_OS" -ge $MIN_OS ] 
		then
			if ( lspv -u | grep -w $disks | awk '{print $5}' | grep -q IBM ) ; then
				lspv -u | grep -w $disks | awk '{print $5}' | cut -c "10-41" | read LUN
				SAN_TYP=vscsi-IBM
			fi
		fi
	}

echo "\nCollecting Disk details\n" 
if ( ! lspv | grep -q hdiskpower ) ; then
	echo $BOLD ; printf "%5s %16s %19s %16s %30s %15s\n" DISK PVID VG SIZE-MB LUN SAN-TYPE; echo $UNBOLD
	lspv | awk '{print $1}' | while read disks
	do
		lspv | grep -w $disks | awk '{print $1,$2,$3}' | read VG
		bootinfo -s $disks | read SIZE
		if ( lsattr -El $disks | grep -qw PCM ) ; then
		DISK_MAKE=$(lsattr -El $disks -a PCM -F value|awk -F"/" '{print $3}')
			if [ "$DISK_MAKE" = sddpcm ] > /dev/null
			then
				lscfg -vl $disks | grep Serial | awk -F"." '{print $NF}' | read LUN
				lsdev -Ccdisk | grep -w $disks | awk 'OFS="-" {print $(NF-2),$(NF-1),$NF}'| sed 's/MPIO/IBM/' | read SAN_TYP
			elif [ "$DISK_MAKE" = fcpother ] > /dev/null
			then
				lscfg -vl $disks | grep Serial | awk -F"." '{print $NF}' | read LUN
				lsdev -Ccdisk | grep -w $disks | awk 'OFS="-" {print $(NF-2),$(NF-1),$NF}'| sed 's/MPIO/IBM/' | read SAN_TYP
			elif [ "$DISK_MAKE" = scsiscsd ] > /dev/null
			then
				LUN=local
				lsdev -Ccdisk | grep -w $disks | awk 'OFS="-" {print $(NF-2),$(NF-1)}' | read SAN_TYP
			elif [ "$DISK_MAKE" = vscsi ] > /dev/null
			then
				LSPV_OPT
			fi
		
		fi
		printf "%1s %20s %17s %12s %32s %15s\n" $VG $SIZE $LUN $SAN_TYP
	done

fi
#Collecting disk details function ends
}	
	
FCS_INFO ()
{
#Collecting FC adapter details function begin
	FCS_CNT=$(lsdev | grep fcs | wc -l)
	if [ "$FCS_CNT" -ge 1 ] > /dev/null
	then
		lsdev | grep fcs | grep Available | awk '{print $1}' | while read FCS
		do
			CMD="lsattr -El $FCS"
			EXEC_CMD $CMD
			FSCSI=$(lsdev -p $FCS | grep Available | awk '{print $1}' | grep fscsi)
			CMD="lsattr -El $FSCSI"
			EXEC_CMD $CMD
		done
	fi
#Collecting FC adapter details function ends
}

GEN_INFO ()
{
#Collecting general information function
	[[ ! -d $log_dir/ ]] && mkdir -p $log_dir 
	echo
	VIO_CHECK
	echo
	echo [$(date +%T)] Collecting System details !!!

	CMD="uptime"
	EXEC_CMD $CMD

	CMD="oslevel -s"
	EXEC_CMD $CMD
  
	CMD="ssh -V"
	EXEC_CMD $CMD

	CMD="lsattr -El sys0"
	EXEC_CMD $CMD

	CMD="lparstat -i"
	EXEC_CMD $CMD

	CMD="lparstat -l"
	EXEC_CMD $CMD

	CMD="prtconf"
	EXEC_CMD $CMD

	CMD="date"
	EXEC_CMD $CMD
  
	CMD="grep -w TZ /etc/environment"
	EXEC_CMD $CMD  

	CMD="getconf KERNEL_BITMODE"
	EXEC_CMD $CMD

	CMD="getconf REAL_MEMORY"
	EXEC_CMD $CMD

	CMD="getconf BOOT_DEVICE"
	EXEC_CMD $CMD

	CMD="bootlist -om normal"
	EXEC_CMD $CMD

	CMD="smtctl"
	EXEC_CMD $CMD

	echo ========================================================================
	echo "Command : lsdev -S Available | grep proc"
	echo ========================================================================
	lsdev -S Available | grep proc
	echo

	CMD="lsdev -Ccif"
	EXEC_CMD $CMD

	CMD="lsdev -Ccadapter"
	EXEC_CMD $CMD

	CMD="lsdev -Ccdisk"
	EXEC_CMD $CMD

	CMD="lsitab -a"
	EXEC_CMD $CMD

	CMD="ps -eaf"
	EXEC_CMD $CMD

	CMD="lppchk -v"
	EXEC_CMD $CMD

	CMD="lsps -a"
	EXEC_CMD $CMD

	CMD="sysdumpdev -l"
	EXEC_CMD $CMD

	CMD="sysdumpdev -L"
	EXEC_CMD $CMD

	CMD="vmstat -v"
	EXEC_CMD $CMD

	CMD="netstat -nr"
	EXEC_CMD $CMD

	CMD="netstat -in"
	EXEC_CMD $CMD

	CMD="lsattr -El inet0"
	EXEC_CMD $CMD

	CMD="ifconfig -a"
	EXEC_CMD $CMD
  
	CMD="rpcinfo -p"
	EXEC_CMD $CMD
  
	for ENT in `IP_CON | awk '{print $1}' | sort -u`
	do
		echo Listing Attributes of $ENT
		CMD="lsattr -El $ENT"
		EXEC_CMD $CMD
	done  

	CMD="no -x"
	EXEC_CMD $CMD
  
	CMD="vmo -x"
	EXEC_CMD $CMD
  
	CMD="exportfs"
	EXEC_CMD $CMD
  
	CMD="lsnfsmnt"
	EXEC_CMD $CMD
  
	CMD="lspv"
	EXEC_CMD $CMD

	CMD="lspath -F "name:parent:status:connection""
	EXEC_CMD $CMD  
	
	CMD="df -gt"
	EXEC_CMD $CMD

	echo ========================================================================
	echo "Command : df -gt | wc -l"
	echo ========================================================================
	df -gt | wc -l
	echo

	CMD="lsvg"
	EXEC_CMD $CMD

	CMD="lsvg -o"
	EXEC_CMD $CMD

	echo ========================================================================
	echo "Command : lsvg -o | wc -l"
	echo ========================================================================
	lsvg -o | wc -l
	echo

	echo ========================================================================
	echo "Command : lsvg | wc -l"
	echo ========================================================================
	lsvg | wc -l
	echo

	echo ========================================================================
	echo "Command : lsvg -o | lsvg -il"
	echo ========================================================================
	lsvg -o | lsvg -il
	echo

	CMD="lsvg -p `lsvg -o`"
	EXEC_CMD $CMD
  
	CMD="lsvg `lsvg -o`"
	EXEC_CMD $CMD

	echo ========================================================================
	echo "Command : lsvg -o | lsvg -il | grep -i close"
	echo ========================================================================
	lsvg -o | lsvg -il | grep -i close
	echo

	echo ========================================================================
	echo "Command : lssrc -a | grep active"
	echo ========================================================================
	lssrc -a | grep active
	echo

	CMD="lsfs"
	EXEC_CMD $CMD

	CMD="errpt -s `date +%m%d0000%y`"
	EXEC_CMD $CMD
#Collecting general information function ends	
}

HACMP_INFO ()
{
#HACMP INFO function begin
	if ( ! lssrc -a | grep -qw clstrmgrES ) ; then
		echo
		echo $BOLD;echo "Not a HACMP Node !!!";echo $UNBOLD
		echo
	else
		if [ -d /usr/es/sbin/cluster/utilities/ ] > /dev/null
		then
			echo
			echo Listing HACMP related Info
			echo
			CMD="lssrc -ls clstrmgrES"
			EXEC_CMD $CMD
			export PATH=$PATH:/usr/es/sbin/cluster/utilities/
			CMD="cllsnode"
			EXEC_CMD $CMD
			CMD="clshowres"
			EXEC_CMD $CMD
			CMD="clRGinfo"
			EXEC_CMD $CMD
			CMD="cltopinfo"
			EXEC_CMD $CMD
			CMD="cllsfs"
			EXEC_CMD $CMD
			CMD="cllsvg"
			EXEC_CMD $CMD
			CMD="cllsif"
			EXEC_CMD $CMD
		fi    
	fi
#HACMP INFO function ends
}

GPFS_INFO ()
{
#Collecting GPFS related info function begin

	if ( ! lslpp -l | grep -qw gpfs ) ; then
		echo $BOLD;echo Not a GPFS Node !!!;echo $UNBOLD
	else
		if [ -d /usr/lpp/mmfs/bin ] > /dev/null
		then
			echo
			echo Collecting GPFS details  ; sleep 1
			echo
			export PATH=$PATH:/usr/lpp/mmfs/bin
			CMD="mmlscluster"
			EXEC_CMD $CMD
			CMD="mmlsconfig"
			EXEC_CMD $CMD
			CMD="mmlsnsd"
			EXEC_CMD $CMD
			CMD="mmlspv"
			EXEC_CMD $CMD
			CMD="mmlsnode"
			EXEC_CMD $CMD
			CMD="mmlsmgr"
			EXEC_CMD $CMD
			CMD="mmlsmount all"
			EXEC_CMD $CMD
			CMD="cat /var/mmfs/gen/mmfsNodeData"
			EXEC_CMD $CMD
			CMD="mmgetstate -aL"
			EXEC_CMD $CMD
		fi
	fi
#Collecting GPFS related info function ends
}

MAIN ()
{
#Starting MAIN Function

	GEN_INFO						#Collecting general information 
	FCS_INFO						#FCS attribute function
	EXEC_MPIO						#MPIO information
	GPFS_INFO					#Collecting GPFS Info
	HACMP_INFO					#Collecting HACMP Info
        DISK_DETAILS                                    #Collection disk information
	echo ; echo "--> Logs stored at $LOGS"

#MAIN Function Ends
}	

#--------------------------------
# Calling Pre-Check MAIN Function
#--------------------------------
MAIN | tee -a $LOGS
sleep 2	
cp $LOGS /home/ansuer/prepatch.txt
#--------------------------------

#------------------------------------
#Collecting data's for post check !!!
#------------------------------------
echo "$LOGS" > $log_dir/precheck_log.file

for FILE_LIST in $FS_INFO $ROUTE $DATE_INFO $IP_INFO $IP_AFTR $ACTIV_VG $ADAPTR $PRE_DISK $POST_DISK $DISK_PATH_BEFORE $DISK_PATH_AFTER $ADAPT_BEFORE $ADAPT_AFTER
	do
		if [ -s $FILE_LIST ] > /dev/null
		then
			if [ ! -f ${FILE_LIST}_${DATE} ] > /dev/null
		then
			cp -p $FILE_LIST ${FILE_LIST}_${DATE}
			fi
		fi
	done
#-----------------------
#Generating Output Files
#-----------------------
df -gt | grep -vwE "/mnt|/nim_backup|/sds" > $FS_INFO
echo `date` `date '+%z'` > $DATE_INFO
lsvg -o > $ACTIV_VG
echo $HOST > $HOST_FILE
netstat -nr | grep -E "[0-9]" | grep -vE "^Route|^:" | awk '{print $1"\t"$2"\t"$3"\t"$6}' > $ROUTE
lsdev -Ccadapter | grep Available | grep -vE "PKCS|EtherChannel|Shared Ethernet|USB|PCI-X" | awk '{print "lscfg -l",$1}' | ksh > $ADAPTR

for int in $(ifconfig -l | sed -e 's/lo0//' -e 's/et[0-9]//g') ; do
 entstat -d $int | grep -E "VLAN ID:|VLAN Tag IDs:" | awk -F ":" '{print $2}'|grep -E "[0-9]" > $log_dir/vlan_$int
done
IP_CON > $IP_INFO
echo
echo [$(date +%T)] Precheck Completes ; echo

#PRECHECK Function Ends	
}

#****************************************************************************************
# POST CHECK Function starts
#****************************************************************************************

POST_CHK ()
{
#
#This section of the script covers the post checks performed in the system 
#Post check depends upon the outputs collected during precheck, the script will exit 
#if the precheck was not run
#
#*************************************************************************************
#                               Defining Variables                                   *
#*************************************************************************************
 LOGS=/tmp/${HOST}.post.chk_${DATE}.log
 FAILURE_LOGS=$log_dir/failures.log
 GPFS=$(lslpp -L | grep -w  gpfs.base | wc -l)
 HACMP=$(lslpp -L |grep -w cluster.es.server.rte | awk '{print $1}')

if [ -s $log_dir/precheck_log.file ] > /dev/null
then
	PRE_LOGS=$(cat $log_dir/precheck_log.file)
else
	echo $BOLD
	echo "\n!!! Pre check must be run before running Post check !!!" ; echo $UNBOLD ; sleep 1
	echo $BOLD ; echo "Try $0 pre OR $0 PRE to run Pre check" ; echo $UNBOLD
	sleep 2 ; exit 0
fi

EXEC_BY					####Capturing UID 

#------------------------------------------
#Defining Functions under POST_CHK function
#------------------------------------------

MAIN_POST ()
{
[[ -s $FAILURE_LOGS ]] && cp /dev/null $FAILURE_LOGS

[[ -d $log_dir/ ]] && IP_CON > $IP_AFTR					#Collecting currently available IP details

HOST_CHK ()
{
	if [ -s $HOST_FILE ] > /dev/null
	then
		HOST_BFR=$(cat $HOST_FILE)
		if [ $HOST != $HOST_BFR ] > /dev/null
		then
			echo "\n$RED Mismatch in hostname, before reboot $HOST_BFR and after reboot $HOST" ; SLEEP
		fi
	else
		echo "\n$HOST_FILE doesn't exist to verify hostname" ; SLEEP
	fi
}

GPFS_CHK ()
{
	if [ "$GPFS" = 1 ] > /dev/null
	then
		if ( ! ps -eaf | grep -v grep | grep -qw mmfs ) ; then
			echo "\n$AMBER GPFS services are not running, this script may produce undesireable results !!!" ; sleep 2
		fi
	fi
}

HACMP_CHK ()
{
	if ( lslpp -L | grep -q cluster.es.server.rte ) ; then
		if [ "$HACMP" = cluster.es.server.rte ] > /dev/null
		then
			/usr/sbin/cluster/utilities/get_local_nodename 1>>/dev/null 2>> /dev/null
			if [ $? = 0 ] > /dev/null
			then
				HACMP_STAT=$(lssrc -ls clstrmgrES | awk '$2 == "state:" {print $NF}')
				HACMP_PREV_STAT=$(grep -p "lssrc -ls clstrmgrES" $PRE_LOGS | awk -F ":" '/Current state/ {print $2}')
				if [ "$HACMP_STAT" = "" ] 
				then
					echo "\nERROR : HACMP services are not active, please rerun this script after starting the services"
					exit 1
				elif [ "$HACMP_STAT" != ST_STABLE ] > /dev/null
				then
					if [ "$HACMP_STAT" != $HACMP_PREV_STAT ] 
					then
						echo "\nERROR : HACMP services are active but they are not STABLE yet, rerun POST check after the services are STABLE"
						exit 1
					fi
				else
					export PATH=$PATH:/usr/es/sbin/cluster/utilities/
					set -A OFFLINE_RG $(clRGinfo -s | grep $HOST | grep -E "OFFLINE|UNMANAGED" | awk -F ":" '{print $1}')
					for RG in ${OFFLINE_RG[*]} ; do
						[ -f $log_dir/${RG}_fs.list ] && cp /dev/null $log_dir/${RG}_fs.list 
						cllsfs -g $RG 1>> $log_dir/${RG}_fs.list 2>/dev/null
					done
				fi
			fi
		fi
	fi
}

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

#--------------------
#Time Zone Validation
#--------------------
TZ_CHK ()
{
	cat $DATE_INFO | awk '{sub ($1,"") ; print $0}' | while read DAT MONTH TIME YEAR TZN
	do
		echo `date` `date '+%z'` | awk '{sub ($1,"") ; print $0}' | while read DAT_N MONTH_N TIME_N YEAR_N TZN_N  
		do
			if [ "$TZN" = "$TZN_N" -a "$YEAR" = "$YEAR_N" ] > /dev/null
			then
				if [ "$MONTH" = "$MONTH_N" ] > /dev/null
				then
					DAYS=`expr $DAT_N - $DAT`
					if [ "$DAYS" -ge 2 ] > /dev/null
					then
						echo "\n$AMBER Precheck script outputs are more than 2 days old " ; sleep 2
					else
						echo "\n$GREEN TIMEZONE validation" ; SLEEP
					fi
				else
					echo "\n$AMBER Precheck script was executed in the month of $MONTH" ; sleep 2
				fi
			else
				echo "\n$RED TIMEZONE validation" 
				echo "Old TZ/Year=${TZN}\t${YEAR}"
				echo "NEW TZ/Year=${TZN_N}\t${YEAR_N}"
				echo "\n$RED TIMEZONE...fix this and rerun the script\n" ; sleep 1
			fi
		done
	done 
}

#Mount Order Check
MNT_CHECK ()
{
	df -gt | sed 1d | awk '{print $NF}' | uniq | while read FS
	do
	COUNT=$(df -g | grep -w $FS | wc -l)
		if [ $COUNT -ne 1 ] > /dev/null
		then
			FS_CHK=$(df -gt | grep -w $FS | awk '!a[$NF]++' | nl | awk -v NEW=$FS '{ if ($NF == NEW) print $1}')
			df -gt | grep -w $FS | awk '{print $NF}' | nl | while read CNT MNT_FS
			do
				if [ $FS_CHK -gt $CNT ] > /dev/null
				then
					echo $RED mount order is incorrect for $MNT_FS;
				fi
			done
		fi
	done
}
#checking FS mount order in /etc/filesystems
LSFS_ORDER ()
{
	lsfs | egrep -vw "$EXCLUDE" | awk '{print $3}' | while read LSFS
	do
		COUNT=$(lsfs | awk '{print $3}' |grep $LSFS | wc -l)
		if [ $COUNT -ne 1 ] > /dev/null
		then
			LSFS_CHK=$(lsfs | grep -v "nfs" | grep -w $LSFS | nl | awk '!a[$4]++' | awk -v NEW_FS=$LSFS '{if ($4 == NEW_FS) print $1}')
			lsfs | awk '{print $3}' | grep -w $LSFS | nl | while read CNT_FS MNT_LSFS
			do
				if [ "$LSFS_CHK" != "" ] > /dev/null
				then
					if [ $LSFS_CHK -gt $CNT_FS ] > /dev/null
					then
						echo $AMBER mount order incorrect in /etc/filesystems for $MNT_LSFS ; SLEEP
					fi
				fi
			done
		fi
	done
}

#FS size Diff check, LV and MNT mismatch check
FS_MNT_CHK ()
{
	cat $FS_INFO | grep -vw "/aha" | sed '1d' | awk '{sub($5,"");print $0}' | while read LV GB_BLKS USED FREE MNT
	do
		df -gt | awk '{print $NF}'| grep -x $MNT > /dev/null
		if [ $? = 0 ] > /dev/null
		then
			df -gt $MNT | grep -v "/aha" | awk -v FSYS=$MNT '$NF==FSYS {sub($5,"");print $0}' | while read LV_N GB_BLKS_N USED_N FREE_N MNT_N
			do
				if [ $GB_BLKS != $GB_BLKS_N ] > /dev/null
				then
					echo "$AMBER Filesystem $MNT is mounted but has different size" ; SLEEP
					echo "BEFORE=${GB_BLKS}GB"
					echo "AFTER=${GB_BLKS_N}GB" ; SLEEP
				else
					if [ $LV = $LV_N ] > /dev/null
					then
						echo "$GREEN $MNT is MOUNTED" ; SLEEP_LESS
					else
						echo "$RED Mismatch in LV $LV_N and mount point $MNT_N, previous LV was $LV" ; SLEEP
						echo "BEFORE=$LV"
						echo "AFTER=$LV_N" 
					fi
				fi
		
			done
		else
			echo "$RED Filesystem $MNT is NOT mounted" ; SLEEP
		fi
	done
}

#Checking mounted FS with /etc/filesystems and auto mount option.
LSFS_MNT_CHK ()
{
	if [ "$EXCLUDE" = "" ] > /dev/null
	then
		LSFS=$(lsfs | sed 1d | awk '{print $3}' | grep -vE "bos_inst|cdrom|aha" )
	else
		LSFS=$(lsfs | sed 1d | grep -vEw "$EXCLUDE|bos_inst|cdrom|aha|aha0" | awk '{print $3}')
	fi

	for MNT_LSFS in $LSFS
	do
		df -gt | awk '{print $NF}' | grep -x $MNT_LSFS > /dev/null
		if [ $? != 0 ] > /dev/null
		then
			echo "$AMBER entry available in /etc/filesystems but NOT mounted $MNT_LSFS" ; SLEEP_LESS 
		fi
	done

	for MNT_LS in $LSFS ; do
		lsfs | awk  '{print $3,$(NF-1)}' | sed 1d | while read MNTS OPTS
		do
			if [ $MNT_LS = $MNTS -a $OPTS = no ] 
			then
				echo "$AMBER Automount is \033[31mno\033[0m for $MNT_LS" ; SLEEP_LESS
			fi
		done
	done  
}

#Calling LSFS_MNT
LSFS_MNT ()
{
	if [ ${#OFFLINE_RG[*]} -ge 1 ] > /dev/null
	then
		clRGinfo
		echo "RG ${OFFLINE_RG[*]} is OFFLINE in this node, excluding cluster filesystems" ; sleep 1
		for RG in ${OFFLINE_RG[*]}
		do
			[[ -s $log_dir/${RG}_fs.list ]] && RG_FS=$(cat $log_dir/${RG}_fs.list) && EXCLUDE=$(echo $RG_FS | tr "[ ]" "[|]")
			cat $log_dir/${RG}_fs.list |sed "s/^/EXCLUDED mount validation for /"
		done
		LSFS_MNT_CHK
	else
		LSFS_MNT_CHK
	fi
#---------------------------------------------------------------------
#FS entry check in /etc/filesystems
	df -gt | awk '{print $NF}' | sed 1d | grep -vwE "/mnt|cdrom|aha|aha0"  | while read MNTS
	do
		if ( ! cat /etc/filesystems | grep -q "${MNTS}:" ) ; then
		echo "$AMBER $MNTS is MOUNTED but no entries available in /etc/filesystems"
		fi
	done
#---------------------------------------------------------------------
#LV's with invalid FS
	if ( lsvg -l `lsvg -o ` | grep -i closed | awk '!/boot/ && !/(jfs|jfs2)log/ && !/sysdump/' | grep -q closed ) ; then
		echo "$AMBER LV's with invalid FS or missing entries in /etc/filesystems"
		lsvg -l `lsvg -o ` | grep -i closed | awk '!/boot/ && !/(jfs|jfs2)log/ && !/sysdump/' | sed "s/^/$AMBER /"
	fi
}

#Route entry check
ROUTE_CHK ()
{
	netstat -nr | grep -E "[0-9]" | grep -vE "^Route|^:" | awk '{print $1"\t"$2"\t"$3"\t"$6}' > $ROUTE_AFT
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
			printf "%1s %8s %8s %8s\n%1s %8s %8s %8s\n" $CURR_STAT ; sleep  1
		fi
	else
		echo "$GREEN Route Validation" ; SLEEP
	fi
}

#IP Address and interface status Verification
IP_CHECK ()
{
	cat $IP_INFO | while read INT IPADD NETMASK
	do
		if ( ifconfig $INT | grep -q $IPADD ) ; then
			set -A ipchk $(ifconfig $INT | grep -w $IPADD	| awk '{print $2,$4}')
			if [ "$IPADD" = "${ipchk[0]}" -a "$NETMASK" = "${ipchk[1]}" ] ; then
				echo "$GREEN IP/NETMASK validation for $IPADD in $INT" ; SLEEP
			else
				echo "$RED IP/NETMASK validation failed for $IPADD in $INT" ; SLEEP
			fi
		else
			echo "$RED IP validation for $IPADD, not plumbed in interface $INT" ; SLEEP
		fi
	done
	echo "\nChecking Interface state" ; SLEEP
	for INT_DOWN in `ifconfig -ld`
	do
		if [ "$INT_DOWN" != "" ] 
		then
			echo "$RED Interface $INT_DOWN status: \033[31mDOWN\033[0m" ; SLEEP
		fi
	done
	for INT_UP in `ifconfig -lu`
	do
		if [ "$INT_UP" != "" ] 
		then
			echo "$GREEN Interface $INT_UP status: \033[32mUP\033[0m" ; SLEEP_LESS
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
				echo "$AMBER New IP $IPADD plumbed on $INT after reboot" ; SLEEP
			fi
		done
	fi
}

#Compare entries of lparstat -i
LPARSTAT ()
{
	cat $PRE_LOGS | grep -p "lparstat -i"| sed '1,3d' | awk -F: '{gsub (/ /,"-",$1) ; print $1,$2}' | while read VAR VALUE
	do
		lparstat -i | awk -F ":" '{gsub(/ /,"-",$1) ; print $1,$2}' | grep "$VAR" | read NEW_VAR NEW_VALUE
		if [  "$VAR" = "$NEW_VAR" ] > /dev/null
		then
			if [ "$VALUE" != "$NEW_VALUE" ] > /dev/null
			then
				echo "\n$AMBER LPARSTAT Parameter value changed for ${VAR}" |  tr "[-]" "[ ]" 
				echo "BEFORE \t ${VAR} ${VALUE}"
				echo "AFTER \t ${NEW_VAR} ${NEW_VALUE}" ; SLEEP	
			fi
		fi
	done
}

#Boot disk validation
BOOT_DEVICE ()
{
	cat $PRE_LOGS | grep -p "bootlist -om" | sed 1,3d |awk '{print $1}' | sort -u | sed '/^$/d' | while read BOOT_DISK
	do
		if ( bootlist -om normal | grep -qw $BOOT_DISK ) ; then
			echo "$GREEN Boot DISK verification for $BOOT_DISK" ; SLEEP
		else
			echo "\n$AMBER Boot DISK verification for $BOOT_DISK"
			echo "Current Bootlists\n==================================="
			bootlist -om normal
			echo "\nPrevious Bootlists\n==================================="
			cat $PRE_LOGS | grep -p "bootlist -om" | sed 1,3d
		fi
	done
}

#Validating Adapters
ADAPTER_CHK_V5 ()
{
	cat $ADAPTR | awk '{print $1,$2}' | while read ADAPTER LOC
	do
		if ( lscfg | grep -qw $ADAPTER ) ; then
			lscfg -l $ADAPTER | awk '{print $2}' | while read LOC_COD
			do
				if [ "$LOC" != "$LOC_COD" ] >> /dev/null
				then
					echo "\n$AMBER Adapter Location code changed from $LOC to $LOC_NEW against the Location code $LOC"
				fi
			done
		else
			echo "\n$AMBER Adapter $ADAPTER with Location code $LOC NOT found"
			if ( lscfg | grep -qw $LOC ) ; then
				NEW_ADAP=$(lscfg | grep -w $LOC | awk '{print $2}')
				echo "\n$AMBER Adapter lable changed from $ADAPTER to $NEW_ADAP for $LOC since reboot"
			fi
		fi
	done
}
#----------------------------------------------------------------------------------------------------------------------
ADAPTER_CHK_V6 ()
{
	ADAPTER_CHK_V5			#Calling Adapter function
	cat $PRE_LOGS | grep -p "lsdev -Ccadapter" | grep Available | awk '{print $1}' > $ADAPT_BEFORE
	lsdev -Ccadapter | grep Available | awk '{print $1}' > $ADAPT_AFTER
	DIFFERENCE=$(diff -u $ADAPT_BEFORE $ADAPT_AFTER | grep -E "^\+ |^\- " | wc -l)
	if [ "$DIFFERENCE" -ge 1 ] > /dev/null
	then
		ADAP=$(diff -u $ADAPT_BEFORE $ADAPT_AFTER | grep -E "^\+ |^\- " |  sed -e 's/ //g')
		NEW_ADAPT=$(diff -u $ADAPT_BEFORE $ADAPT_AFTER | grep "^\+ " |  sed -e 's/+ //')
		MIS_ADAPT=$(diff -u $ADAPT_BEFORE $ADAPT_AFTER | grep "^\- " |  sed -e 's/- //')
		if ( echo $ADAP | tr "[ ]" "[\n]" | grep -q ^- )
		then
			echo "\n$AMBER Missing adapter $MIS_ADAPT  after reboot" ; SLEEP
		fi
		if ( echo $ADAP |  tr "[ ]" "[\n]" | grep -q ^+ )
		then
			echo "\n$AMBER New adapter $NEW_ADAPT availabe after reboot" ; SLEEP
		else
			echo CHECKED Adapters ; SLEEP
		fi
	else
		echo "\n$GREEN Adapter check"
	fi
}

#Verifying sys0 attributes 
SYS_DETAILS ()
{
	cat $PRE_LOGS | grep -p "lsattr -El sys0" | sed -e '1,3d' -e '/^$/d' | awk '{print $1,$2}' | while read VAR VALUE
	do
		REBOOT_VALUE=$(lsattr -El sys0 -a $VAR -F value)
		if [ "$VALUE" != "$REBOOT_VALUE" ] > /dev/null
		then
			echo "$AMBER sys0 attribute value of $VAR, before reboot $VALUE changed to $REBOOT_VALUE after reboot" ; SLEEP
		fi
	done
}

#Validating Kernel and disk status
KRNL_CHK ()
{
	echo "Checking Kernel Bit Mode" ; SLEEP
	KERNEL_MOD_BFR=$(cat $PRE_LOGS | grep -p "getconf KERNEL_BITMODE" | sed -e 1,3d -e '/^$/d')
	KERNEL_MOD_AFT=$(getconf KERNEL_BITMODE)
	if [ "$KERNEL_MOD_BFR" = "$KERNEL_MOD_AFT" ] > /dev/null
	then
		echo "$GREEN KERNEL_BITMODE check" ; SLEEP
	else
		echo "$RED KERNEL_BITMODE check, before reboot $KERNEL_MOD_BFR and after reboot $KERNEL_MOD_AFT" ; SLEEP
	fi
}
#---------------------------------------------------------------------------------------------------------------------
DISK_INFO ()
{
	if ( cat $PRE_LOGS | grep -p "lsdev -Ccdisk"  | sed -e '1,3d' -e '/^$/d' | grep Available | grep -q hdiskpower ) ; then
#		cat $PRE_LOGS | grep -p "lsdev -Ccdisk"  | sed -e '1,3d' -e '/^$/d' | grep Available | grep hdiskpower | awk '{print $1}' > $PRE_DISK
#		lsdev -Ccdisk | grep Available | grep hdiskpower | awk '{print $1}' > $POST_DISK
		echo "$AMBER Power Path details are not collecting using this script. Please contact UNIX L3 support for more details"
	else
		cat $PRE_LOGS | grep -p "lsdev -Ccdisk"  | sed -e '1,3d' -e '/^$/d' | grep Available | awk '{print $1}' > $PRE_DISK
		lsdev -Ccdisk | grep Available | awk '{print $1}' > $POST_DISK
	fi
}

DISK_CHK_V5 ()
{
	DISK_INFO			# Calling Disk info function 
	for MISSING_DISK in `cat $PRE_DISK`
	do
		if ( ! grep -qw $MISSING_DISK $POST_DISK ) ; then
			echo "$AMBER Missing disk $MISSING_DISK after reboot" SLEEP
		fi
	done
	echo "\nCHECKED"
}

DISK_CHK_V6 ()
{
	DISK_INFO			# Calling Disk info function 
	DIFFERENCE=$(diff -u $PRE_DISK $POST_DISK | grep -E "^\+ |^\- " | wc -l)
	if [ "$DIFFERENCE" -ge 1 ] > /dev/null
	then
		TOT_DISK=$(diff -u $PRE_DISK $POST_DISK | grep -E "^\+ |^\- " |  sed -e 's/ //g')
		NEW_DISK=$(diff -u $PRE_DISK $POST_DISK | grep "^\+ " |  sed -e 's/+ //')
		MISSING_DISK=$(diff -u $PRE_DISK $POST_DISK | grep "^\- " |  sed -e 's/- //')	
		if test `echo ${TOT_DISK} | tr "[ ]" "[\n]" | grep ^- | head -1`
		then
			echo ; echo $AMBER $MISSING_DISK | tr "[\n]" "[ ]" ;  echo missing after reboot ; SLEEP
		fi
		if test `echo ${TOT_DISK} |  tr "[ ]" "[\n]" | grep ^+ | head -1`	
		then
			echo ; echo $AMBER $NEW_DISK | tr "[\n]" "[ ]" ; echo New disks availabe after reboot ; SLEEP
		else
			echo CHECKED
		fi	
	else
		echo "\n$GREEN Disk Validation"
	fi
}

#Verifying Processor Availablility
PROC_CHK_V5 ()
{
	echo "\nChecking Available Processors" ; SLEEP
	for PROC in `cat $PRE_LOGS | grep -p "lsdev -l proc*"  | sed -e '1,3d' -e '/^$/d' | grep Available | awk '{print $1}'`
	do
		if ( ! lsdev -S Available | grep proc | grep -qw $PROC ) ; then
			echo "$AMBER $PROC NOT available since reboot" ; SLEEP
		else
			echo "$GREEN $PROC is Available" ; SLEEP_LESS
		fi
	done
}

PROC_CHK_V6 ()
{
	echo "\nChecking Available Processors" ; SLEEP
	cat $PRE_LOGS | grep -p 'lsdev -S Available | grep proc' | sed -e '1,3d' -e '/^$/d' | grep Available | awk '{print $1}' > $PROC_BFR
	lsdev -S Available | grep proc | awk '{print $1}' > $PROC_AFTR 
	DIFFERENCE=$(diff -u $PROC_BFR $PROC_AFTR | grep -E "^\+ |^\- " | wc -l)
	if [ "$DIFFERENCE" -ge 1 ] > /dev/null
	then
		TOT_PROC=$(diff -u $PROC_BFR $PROC_AFTR | grep -E "^\+ |^\- " |  sed -e 's/ //g')
		NEW_PROC=$(diff -u $PROC_BFR $PROC_AFTR | grep "^\+ " |  sed -e 's/+ //')
		MISSING_PROC=$(diff -u $PROC_BFR $PROC_AFTR | grep "^\- " |  sed -e 's/- //')	
		if test `echo ${TOT_PROC} | tr "[ ]" "[\n]" | grep ^- | head -1`
		then
			echo $AMBER $MISSING_PROC | tr "[\n]" "[ ]" ;  echo missing after reboot ; SLEEP
		fi
		if test `echo ${TOT_PROC} |  tr "[ ]" "[\n]" | grep ^+ | head -1`	
		then
			echo $AMBER $NEW_PROC | tr "[\n]" "[ ]" ; echo New processors availabe after reboot ; SLEEP
		else
			echo CHECKED
		fi	
	else
		echo "$GREEN Processor Validation" ; SLEEP
	fi
}

#Validating VG's
VG_STAT ()
{
	for VG in `cat $ACTIV_VG` 
	do
		if ( lsvg -o | grep -qw $VG ) ; then
			echo "$GREEN $VG is active" ; SLEEP_LESS
		else
			echo "$AMBER $VG inactive" ; SLEEP
		fi
	done
}

#Checking Disk Path consistency
DISK_PATH_CHK ()
{
	cat $PRE_LOGS | grep -p "lspath -F" | sed -e '1,3d' -e '/^$/d' | awk -F ":" '{print $3,$1,$2}' | sort -k1 > $DISK_PATH_BEFORE
	lspath | sort -k1 > $DISK_PATH_AFTER
	FAILURES=$(sdiff -s $DISK_PATH_BEFORE $DISK_PATH_AFTER | awk '/|/ ; /</ ; />/ {print $0}' | wc -l)
	if [ "$FAILURES" -ge 1 ] > /dev/null
	then
		CHANGES=$(sdiff -s $DISK_PATH_BEFORE $DISK_PATH_AFTER | grep "|" | wc -l)
		if [ "$CHANGES" -ge 1 ] > /dev/null
		then
			DISK=$(sdiff -s $DISK_PATH_BEFORE $DISK_PATH_AFTER | grep "|" | awk -F "|" '{print $2}' | awk '!a[$2]++'| awk '{print $2}')
			PREV_STAT=$(sdiff -s $DISK_PATH_BEFORE $DISK_PATH_AFTER | grep "|" | awk -F "|" '{print $1}')
			CURR_STAT=$(sdiff -s $DISK_PATH_BEFORE $DISK_PATH_AFTER | grep "|" | awk -F "|" '{print $2}')
			echo '\033[33mWARNING\033[0m' $DISK | tr "[\n]" "[ ]" ; print "path status changed" 
			echo "\nPrevious status of paths\n---------------------------------"
			printf "%1s %5s %5s\n%1s %5s %5s\n" $PREV_STAT ; sleep 1
			echo "\nCurrent status of paths\n---------------------------------"
			printf "%1s %5s %5s\n%1s %5s %5s\n" $CURR_STAT ; sleep 1
		fi	
		MISSING=$(sdiff -s $DISK_PATH_BEFORE $DISK_PATH_AFTER | grep "<" | wc -l)
		if [ "$MISSING" -ge 1 ] > /dev/null
		then
			PREV_STAT=$(sdiff -s $DISK_PATH_BEFORE $DISK_PATH_AFTER | grep "<" |sed 's/\<//')
			echo "\033[33mWARNING\033[0m Paths Missing since reboot\n-------------------------------------------"
			printf "%1s %5s %5s\n%1s %5s %5s\n" $PREV_STAT ; sleep 1
		fi
		NEW_PATHS=$(sdiff -s $DISK_PATH_BEFORE $DISK_PATH_AFTER | grep ">" | wc -l)
		if [ "$NEW_PATHS" -ge 1 ] > /dev/null
		then
			CURR_STAT=$(sdiff -s $DISK_PATH_BEFORE $DISK_PATH_AFTER | grep ">" |sed 's/\>//')
			echo "\033[33mWARNING\033[0m New Paths Available after reboot\n-----------------------------------------------"
			printf "%1s %5s %5s\n%1s %5s %5s\n" $CURR_STAT ; sleep  1
		fi	
	else
		echo "$GREEN Disk path Validation" ; SLEEP
	fi
}

#Comparing "no"[network tunable] parameters
NO_CHK ()
{
	cat $PRE_LOGS | grep -p "no -x" | sed -e '1,3d' -e '/^$/d' | awk -F "," '{print $1,$2,$3,$4}' | while read NAME CUR DEF BOOT
	do 
		no -x | awk -F "," '{print $1,$2,$3,$4}' | grep -w $NAME | read NAME_REB CUR_REB DEF_REB BOOT_REB
		if [ "$NAME" = "$NAME_REB" ] 
		then
			if [ "$CUR" = "$CUR_REB" -a "$DEF" = "$DEF_REB" -a "$BOOT" = "$BOOT_REB" ] > /dev/null
			then
				continue 
			else
				if [ "$CUR" != "$CUR_REB" ] 
				then
					echo "$AMBER Name=$NAME::Value_Type=CUR::BEFORE=$CUR::AFTER=$CUR_REB::" ; SLEEP
				fi
				if [ "$DEF" != "$DEF_REB" ] 
				then
					echo "$AMBER Name=$NAME::Value_Type=DEF::BEFORE=$DEF::AFTER=$DEF_REB::" ; SLEEP
				fi
				if [ "$BOOT" != "$BOOT_REB" ] 
				then
					echo "$AMBER Name=$NAME::Value_Type=BOOT::BEFORE=$BOOT::AFTER=$BOOT_REB::" ; SLEEP
				fi
			fi
		fi
	done
}

#Comparing "vmo"[Virtual Memory Manager] tuning parameter verification
VMO_CHK ()
{
	cat $PRE_LOGS|grep -p "vmo -x"|sed -e '1,3d' -e '/^$/d'|awk -F "," '{print $1,$2,$3,$4}'|grep -Evw "pinnable_frames|maxpin"|while read NAME CUR DEF BOOT
	do 
		vmo -x | awk -F "," '{print $1,$2,$3,$4}' | grep -w $NAME | read NAME_REB CUR_REB DEF_REB BOOT_REB
		if [ "$NAME" = "$NAME_REB" ] 
		then
			if [ "$CUR" = "$CUR_REB" -a "$DEF" = "$DEF_REB" -a "$BOOT" = "$BOOT_REB" ] > /dev/null
			then
				continue 
			else
				if [ "$CUR" != "$CUR_REB" ] 
				then
					echo "$AMBER Name=$NAME::Value_Type=CUR::BEFORE=$CUR::AFTER=$CUR_REB::" ; SLEEP
				fi
				if [ "$DEF" != "$DEF_REB" ] 
				then
					echo "$AMBER Name=$NAME::Value_Type=DEF::BEFORE=$DEF::AFTER=$DEF_REB::" ; SLEEP
				fi
				if [ "$BOOT" != "$BOOT_REB" ] 
				then
					echo "$AMBER Name=$NAME::Value_Type=BOOT::BEFORE=$BOOT::AFTER=$BOOT_REB::" ; SLEEP
				fi
			fi
		fi
	done
}

#Validating Dump devices
DUMP_CHK ()
{
	PRIMARY_AFT=$(sysdumpdev -l | awk '$1 == "primary" {print $2}')
	SEC_AFTER=$(sysdumpdev -l | awk '$1 == "secondary" {print $2}')
	PRIMARY_BFR=$(cat $PRE_LOGS | grep -p "sysdumpdev -l"  |sed -e '1,3d' | awk '$1 == "primary" {print $2}')
	SEC_BEFORE=$(cat $PRE_LOGS | grep -p "sysdumpdev -l"  |sed -e '1,3d' | awk '$1 == "secondary" {print $2}')
	if [ "$PRIMARY_AFT" = "$PRIMARY_BFR" ] > /dev/null
	then
		echo "$GREEN Primary dump device check" ; SLEEP
	else
		echo "$AMBER Primary dump device check, before reboot $PRIMARY_BFR and after reboot $PRIMARY_AFT" ; SLEEP
	fi
	if [ "$SEC_BEFORE" = "$SEC_AFTER" ] > /dev/null
	then
		echo "$GREEN Secondary dump device check" ; SLEEP
	else
		echo "$AMBER Secondary dump device check, before reboot $SEC_BEFORE and after reboot $SEC_AFTER" ; SLEEP
	fi
}

OS_VER ()
{
	if [ $OSLEVEL = 5.3 ] > /dev/null
	then
		_VAR_ADAP=ADAPTER_CHK_V5
		_VAR_DISK=DISK_CHK_V5
		_VAR_PROC=PROC_CHK_V5
	else
		_VAR_ADAP=ADAPTER_CHK_V6
		_VAR_DISK=DISK_CHK_V6
		_VAR_PROC=PROC_CHK_V6
	fi
}

#Checking Shared Ethernet Adapter status of VIO servers.
SEA_STAT ()
{
	if ( lslpp -L | grep -q ios.cli.rte ) 
	then
		/usr/ios/cli/ioscli lsdev -type sea | awk '/ent/ \
		{print $1,system("lsattr -El "$1" -a ha_mode -F value")}' | \
		sed -e 's/^0//' -e '/^$/d' | \
		awk '/ent/ $2 !~ "auto|sharing" {print "'$RED' "$1" SEA is in\033[31m",$2,"\033[0mstatus"}' | \
		awk  '{print "\n"$0} END {if (NR == "0") printf "\n\033[32mPASSED\033[0m SEAs are online\n"}'

		for SEA in $(/usr/ios/cli/ioscli lsdev -type sea | awk 'NR>1 {print $1}') ; do
			set -A curr_sea $(entstat -d $SEA | grep -E "VLAN ID:|VLAN Tag IDs:" | awk -F ":" '{print $2}'|grep -E "[0-9]")
			for vlan in ${curr_sea[*]} ; do
				if ( ! grep -wq $vlan $log_dir/SEA_$SEA ) ; then
					echo "$RED Vlan $vlan missing from $SEA" ; RC=1  
				fi
			done
			if [ "$RC" = 1 ] ; then
				echo "$RED Vlan check for SEA $SEA" ; RC=0
			else
				echo "$GREEN Vlan check for SEA $SEA"
			fi
		done
	fi
} 

#Checking nfs daemon and will start if not active. 
nfs_stat () 
{
	set -A nfs $(grep -p "lssrc -a | grep active" $PRE_LOGS | awk '/nfs/ {print $1}')
	if [ ${#nfs[*]} -ge 1 ] ; then
		for subsys in ${nfs[*]} ; do
			x=1
			while ( ! lssrc -s $subsys | awk 'NR>1 {print $NF}' | grep -qw active ) ; do
				echo "nfs subsystem \"$subsys\" not active, starting..."
				startsrc -s $subsys ; sleep 1
				echo
				((x=x+1))
				if [ $x = 4 ] ; then
					echo "$RED Retry limit reached for \"$subsys\", permanently failed to start the subsystem"
					break
				fi
			done
		done
	fi
}
#End of POST_CHK Functions

#Calling POST_CHK Functions 
clear
OS_VER
GPFS_CHK
HACMP_CHK
HOST_CHK

echo "\n==============================Validating TIMEZONE*==============================" ; SLEEP
FILE_CHK $DATE_INFO TZ_CHK

echo "\n==============================Validating FS mounts==============================" ; SLEEP
echo "\nValidating FS mounts from df output" ; SLEEP
FILE_CHK $FS_INFO FS_MNT_CHK
echo "\n__________________________________________________________________________________\n" ; SLEEP
printf "Validating FS mounts from /etc/filesystems" ; dots
bgid=$!
LSFS_MNT | awk '{print "\n"$0} END {if (NR == "0") printf "\n\033[32mPASSED\033[0m mount validation from /etc/filesystems"}'
kill $bgid

echo "\n==============================Validating Mount Order==============================\n" ; SLEEP
printf "Validating mounted filesystems mount order" ; dots
bgid=$!
MNT_CHECK | awk '{print "\n"$0} END {if (NR == "0") printf "\n\033[32mPASSED\033[0m mount order check from df"}'
kill $bgid

echo
echo "__________________________________________________________________________________\n" ; SLEEP
printf "Validating Mount Order from /etc/filesystems" ; dots
bgid=$!
LSFS_ORDER | awk  '{print "\n"$0} END {if (NR == "0") printf "\n\033[32mPASSED\033[0m FS order check of /etc/filesystem"}'
kill "$bgid"

echo "\n==============================Validating Route==============================\n" ; SLEEP
FILE_CHK $ROUTE ROUTE_CHK

echo "\n==============================Validating IP Address==============================\n" ; SLEEP
FILE_CHK $IP_INFO IP_CHECK
FILE_CHK $IP_AFTR IP_CHK_AFTR

echo "\n==============================Validating LPAR Statistics==============================" ; SLEEP
LPARSTAT | awk  '{print "\n"$0} END {if (NR == "0") printf "\n\033[32mPASSED\033[0m LPAR statistics validation"}'

echo "\n==============================Validating BOOT DISKS==============================\n" ; SLEEP
FILE_CHK $PRE_LOGS BOOT_DEVICE

echo "\n==========================================================================================" ; SLEEP
echo
printf "Validating Adapters"  ; dots
bgid=$!
FILE_CHK $ADAPTR $_VAR_ADAP
kill "$bgid"

echo "\n==============================Validating Processors==============================" ; SLEEP
FILE_CHK $PRE_LOGS $_VAR_PROC


echo "\n==============================Validating VG Status==============================\n" ; SLEEP
FILE_CHK $ACTIV_VG VG_STAT

echo "\n==============================Validating System Details==============================\n" ; SLEEP
echo "Validating sys0 attributes"
FILE_CHK $PRE_LOGS SYS_DETAILS
echo CHECKED

echo
printf "Validating Disks"  ; dots
bgid=$!
FILE_CHK $ADAPTR $_VAR_DISK
kill "$bgid"

echo "\n__________________________________________________________________________________\n" ; SLEEP
FILE_CHK $PRE_LOGS KRNL_CHK

echo "\nValidating disk paths" ; SLEEP
FILE_CHK $PRE_LOGS DISK_PATH_CHK

echo "\n==============================Validating Tunable Paramaters==============================\n" ; SLEEP
printf "Validating \"no\" parameters" ; dots
bgid=$!
NO_CHK | awk  '{print "\n"$0} END {if (NR == "0") print "\n\033[32mPASSED\033[0m network tuning parameter verification"}'
kill $bgid
echo
printf "Validating \"vmo\" parameters" ; dots
bgid=$!
VMO_CHK | awk '{print "\n"$0} END {if (NR == "0") print "\n\033[32mPASSED\033[0m Virtual Memory Manager tuning parameter verification"}'
kill $bgid

echo "\n==============================Validating Dump Devices==============================\n" ; SLEEP
FILE_CHK $PRE_LOGS DUMP_CHK

#echo "\nVerifying Monitoring process status" ; SLEEP
#POSTFIX_ITM

echo ; SEA_STAT
echo ; nfs_stat
echo
echo "--> Logs Stored at $LOGS" ; sleep 1
echo "\n===============================================================================================" ; SLEEP
#End of MAIN_POST function

}

MAIN_POST | tee -a $LOGS
sleep 2
cat $LOGS | egrep "FAILED|ERROR" > /dev/null
	if [ $? = 0 ] > /dev/null
	then
		echo "\nFailed Post check, fix below FAILURES and rerun post check\n" | tee -a $LOGS $FAILURE_LOGS ; sleep 2
		echo ; cat $LOGS | egrep "FAILED|WARNING|ERROR" | sort -u | tee -a $LOGS $FAILURE_LOGS
		echo "\nDetails of Failures are also availabe in $FAILURE_LOGS" | tee -a $LOGS 
		echo "\nWARNINGS are not considered as Failures, but requires \033[31mAttention\033[0m" | tee -a $LOGS $FAILURE_LOGS; SLEEP
		echo "\n#################################################################################" | tee -a $LOGS $FAILURE_LOGS ; SLEEP
	else
		if ( grep -q WARNING $LOGS) ; then
			echo "\n$GREEN Post check Validation with WARNINGS" | tee -a $LOGS ; sleep 2
			echo | tee -a $LOGS
			cat $LOGS | grep WARNING | grep -v Validation | tee -a $LOGS
			echo "\nWARNINGS are not considered as Failures, but requires \033[31mAttention\033[0m" | tee -a $LOGS ; SLEEP
			echo "\n#################################################################################" | tee -a $LOGS ; SLEEP
		else
			if ( grep -q PASSED $LOGS ) ; then
				echo "\n$GREEN Post check Validation" | tee -a $LOGS ; sleep 1
				echo "\n#################################################################################" | tee -a $LOGS ; SLEEP
			else
				echo "\n$RED Post check Validation" | tee -a $LOGS ; sleep 1
				echo "\n#################################################################################" | tee -a $LOGS ; SLEEP
			fi		
		fi
	fi
#End of POST_CHK Function

}
case $1 in
  pre|Pre|PRE)
  PRE_CHK  ;;

  post|Post|POST)
  POST_CHK ;;

  *)
    Usage ;;
esac

#EOF
