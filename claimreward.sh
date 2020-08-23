#!/bin/bash

#****************************************************************************************************#
#                                     ORE-PROTOCOL-CLAIM-REWARD                                      #
#****************************************************************************************************#

#----------------------------------------------------------------------------------------------------#
# IF THE USER HAS NO ROOT PERMISSIONS THE SCRIPT WILL EXIT                                           #
#----------------------------------------------------------------------------------------------------#

if (($EUID!=0))
then
  echo "You must be root to run this script" 2>&1
  exit 1
fi

#****************************************************************************************************#
#                                   SCRIPT CONFIGURATION VARIABLES                                   #
#****************************************************************************************************#

#----------------------------------------------------------------------------------------------------#
# CREATE AUTOBOT DIRECTORY                                                                           #
#----------------------------------------------------------------------------------------------------#

create_dir="/root/remblock/autobot"

#----------------------------------------------------------------------------------------------------#
# CREATE AUTOBOT CONFIG FILE                                                                         #
#----------------------------------------------------------------------------------------------------#

config_file="/root/remblock/autobot/config"

#----------------------------------------------------------------------------------------------------#
# MINUTES TO WAIT BETWEEN EACH EXECUTIONS OF THE SCRIPT                                              #
#----------------------------------------------------------------------------------------------------#

minutes_to_wait=1442

#----------------------------------------------------------------------------------------------------#
# INITIATE BOOLEAN VARIABLES FOR THE AUTOBOT SCRIPT                                                  #
#----------------------------------------------------------------------------------------------------#

auto_reward=true
send_message=false
reward_failed=false
auto_reward_alert=false

#----------------------------------------------------------------------------------------------------#
# CHECK IF THE REQUIRED PACKAGES WERE INSTALLED, IF NOT INSTALL THEM                                 #
#----------------------------------------------------------------------------------------------------#

if ! dpkg -l | awk '{print $2}' | grep -w at &>/dev/null
then
  echo "at package was not installed, installing it now..."
  apt-get install at -y
fi
if ! dpkg -l | awk '{print $2}' | grep -w bc &>/dev/null
then
  echo "bc package was not installed, installing it now..."
  apt-get install bc -y
fi

#----------------------------------------------------------------------------------------------------#
# CHECK IF THE AT CONDITION IS ENABLE TO AVOID PRINTING ANY OUTPUT                                   #
#----------------------------------------------------------------------------------------------------#

at=false
if [[ "$1" == "--at" ]]
then
  at=true
  at now + $minutes_to_wait minutes << DOC &>/dev/null
  /root/claimreward.sh --at
DOC
fi

#----------------------------------------------------------------------------------------------------#
# CREATE THE DIRECTORY IF IT DOES NOT EXIST                                                          #
#----------------------------------------------------------------------------------------------------#

if [ ! -d "$create_dir" ]
then
  mkdir -p "$create_dir"
fi

#----------------------------------------------------------------------------------------------------#
# CREATE THE CONFIG FILE IF IT DOES NOT EXIST                                                        #
#----------------------------------------------------------------------------------------------------#

if [ ! -f "$config_file" ]
then
  echo "#Configuration file for the claim reward script" > "$config_file"
  echo "#Make the entries as variable=value" >> "$config_file"
  echo  >> "$config_file"
fi

#****************************************************************************************************#
#                                       SCRIPT PROGRAM FUNCTIONS                                     #
#****************************************************************************************************#

function get_user_answer_yn(){
  while :
  do
    read -p "$1 [y/n]: " answer
    answer="$(echo $answer | tr '[:upper:]' '[:lower:]')"
    case "$answer" in
      yes|y) return 0 ;;
      no|n) return 1 ;;
      *) echo  "Invalid Answer [yes/y/no/n expected]";continue;;
    esac
  done
}

#----------------------------------------------------------------------------------------------------#
# GLOBAL VALUE IS USED AS A GLOBAL VARIABLE TO RETURN THE RESULT                                     #
#----------------------------------------------------------------------------------------------------#

function get_config_value(){
  global_value=$(grep -v '^#' "$config_file" | grep "^$1=" | awk -F '=' '{print $2}')
  if [ -z "$global_value" ]
  then
    return 1
  else
    return 0
  fi
}

#****************************************************************************************************#
#                                  CONFIG CONFIGURATION VARIABLES                                    #
#****************************************************************************************************#

#----------------------------------------------------------------------------------------------------#
# ASK USER FOR THEIR OWNER ACCOUNT NAME OR TAKE IT FROM THE CONFIG FILE                              #
#----------------------------------------------------------------------------------------------------#

if get_config_value accountname
then
  accountname="$global_value"
else
  if $at
  then
    exit 2
  fi
  accountname=$(cat config/config.ini | grep 'producer-name' | awk '{print $3}')
  if [ ! -z "$accountname" ]
  then
    echo "accountname=$accountname" >> "$config_file"
  fi
fi
if [ -z "$accountname" ]
then
  echo ""
  read -p "ENTER YOUR ACCOUNT NAME: " -e accountname
  echo "accountname=$accountname" >> "$config_file"
fi

#----------------------------------------------------------------------------------------------------#
# ASK USER FOR THEIR WALLET PASSWORD OR TAKE IT FROM THE CONFIG FILE                                 #
#----------------------------------------------------------------------------------------------------#

if get_config_value walletpass
then
  walletpass="$global_value"
