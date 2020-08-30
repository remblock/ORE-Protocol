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
config_folder=/root/config
state_folder=$data_folder/state
blocks_folder=$data_folder/blocks
external_api=https://ore.eosusa.news
snapshots_folder=$data_folder/snapshots
state_history_folder=$data_folder/state
last_download_folder=$snapshots_folder/lastdownload

#----------------------------------------------------------------------------------------------------#
# INSTALL ORE SNAPSHOT DEPENDENCIES                                                                  #
#----------------------------------------------------------------------------------------------------#

sudo apt install curl -y
sudo apt-get install jq -y

#----------------------------------------------------------------------------------------------------#
# CREATE SNAPSHOT FOLDER IN DATA                                                                     #
#----------------------------------------------------------------------------------------------------#

if [ ! -d "$snapshots_folder" ]
then
  mkdir -p "$snapshots_folder"
  cp -p "$0" "$snapshots_folder"
fi

#----------------------------------------------------------------------------------------------------#
# CREATE DOWNLOAD FOLDER IN SNAPSHOTS                                                                #
#----------------------------------------------------------------------------------------------------#

mkdir -p $last_download_folder
cd $last_download_folder
rm -f *.bin

#----------------------------------------------------------------------------------------------------#
# CHOOSING THE TYPE OF SNAPSHOT                                                                      #
#----------------------------------------------------------------------------------------------------#

echo ""
echo "<<< ORE-RESTORE-SNAPSHOT >>>"
echo ""
PS3='Please choose a number from the menu above: '
options=("Snapshot Only" "Snapshot and Blocks Log" "Snapshot and Blocks Log and State History" "Quit")
snap_type_php=""
select opt in "${options[@]}"
do
    case $opt in
        "Snapshot Only")
        rm -rf $snapshotsfolder/*.bin
        mkdir -p $last_download_folder/snapshot
        cd $last_download_folder/snapshot
        latest_snapshot=$(curl -s https://ore.remblock.io/snapshots/latestsnapshot.txt)
        echo ""
        echo "Downloading snapshot now..."
        wget https://ore.remblock.io/snapshots/$latest_snapshot
        echo ""
        echo "Downloaded $latest_snapshot"
        sudo tar -Sxz --strip=4 -f $latest_snapshot
        echo ""
        echo "Uncompressed $latest_snapshot"
        cp -a $last_download_folder/snapshot/. $snapshots_folder/
        bin_file=$(ls *.bin | head -1)
        break
             ;;
        "Snapshot and Blocks Log")
        rm -rf $snapshotsfolder/*.bin
        mkdir -p $last_download_folder/snapshot
        cd $last_download_folder/snapshot
        latest_snapshot=$(curl -s https://ore.remblock.io/snapshots/latestsnapshot.txt)
        echo ""
        echo "Downloading snapshot now..."
        wget https://ore.remblock.io/snapshots/$latest_snapshot
        echo ""
        echo "Downloaded $latest_snapshot"
        sudo tar -Sxz --strip=4 -f $latest_snapshot
        echo ""
        echo "Uncompressed $latest_snapshot"
        cp -a $last_download_folder/snapshot/. $snapshots_folder/
        bin_file=$(ls *.bin | head -1)
        rm -rf $blocks_folder*/
        mkdir -p $last_download_folder/blocks
        cd $last_download_folder/blocks
        latest_blocks=$(curl -s https://ore.remblock.io/snapshots/latestblocks.txt)
        echo ""
        echo "Downloading blocks now..."
        wget https://ore.remblock.io/snapshots/blocks/$latest_blocks
        echo ""
        echo "Downloaded $latest_blocks"
        sudo tar -Sxz --strip=3 -f $latest_blocks
        echo ""
        echo "Uncompressed $latest_blocks"
        cp -a $last_download_folder/blocks/. $blocks_folder/
        break
             ;;
       "Snapshot and Blocks Log and State History")  
       rm -rf $snapshotsfolder/*.bin
       mkdir -p $last_download_folder/snapshot
       cd $last_download_folder/snapshot
       latest_snapshot=$(curl -s https://ore.remblock.io/snapshots/latestsnapshot.txt)
       echo ""
       echo "Downloading snapshot now..."
       wget https://ore.remblock.io/snapshots/$latest_snapshot
       echo ""
       echo "Downloaded $latest_snapshot"
       sudo tar -Sxz --strip=4 -f $latest_snapshot
       echo ""
       echo "Uncompressed $latest_snapshot"
       cp -a $last_download_folder/snapshot/. $snapshots_folder/
       bin_file=$(ls *.bin | head -1)
       rm -rf $blocks_folder*/
       mkdir -p $last_download_folder/blocks
       cd $last_download_folder/blocks
       latest_blocks=$(curl -s https://ore.remblock.io/snapshots/latestblocks.txt)
       echo ""
       echo "Downloading blocks now..."
       wget https://ore.remblock.io/snapshots/blocks/$latest_blocks
       echo ""
       echo "Downloaded $latest_blocks"
       sudo tar -Sxz --strip=3 -f $latest_blocks
       echo ""
       echo "Uncompressed $latest_blocks"
       cp -a $last_download_folder/blocks/. $blocks_folder/
       rm -rf $state_folder*/
       mkdir -p $last_download_folder/state-history
       cd $last_download_folder/state-history
       latest_state_history=$(curl -s https://ore.remblock.io/snapshots/lateststatehistory.txt)
       echo ""
       echo "Downloading state history now..."
       wget -Nc https://ore.remblock.io/snapshots/state-history/$latest_state_history
       echo ""
       echo "Downloaded $latest_state_history"
       sudo tar -Sxz --strip=3 -f $latest_state_history
       echo ""
       echo "Uncompressed $latest_state_history"
       cp -a $last_download_folder/state-history/. $state_history_folder/
       break
            ;;
       "Quit")
       exit 1
       break
            ;;
       *) echo "Invalid option $REPLY";;
    esac
