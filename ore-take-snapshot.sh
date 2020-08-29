#!/bin/bash

#****************************************************************************************************#
#                                     ORE-PROTOCOL-TAKE-SNAPSHOT                                     #
#****************************************************************************************************#

data_folder=/root/data
blocks_folder=$data_folder/blocks
snapshots_folder=$data_folder/snapshots
state_history_folder=$data_folder/state-history
compressed_folder=$snapshots_folder/compressed/

#****************************************************************************************************#
#                                    SCRIPT CONFIGURATION VARIABLES                                  #
#****************************************************************************************************#

sh_create=$snapshots_folder/compress_and_send_lastsnapshot.sh
sh_create_full=$snapshots_folder/compress_and_send_lastsnapshot_full.sh
sh_create_fullstate=$snapshots_folder/compress_and_send_lastsnapshot_fullstate.sh

#****************************************************************************************************#
#                                     REMOTE SERVER PARAMETERS                                       #
#****************************************************************************************************#

remote_server_folder=/var/www/html/snapshots
remote_user=root@ore.remblock.io

#****************************************************************************************************#
#                                          MISC PARAMETERS                                           #
#****************************************************************************************************#

ssh_port=18990
test_blocks=0
chain_stopped=0
test_snapshot=0
test_state_history=0
the_hour=$(date +"%-H")
date_name=$(date +%Y-%m-%d_%H-%M)
file_name="$compressed_folder$date_name"

#----------------------------------------------------------------------------------------------------#
# CREATE THE DIRECTORY IF IT DOES NOT EXIST                                                          #
#----------------------------------------------------------------------------------------------------#

mkdir -p $compressed_folder
chmod +x $compressed_folder

#****************************************************************************************************#
#                                      TAKE SNAPSHOT OF CHAIN                                        #
#****************************************************************************************************#

#----------------------------------------------------------------------------------------------------#
# RUN EVERY 3 HOURS A DAY BY MODIFY THE HOUR BY 3                                                    #
#----------------------------------------------------------------------------------------------------#

