#!/bin/bash

#****************************************************************************************************#
#                                        ORE-RESTORE-SNAPSHOT                                        #
#****************************************************************************************************#

#----------------------------------------------------------------------------------------------------#
# CONFIGURATION VARIABLES                                                                            #
#----------------------------------------------------------------------------------------------------#

data_folder=/root/data
log_file=/root/nodeos.log
config_folder=/root/config
state_folder=$data_folder/state
blocks_folder=$data_folder/blocks
snapshots_folder=$data_folder/snapshots

#----------------------------------------------------------------------------------------------------#
# CREATE SNAPSHOT FOLDER IN DATA                                                                     #
#----------------------------------------------------------------------------------------------------#

if [ ! -d $snapshots_folder ]
then
  mkdir -p $snapshots_folder
  cp -p $0 $snapshots_folder
fi

rm $snapshot_folder/*.bin 2> /dev/null

#----------------------------------------------------------------------------------------------------#
# GRACEFULLY STOP ORE-PROTOCOL                                                                       #
#----------------------------------------------------------------------------------------------------#

nodeos_pid=$(pgrep nodeos)
if [ ! -z "$nodeos_pid" ]
then
  if ps -p $nodeos_pid > /dev/null; then
     kill -SIGINT $nodeos_pid
  fi
  while ps -p $nodeos_pid > /dev/null; do
  sleep 1
  done
fi

#----------------------------------------------------------------------------------------------------#
# MAIN PART OF THE SCRIPT                                                                            #
#----------------------------------------------------------------------------------------------------#

echo ""
echo "<<< ORE-RESTORE-SNAPSHOT >>>"
latest_snapshot=$(curl -s https://ore.remblock.io/snapshots/latestsnapshot.txt)
echo ""
echo "Downloading Snapshot now..."
echo ""
curl -O https://ore.remblock.io/snapshots/$latest_snapshot
echo ""
echo "Downloaded $latest_snapshot"
gunzip $latest_snapshot
tar_file=$(ls *.tar | head -1)
sudo tar -xvf $tar_file
rm $tar_file
mv /root/root/data/snapshots/*.bin $snapshots_folder/
bin_file=$snapshots_folder/*.bin
echo ""
echo "Uncompressed $latest_snapshot"
rm -rf $blocks_folder
rm -rf $state_folder
cd ~
nodeos --config-dir $config_folder/ --data-dir $data_folder/ --snapshot $bin_file >> $log_file 2>&1 &
sleep 4
while [ : ]
do
	systemdt=$(date '+%Y-%m-%dT%H:%M')

	if [ "$dt1" == "$systemdt" ]; then
		break
	else
		dt1=$(nodeos get info | grep head_block_time | cut -c 23-38)
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