else
  if $at
  then
    exit 2
  fi
  walletpass=$(cat walletpass)
  if [ ! -z "$walletpass" ]
  then
    echo "walletpass=$walletpass" >> "$config_file"
  fi
fi
if [ -z "$walletpass" ]
then
  echo ""
  read -p "ENTER YOUR WALLET PASSWORD: " -e walletpass
  echo "walletpass=$walletpass" >> "$config_file"
fi

#----------------------------------------------------------------------------------------------------#
# GET AUTOMATED REWARDS ANSWER FROM THE USER OR TAKE IT FROM THE CONFIG FILE                         #
#----------------------------------------------------------------------------------------------------#

if get_config_value auto_reward
then
  if [ "$global_value" = "true" ]
  then
    auto_reward=true
  fi
else
  if $at
  then
    exit 2
  fi
  if get_user_answer_yn "DO YOU WANT AUTOBOT TO AUTO CLAIM YOUR REWARDS"
  then
    auto_reward=true
    echo "auto_reward=true" >> "$config_file"
  else
    echo "auto_reward=false" >> "$config_file"
  fi
  echo
fi

#----------------------------------------------------------------------------------------------------#
# GET REWARD NOTIFCATION ANSWER FROM THE USER OR TAKE IT FROM THE CONFIG FILE                        #
#----------------------------------------------------------------------------------------------------#

if $auto_reward
then
  if get_config_value claim_permission
  then
    claim_permission="$global_value"
else
  if $at
   then
     exit 2
   fi
   read -p "ENTER YOUR CLAIM REWARD KEY PERMISSION: " -e claim_permission
   if [ -z "$claim_permission" ]
   then
     claim_permission="owner"
   fi
   echo "claim_permission=$claim_permission" >> "$config_file"
   echo
 fi
 if get_config_value auto_reward_alert
 then
   if [ "$global_value" = "true" ]
   then
     auto_reward_alert=true
   fi
 else
   if get_user_answer_yn "DO YOU WANT TO RECEIVE REWARD NOTIFICATIONS"
   then
     auto_reward_alert=true
     echo "auto_reward_alert=true" >> "$config_file"
   else
     echo "auto_reward_alert=false" >> "$config_file"
   fi
    echo
 fi
 
 #----------------------------------------------------------------------------------------------------#
# GET TELEGRAM TOKEN FROM THE USER OR TAKE IT FROM THE CONFIG FILE                                   #
#----------------------------------------------------------------------------------------------------#

if $auto_reward_alert
then
  if get_config_value telegram_token
  then
    telegram_token="$global_value"
  else
    if $at
    then
      exit 2
    fi
    read -p "COPY AND PASTE YOUR TELEGRAM TOKEN: " -e telegram_token
    echo "telegram_token=$telegram_token" >> "$config_file"
    echo
  fi

#----------------------------------------------------------------------------------------------------#
# GET TELEGRAM CHAT ID FROM THE USER OR TAKE IT FROM THE CONFIG FILE                                 #
#----------------------------------------------------------------------------------------------------#

  if get_config_value telegram_chatid
  then
    telegram_chatid="$global_value"
  else
    if $at
    then
      exit 2
    fi
    read -p "COPY AND PASTE YOUR TELEGRAM CHAT ID: " -e telegram_chatid
    echo "telegram_chatid=$telegram_chatid" >> "$config_file"
    echo
  fi
fi

#----------------------------------------------------------------------------------------------------#
# CLEOS COMMANDS FOR UNLOCKING YOUR WALLET                                                           #
#----------------------------------------------------------------------------------------------------#

cleos wallet unlock --password $walletpass > /dev/null 2>&1

#----------------------------------------------------------------------------------------------------#
# CLEOS COMMAND FOR CLAIMING YOUR REWARDS                                                            #
#----------------------------------------------------------------------------------------------------#

previous=$(cleos get currency balance eosio.token $accountname | awk '{print $1}')
rewardoutput=$(cleos system claimrewards $accountname -x 120 -p $accountname@$claim_permission -f 2>&1)
if [[ ! "$rewardoutput" =~ "executed transaction" ]]; then reward_failed=true; fi
sleep 120
after=$(cleos get currency balance eosio.token $accountname | awk '{print $1}')
total_reward=$(echo "scale=4; $after - $previous" | bc)
claimamount=$(echo "$total_reward" | awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}')

#----------------------------------------------------------------------------------------------------#
# PREPARE NOTIFICATION TO SEND TO TELEGRAM                                                           #
#----------------------------------------------------------------------------------------------------#

if [ ! -z "$telegram_chatid" ]
then
  telegram_message="
--------------------------------------
Daily Summary
--------------------------------------
Date: $(date +"%d-%m-%Y")
Account Name: "${accountname^}""
  if $auto_reward_alert
  then
    if $reward_failed
    then
      telegram_message="$telegram_message
--------------------------------------
Claimed Rewards
--------------------------------------
Failed"
      send_message=true
    else
      telegram_message="$telegram_message
--------------------------------------
Claimed Rewards
--------------------------------------
$claimamount ORE"
      send_message=true
    fi
  fi

#----------------------------------------------------------------------------------------------------#
# SEND ALERT NOTIFICATIONS TO TELEGRAM BOT (IF THERE'S SOMETHING TO SEND)                            #
#----------------------------------------------------------------------------------------------------#

  if $send_message
  then
    curl -s -X POST https://api.telegram.org/bot$telegram_token/sendMessage -d chat_id=$telegram_chatid -d text="$telegram_message" &>/dev/null
  fi
fi
