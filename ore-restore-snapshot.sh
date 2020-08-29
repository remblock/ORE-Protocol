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
data_folder=/root/data
log_file=/root/nodeos.log
configfolder=/root/config
state_folder=$datafolder/state
blocks_folder=$datafolder/blocks
external_api=https://ore.eosusa.news
snapshots_folder=$datafolder/snapshots
state_history_folder=$datafolder/state-history
last_download_folder=$snapshotsfolder/lastdownload

#----------------------------------------------------------------------------------------------------#
# CREATE DOWNLOAD FOLDER IN SNAPSHOTS                                                                #
#----------------------------------------------------------------------------------------------------#

mkdir -p $last_download_folder
cd $last_download_folder
echo "Clearing last download folder"
rm -f *.bin

#----------------------------------------------------------------------------------------------------#
# CHOOSING THE TYPE OF SNAPSHOT                                                                      #
#----------------------------------------------------------------------------------------------------#

PS3='Please enter the menu number below: '
options=("Snapshot Only" "Snapshot and Blocks Log" "Snapshot and Blocks Log and State History" "Quit")
snap_type_php=""
select opt in "${options[@]}"
do
    case $opt in
        "Snapshot Only")
        snap_type_php="snap"
            echo "Your choice is snapshot only"
        break
            ;;
        "Snapshot and Blocks Log")
            echo "Your choice is blocks log and snapshot"
        snap_type_php="blocks"
        break
            ;;
       "Snapshot and Blocks Log and State History")
            echo "Your choice is state history and blocks log and snapshot"
        snap_type_php="state-history"
break
            ;;
        "Quit")
            exit 1
break
            ;;
        *) echo "Invalid option $REPLY";;
    esac
done

#----------------------------------------------------------------------------------------------------#
# SNAPSHOT OPTION    		                                                                     #
#----------------------------------------------------------------------------------------------------#

if [[ $snap_type_php -eq "snap" ]]
then
  rm -rf $snapshotsfolder/*.bin
  mkdir -p $last_download_folder/snapshot
  cd $last_download_folder/snapshot
  $latest_snapshot=$(curl -s https://ore.remblock.io/snapshots/latestsnapshot.php)
  echo "Downloading snapshot now..."
  wget -Nc https://ore.remblock.io/snapshots/$latest_snapshot -q --show-progress  -O - | sudo tar -Sxz --strip=4
  echo "Downloaded Snapshot $latest_snapshot"
  cp -a $last_download_folder/snapshot/. $snapshots_folder/
  bin_file=$(ls *.bin | head -1)
  echo "bin file downloaded is $bin_file"
fi

#----------------------------------------------------------------------------------------------------#
# BLOCKS OPTION    		                                                                     #
#----------------------------------------------------------------------------------------------------#

if [[ $snap_type_php -eq "blocks" ]]
then
  rm -rf $blocks_folder*/
  mkdir -p $last_download_folder/blocks
  cd $last_download_folder/blocks
  $latest_blocks=$(curl -s https://ore.remblock.io/snapshots/latestblocks.php)
  echo "Downloading blocks now..."
  wget  -Nc https://ore.remblock.io/snapshots/blocks/$blocks -q --show-progress -O - | sudo tar -Sxz --strip=3
  echo "Downloaded Blocks $latest_blocks"
  cp -a $last_download_folder/blocks/. $blocks_folder/
fi

#----------------------------------------------------------------------------------------------------#
# STATE HISTROY OPTION                                                                               #
#----------------------------------------------------------------------------------------------------#

if [[ $snap_type_php -eq "state-history" ]]
then
  rm -rf $state_folder*/
  mkdir -p $last_download_folder/state-history
  cd $last_download_folder/state-history
  $latest_state_history=$(curl -s https://ore.remblock.io/snapshots/lateststatehistory.php)
  echo "Downloading state history now..."
  wget  -Nc https://ore.remblock.io/snapshots/state-history/$latest_state_history -q --show-progress -O - | sudo tar -Sxz --strip=3
  echo "Downloaded Blocks $latest_state_history"
  cp -a $last_download_folder/state-history/. $state_history_folder/
fi
rm -R $last_download_folder/*

#----------------------------------------------------------------------------------------------------#
# MAIN PART OF THE SCRIPT                                                                            #
#----------------------------------------------------------------------------------------------------#

function StopNode() {
echo "Nodeos is stopping..."
nodeos_pid=$(pgrep nodeos)
if [ ! -z "$nodeos_pid" ]; then
    if ps -p $nodeos_pid > /dev/null; then
        kill -SIGINT $nodeos_pid
    fi
    while ps -p $nodeos_pid > /dev/null; do
        sleep 1
    done
fi
echo "Nodeos has stopped..."
}

function StartNode() {
  echo "Starting ORE Protocol - Config: $config_folder Bin File: $snapshots_folder/$bin_file Date Folder: $data_folder"
  nodeos --config-dir $config_folder/ --disable-replay-opts --data-dir $data_folder/ >> $log_file 2>&1 &
}

function StartNodeSnapshot() {
    echo "Starting ORE Protocol - Config: $config_folder Bin File: $snapshots_folder/$bin_file Data Folder: $data_folder"
    nodeos --config-dir $config_folder/ --disable-replay-opts --snapshot $snapshots_folder/$bin_file --data-dir $data_folder/ >> $log_file 2>&1 &
}

function WritePercentage() {

diff=$(($2-$1))
sumit=$(awk "BEGIN {print ($diff/$2)*100}")
percentage=$(awk "BEGIN {print (100 - $sumit) }")
echo -en "\r$percentage% Chain Sync Completed\c\b"
}

sync_log=/root/data/snapshots/sync.log
touch $sync_log
echo -999999999999 > $sync_log
their_head_block_num=$(cleos -u $external_api get info | jq '.head_block_num')
our_head_block_num=$(cleos get info | jq '.head_block_num')
sleep 1
blockdiff=$(($their_head_block_num-$our_head_block_num))
echo "Block Height Difference: $block_diff Blocks - Their Head Block Number: $their_head_block_num - Ours: $our_head_block_num"

#----------------------------------------------------------------------------------------------------#
# NOW WE WAIT FOR LAST IRREVERSIBLE BLOCK TO PASS OUR SNAPSHOT TAKEN                                 #
#----------------------------------------------------------------------------------------------------#

if [[ $our_head_block_num -eq $their_head_block_num ]] 
then
 echo 0 > $sync_log
else
 while [[ 1 -eq 1 ]]
 do
 their_head_block_num=$(cleos -u $external_api get info | jq '.head_block_num')
 our_head_block_num=$(cleos get info | jq '.head_block_num')
 block_diff=$(($their_head_block_num-$our_head_block_num))
 echo $block_diff > $sync_log
 if [[ $their_head_block_num -le $our_head_block_num ]]
 then
   break                               
 else
   WritePercentage $our_head_block_num $their_head_block_num
   sleep 2
 fi 
 done
fi

sleep 3
StopNode
sleep 1
cd ~
sleep 1
StartNodeSnapshot

echo ""
echo "==================================="
echo "ORE PROTOCOL SNAPSHOT HAS COMPLETED"
echo "==================================="
echo ""