done

rm -R $last_download_folder/*

#----------------------------------------------------------------------------------------------------#
# NODEOS STOP FUNCTION                                                                               #
#----------------------------------------------------------------------------------------------------#

function StopNode() {
nodeos_pid=$(pgrep nodeos)
if [ ! -z "$nodeos_pid" ]; then
    if ps -p $nodeos_pid > /dev/null; then
        kill -SIGINT $nodeos_pid
    fi
    while ps -p $nodeos_pid > /dev/null; do
        sleep 1
    done
fi
}

#----------------------------------------------------------------------------------------------------#
# NODEOS START FUNCTION                                                                              #
#----------------------------------------------------------------------------------------------------#

function StartNode() {
  nodeos --config-dir $config_folder/ --disable-replay-opts --data-dir $data_folder/ >> $log_file 2>&1 &
}

#----------------------------------------------------------------------------------------------------#
# NODEOS START SNAPSHOT FUNCTION                                                                     #
#----------------------------------------------------------------------------------------------------#

function StartNodeSnapshot() {
  nodeos --config-dir $config_folder/ --disable-replay-opts --snapshot $snapshots_folder/$bin_file --data-dir $data_folder/ >> $log_file 2>&1 &
}

#----------------------------------------------------------------------------------------------------#
# WRITE PERCENTAGE FUNCTION                                                                          #
#----------------------------------------------------------------------------------------------------#

function WritePercentage() {
diff=$(($2-$1))
sumit=$(awk "BEGIN {print ($diff/$2)*100}")
percentage=$(awk "BEGIN {print (100 - $sumit) }")
echo -en "\r$percentage% Chain Sync Completed\c\b"
}

#----------------------------------------------------------------------------------------------------#
# STOP NODEOS AND RESTORE SNAPSHOT                                                                   #
#----------------------------------------------------------------------------------------------------#

StopNode
sleep 1
cd ~
sleep 1
echo ""
StartNodeSnapshot
WritePercentage

#----------------------------------------------------------------------------------------------------#
# CHECK IRREVERSIBLE BLOCK AGAINST EXTERNAL API                                                      #
#----------------------------------------------------------------------------------------------------#

sync_log=/root/data/snapshots/sync.log
touch $sync_log
echo -999999999999 > $sync_log
api_head_block_num=$(cleos -u $external_api get info | jq '.head_block_num')
our_head_block_num=$(cleos get info | jq '.head_block_num')
sleep 1
block_diff=$(($api_head_block_num-$our_head_block_num))
echo "
echo "Head Block Number: $our_head_block_num"
echo "API Head Block Number: $api_head_block_num"
echo "Block Height Difference: $block_diff Blocks"
echo ""

#----------------------------------------------------------------------------------------------------#
# NOW WE WAIT FOR LAST IRREVERSIBLE BLOCK TO PASS OUR SNAPSHOT TAKEN                                 #
#----------------------------------------------------------------------------------------------------#

if [[ $our_head_block_num -eq $api_head_block_num ]] 
then
 echo 0 > $sync_log
else
 while [[ 1 -eq 1 ]]
 do
 api_head_block_num=$(cleos -u $external_api get info | jq '.head_block_num')
 our_head_block_num=$(cleos get info | jq '.head_block_num')
 block_diff=$(($api_head_block_num-$our_head_block_num))
 echo $block_diff > $sync_log
 if [[ $api_head_block_num -le $our_head_block_num ]]
 then
   break       
 else
   WritePercentage $our_head_block_num $api_head_block_num
   sleep 2
 fi
 done
fi
rm $sync_log
echo ""
echo "==================================="
echo "ORE PROTOCOL SNAPSHOT HAS COMPLETED"
echo "==================================="
echo ""
