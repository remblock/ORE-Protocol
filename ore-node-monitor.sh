#!/bin/bash

#****************************************************************************************************#
#                                        ORE-NODE-MONITOR                                            #
#****************************************************************************************************#

#----------------------------------------------------------------------------------------------------#
# CONFIGURATION VARIABLES                                                                            #
#----------------------------------------------------------------------------------------------------#

producer=remblock21bp
log_file=/root/nodeos.log
telegram_chat_id=704178267
telegram_chat_api=711425317:AAG5nKmZarIlFwhOLSlLN5tYxpKNxTu9iYo

#----------------------------------------------------------------------------------------------------#
# FUNCTION TO TRANSLATE THE TIME FORMAT FROM REMCLI FORMATE TO EPOCH TIME                            #
#----------------------------------------------------------------------------------------------------#

function nodeoslogtime_to_date() {
  temp_date="$( echo $1 | awk -F '.' '{ print $1}' | tr '-' '/' | tr 'T' ' ')"
  echo $(date "+%s" -d "$temp_date")
}

second_date=$(date +%s)

#----------------------------------------------------------------------------------------------------#
# CHECK BLOCK CONDITION                                                                              #
#----------------------------------------------------------------------------------------------------#

last_nodeos_block_date=$(grep $producer $log_file | tail -n1 | awk '{print $2}')
last_block=$(nodeoslogtime_to_date "$last_nodeos_block_date")
block_result=$(expr $second_date - $last_block)
block_minute=$(expr $block_result / 60)
if [[ $block_result -le "300" ]]
then
  echo "" &>/dev/null
else
  curl -s -X POST https://api.telegram.org/bot$telegram_chat_api/sendMessage -d chat_id=$telegram_chat_id -d text="Warning: Stopped producing blocks $block_minute minutes ago on ORE-Protocol." &>/dev/null
fi