if [[ $(($the_hour%3)) -eq 0 ]] || [[ $test_snapshot -eq 1 ]]
then
  echo ""
  echo "Snapshot is about to start the hour is $the_hour"
  echo ""
  snapname=$(curl http://127.0.0.1:8888/v1/producer/create_snapshot | jq '.snapshot_name')
  rm -f $sh_create
  touch $sh_create && chmod +x $sh_create
  echo "tar -Scvzf $file_name-snaponly.tar.gz $snapname" >> $sh_create
  echo "Compression of the Snapshot has completed"
  echo ""
  echo "ssh -i ~/.ssh/id_rsa -p $ssh_port $remote_user 'find $remote_server_folder -name \"*.gz\" -type f -size -1000k -delete 2> /dev/null'" >> $sh_create
  echo "ssh -i ~/.ssh/id_rsa -p $ssh_port $remote_user 'ls -F $remote_server_folder/*.gz | head -n -8 | xargs -r rm 2> /dev/null'" >> $sh_create
  echo "rsync -rv -e 'ssh -i ~/.ssh/id_rsa -p $ssh_port' --progress $file_name-snaponly.tar.gz $remote_user:$remote_server_folder" >> $sh_create
  $sh_create
  echo "Transfer of the Snapshot has completed"
  echo ""
else
  echo ""
  echo "Warning: Snapshot is not due yet skipping"
  echo ""
fi

#****************************************************************************************************#
#                                     CHECK IRREVERSIBLE BLOCKS                                      #
#****************************************************************************************************#

#----------------------------------------------------------------------------------------------------#
# RUN TWICE A DAY BY MOD THE HOUR BY 12                                                              #
#----------------------------------------------------------------------------------------------------#

if [[ $(($the_hour%12)) -eq 0 ]] || [[ $test_blocks -eq 1 ]]
then
  echo "Blocks Logs is about to start the hour is $the_hour"
  echo ""
  echo "Get Head and Irreversible Block Numbers:"
  echo ""
  head_block_num=$(cleos get info | jq '.head_block_num')
  last_irr_block_num=$(cleos get info | jq '.last_irreversible_block_num')

#----------------------------------------------------------------------------------------------------#
# NOW WE WAIT FOR LAST IRREVERSIBLE BLOCK TO PASS OUR TAKEN SNAPSHOT                                 #
#----------------------------------------------------------------------------------------------------#

  while [ $last_irr_block_num -le $head_block_num ]
  do
    last_irr_block_num=$(cleos get info | jq '.last_irreversible_block_num')
    ans=$(($head_block_num-$last_irr_block_num))
    echo "Last Irreversible Block reached in $ans blocks"
    echo ""
    sleep 10
  done
  echo "Last Irreversible Block number has been reached, time to stop the chain"
  echo ""

#----------------------------------------------------------------------------------------------------#
# GRACEFULLY STOP ORE-PROTOCOL                                                                       #
#----------------------------------------------------------------------------------------------------#

  nodeos_pid=$(pgrep nodeos)
  if [ ! -z "$nodeos_pid" ]; then
  if ps -p $nodeos_pid > /dev/null; then
    kill -SIGINT $nodeos_pid
  fi
  while ps -p $nodeos_pid > /dev/null; do
   sleep 1
  done
fi

chain_stopped=1

#****************************************************************************************************#
#                                    COMPRESSING NODEOS BLOCKS                                       #
#****************************************************************************************************#

  rm -f $sh_create_full
  touch $sh_create_full && chmod +x $sh_create_full
  echo "tar -Scvzf $file_name-blockslog.tar.gz $blocks_folder/blocks.log $blocks_folder/blocks.index" >> $sh_create_full
  echo "Compression of the Blocks Log has completed"
  echo ""

#****************************************************************************************************#
#                                    TRANSFERING NODEOS BLOCKS                                       #
#****************************************************************************************************#

  echo "ssh -i ~/.ssh/id_rsa -p $ssh_port $remote_user 'find $remote_server_folder/blocks -name \"*.gz\" -type f -size -1000k -delete 2> /dev/null'" >> $sh_create_full
  echo "ssh -i ~/.ssh/id_rsa -p $ssh_port $remote_user 'ls -F $remote_server_folder/blocks/*.gz | head -n -1 | xargs -r rm 2> /dev/null'" >> $sh_create_full
  echo "rsync -rv -e 'ssh -i ~/.ssh/id_rsa -p $ssh_port $remote_user' --progress $file_name-blockslog.tar.gz $remote_user:$remote_server_folder/blocks" >> $sh_create_full
  $sh_create_full
  echo "Transfer of the Blocks Log has completed"
  echo ""
else
  echo "Warning: Blocks Log is not due yet skipping"
  echo ""
fi

#****************************************************************************************************#
#                                   COMPRESSING NODEOS FULL STATE                                    #
#****************************************************************************************************#

#----------------------------------------------------------------------------------------------------#
# RUN TWICE A DAY BY MOD THE HOUR BY 12                                                              #
#----------------------------------------------------------------------------------------------------#

if [[ $(($the_hour%24)) -eq 0 ]] || [[ $test_state_history -eq 1 ]]
then
  echo "State Histroy is about to start the hour is $the_hour"
  echo ""
  rm -f $sh_create_fullstate
  touch $sh_create_fullstate && chmod +x $sh_create_fullstate
  echo "tar -Scvzf $file_name-state_history.tar.gz $state_history_folder" >> $sh_create_fullstate
  echo "Compression of the State History has completed"
  echo ""

#****************************************************************************************************#
#                                    TRANSFERING NODEOS BLOCKS                                       #
#****************************************************************************************************#

  echo "ssh -i ~/.ssh/id_rsa -p $ssh_port $remote_user 'find $remote_server_folder/state-history -name \"*.gz\" -type f -size -1000k -delete 2> /dev/null'" >> $sh_create_fullstate
  echo "ssh -i ~/.ssh/id_rsa -p $ssh_port $remote_user 'ls -F $remote_server_folder/state-history/*.gz | head -n -1 | xargs -r rm 2> /dev/null'" >> $sh_create_fullstate
  echo "rsync -rv -e 'ssh -i ~/.ssh/id_rsa -p $ssh_port' --progress $file_name-state_history.tar.gz $remote_user:$remote_server_folder/state-history" >> $sh_create_fullstate
  $sh_create_fullstate
  echo "Transfer of the State History has now completed"
  echo ""
else
  echo "Warning: State History is not due yet skipping"
  echo ""
fi

#****************************************************************************************************#
#                                    SNAPSHOT CLEAN UP PROCESS                                       #
#****************************************************************************************************#

rm -f $sh_create 2> /dev/null
rm -f $sh_create_full 2> /dev/null
rm -R $blocks_folder/*.gz 2> /dev/null
rm -f $sh_create_fullstate 2> /dev/null
rm -R $snapshots_folder/*.gz 2> /dev/null
rm -R $snapshots_folder/*.bin 2> /dev/null
rm -R $compressed_folder/*.gz 2> /dev/null
rm -R $state_history_folder/*.gz 2> /dev/null

#****************************************************************************************************#
#                                  START NODEOS IN THE BACKGROUND                                    #
#****************************************************************************************************#

if [[ $chain_stopped -eq 1 ]]
then
  cd ~
  nodeos  --config-dir ./config/ --disable-replay-opts --data-dir ./data/ >> nodeos.log 2>&1 &
  echo ""
  echo "Started ORE-Protocol !!!"
  echo ""
fi
