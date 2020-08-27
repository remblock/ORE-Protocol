#!/bin/bash

#****************************************************************************************************#
#                                     ORE-PROTOCOL-TAKE-SNAPSHOT                                     #
#****************************************************************************************************#

datafolder=/root/data
statehistoryfolder=$datafolder/state-history
blocksfolder=$datafolder/blocks
snapshotsfolder=$datafolder/snapshots
compressedfolder=$snapshotsfolder/compressed/

#****************************************************************************************************#
#                                    SCRIPT CONFIGURATION VARIABLES                                  #
#****************************************************************************************************#

shcreate=$snapshotsfolder/compressandsendlastsnapshot.sh
shcreatefull=$snapshotsfolder/compressandsendlastsnapshot_full.sh
shcreatefullstate=$snapshotsfolder/compressandsendlastsnapshot_fullstate.sh

#****************************************************************************************************#
#                                     REMOTE SERVER PARAMETERS                                       #
#****************************************************************************************************#

remote_server_folder=/var/www/geordier.co.uk/snapshots
remote_user=root@website.geordier.co.uk

#****************************************************************************************************#
#                                          MISC PARAMETERS                                           #
#****************************************************************************************************#

sshport=22
testblocks=0
chainstopped=0
testsnapshot=0
teststatehistory=0
thehour=$(date +"%-H")
datename=$(date +%Y-%m-%d_%H-%M)
filename="$compressedfolder$datename"

#----------------------------------------------------------------------------------------------------#
# CREATE THE DIRECTORY IF IT DOES NOT EXIST                                                          #
#----------------------------------------------------------------------------------------------------#

mkdir -p $compressedfolder
chmod +x $compressedfolder

#****************************************************************************************************#
#                                      TAKE SNAPSHOT OF CHAIN                                        #
#****************************************************************************************************#

#----------------------------------------------------------------------------------------------------#
# RUN EVERY 3 HOURS A DAY BY MODIFY THE HOUR BY 3                                                    #
#----------------------------------------------------------------------------------------------------#

if [[ $(($thehour%3)) -eq 0 ]] || [[ $testsnapshot -eq 1 ]]
then
  echo "# Snapshot Only Start. Hour is $thehour #"
  snapname=$(curl http://127.0.0.1:8888/v1/producer/create_snapshot | jq '.snapshot_name')
  rm -f $shcreate
  touch $shcreate && chmod +x $shcreate
  echo "tar -Scvzf $filename-snaponly.tar.gz $snapname" >> $shcreate
  echo "ssh -p $sshportno $remote_user 'find $remote_server_folder -name \"*.gz\" -type f -size -1000k -delete'" >> $shcreate
  echo "ssh -p $sshportno $remote_user 'ls -F $remote_server_folder/*.gz | head -n -8 | xargs -r rm'" >> $shcreate
  echo "rsync -rv -e 'ssh -p $sshportno' --progress $filename-snaponly.tar.gz $remote_user:$remote_server_folder" >> $shcreate
  echo "Sending snapshot only..."
  $shcreate
else
  echo "Snapshot is not due..Aborting"
fi

#****************************************************************************************************#
#                                     CHECK IRREVERSIBLE BLOCKS                                      #
#****************************************************************************************************#

#----------------------------------------------------------------------------------------------------#
# RUN TWICE A DAY BY MOD THE HOUR BY 12                                                              #
#----------------------------------------------------------------------------------------------------#

if [[ $(($thehour%12)) -eq 0 ]] || [[ $testblocks -eq 1 ]]
then
  echo "Get Head and Irreversible Block Numbers"
  head_block_num=$(remcli get info | jq '.head_block_num')
  last_irr_block_num=$(remcli get info | jq '.last_irreversible_block_num')
  
#----------------------------------------------------------------------------------------------------#
# NOW WE WAIT FOR LAST IRREVERSIBLE BLOCK TO PASS OUR SNAPSHOT TAKEN                                 #
#----------------------------------------------------------------------------------------------------#

while [ $last_irr_block_num -le $head_block_num ]
do
last_irr_block_num=$(remcli get info | jq '.last_irreversible_block_num')
ans=$(($head_block_num-$last_irr_block_num))
        echo "Last Irreversible Block Reached In $ans Blocks"
        sleep 10
done
echo "Last Irreversible Block Number Passed - Great, lets stop the chain now"
~/stop.sh
chainstopped=1

#****************************************************************************************************#
#                                    COMPRESSING NODEOS BLOCKS                                       #
#****************************************************************************************************#

echo "#Blocks Log Start #"
rm -f $shcreatefull
touch $shcreatefull && chmod +x $shcreatefull
echo "tar -Scvzf $filename-blockslog.tar.gz $blocksfolder/blocks.log $blocksfolder/blocks.index" >> $shcreatefull

#****************************************************************************************************#
#                                    TRANSFERING NODEOS BLOCKS                                       #
#****************************************************************************************************#

echo "ssh -p $sshportno $remote_user 'find $remote_server_folder/blocks -name \"*.gz\" -type f -size -1000k -delete'" >> $shcreate
echo "ssh -p $sshportno $remote_user 'ls -F $remote_server_folder/blocks/*.gz | head -n -1 | xargs -r rm'" >> $shcreatefull
echo "rsync -rv -e 'ssh -p $sshportno' --progress $filename-blockslog.tar.gz $remote_user:$remote_server_folder/blocks" >> $shcreatefull
echo "Sending blocks..."
$shcreatefull
else
echo "Blocks Log is not due..Aborting"
fi

#****************************************************************************************************#
#                                   COMPRESSING NODEOS FULL STATE                                    #
#****************************************************************************************************#

#Run twice a day by MOD the hour by 12
if [[ $(($thehour%24)) -eq 0 ]] || [[ $teststatehistory -eq 1 ]]
then
  echo "#State History Start #"
  rm -f $shcreatefullstate
  touch $shcreatefullstate && chmod +x $shcreatefullstate
  echo "tar -Scvzf $filename-statehistory.tar.gz $statehistoryfolder  " >> $shcreatefullstate

#****************************************************************************************************#
#                                    TRANSFERING NODEOS BLOCKS                                       #
#****************************************************************************************************#

echo "ssh -p $sshportno $remote_user 'find $remote_server_folder/state-history -name \"*.gz\" -type f -size -1000k -delete'" >> $shcreate
echo "ssh -p $sshportno $remote_user 'ls -F $remote_server_folder/state-history/*.gz | head -n -1 | xargs -r rm'" >> $shcreatefullstate
echo "rsync -rv -e 'ssh -p $sshportno' --progress $filename-statehistory.tar.gz $remote_user:$remote_server_folder/state-history" >> $shcreatefullstate
echo "Sending state history..."
$shcreatefullstate
else
echo "State History is not due...Aborting"
fi

#****************************************************************************************************#
#                                    SNAPSHOT CLEAN UP PROCESS                                       #
#****************************************************************************************************#

echo "Cleaning Up..."
rm -f $shcreate
rm -f $shcreatefull
rm -f $shcreatefullstate
rm -R $snapshotsfolder/*.gz
rm -R $snapshotsfolder/*.bin
rm -R $compressedfolder/*.gz
rm -R $statehistoryfolder/*.gz
rm -R $blocksfolder/*.gz

#****************************************************************************************************#
#                                  START NODEOS IN THE BACKGROUND                                    #
#****************************************************************************************************#

if [[ $chainstopped -eq 1 ]]
then
echo "Starting chain..."
cd ~
./start.sh
fi
echo "We are done"
