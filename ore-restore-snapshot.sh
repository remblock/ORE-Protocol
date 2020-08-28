#!/bin/bash

#****************************************************************************************************#
#                                        ORE-RESTORE-SNAPSHOT                                        #
#****************************************************************************************************#

#----------------------------------------------------------------------------------------------------#
# IF THE USER HAS NO ROOT PERMISSIONS THE SCRIPT WILL EXIT                                           #
#----------------------------------------------------------------------------------------------------#

if (($EUID!=0))
then
  echo "You must be root to run this script" 2>&1
  exit 1
fi

#----------------------------------------------------------------------------------------------------#
# CONFIGURATION VARIABLES                                                                            #
#----------------------------------------------------------------------------------------------------#

data_folder="/root/data"
log_file="/root/nodeos.log"
config_folder="/root/config"
create_snapshot_folder="$data_folder/snapshots"

#----------------------------------------------------------------------------------------------------#
# MAIN PART OF THE SCRIPT                                                                            #
#----------------------------------------------------------------------------------------------------#

if [ ! -d "$create_snapshot_folder" ]
then
  mkdir -p "$create_snapshot_folder"
  cp -p "$0" "$create_snapshot_folder"
fi
blocks_folder=$data_folder/blocks
state_folder=$data_folder/state
rm -f *.bin
latest_snapshot=$(curl -s https://ore.remblock.io/snapshots/latestsnapshot.php)
wget -c https://ore.remblock.io/snapshots/$latest_snapshot -O - | sudo tar -xz --strip=4
bin_file=$create_snapshot_folder/*.bin
nodeos_pid=$(pgrep nodeos)
if [ ! -z "$nodeos_pid" ]
then
  if ps -p $nodeos_pid > /dev/null
  then
    kill -SIGINT $nodeos_pid
  fi
  while ps -p $nodeos_pid > /dev/null; do
  sleep 1
  done
fi
rm -rf $blocks_folder*/
rm -rf $state_folder
cd ~
nodeos --config-dir $config_folder --snapshot $bin_file --data-dir $data_folder >> $log_file 2>&1 &
sleep 4
while [ : ]
do
	systemdt=$(date '+%Y-%m-%dT%H:%M')

	if [ "$dt1" == "$systemdt" ]; then
		break
	else
		dt1=$(cleos get info | grep head_block_time | cut -c 23-38)
		dt1date=$(echo $dt1 | awk -F'T' '{print $1}' | awk -F'-' 'BEGIN {OFS="-"}{ print $3, $2, $1}')
		dt1time=$(echo $dt1 | awk -F'T' '{print $2}' | awk -F':' 'BEGIN {OFS=":"}{ print $1, $2}')

		dt2=$(tail -n 1 $log_file | awk '{print $2}'| awk -F'.' '{print $1}')
		dt2date=$(echo $dt2 | awk -F'T' '{print $1}' | awk -F'-' 'BEGIN {OFS="-"}{ print $3, $2, $1}')
		dt2time=$(echo $dt2 | awk -F'T' '{print $2}' | awk -F':' 'BEGIN {OFS=":"}{ print $1, $2}')

		echo "Fetching blocks for [${dt1date} | ${dt1time}] | Current block date [${dt2date} | ${dt2time}]"
	fi

	echo ""
	sleep 2
done
echo ""
echo "==================================="
echo "ORE PROTOCOL SNAPSHOT HAS COMPLETED"
echo "==================================="
echo ""
