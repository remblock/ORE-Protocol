#!/bin/bash

#****************************************************************************************************#
#                                       ORE-BP1-MAINNET-SETUP                                        #
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

country_code=554
producer=remblock21bp
wallet_name=walletpass
create_ssh_dir=/root/.ssh
create_data_dir=/root/data
new_hostname=ore-bp1-mainnet
create_config_dir=/root/config
nodeos_log_file=/root/nodeos.log
bp_json=https://bp.remblock.io/ore
config_file=/root/config/config.ini
create_snapshot_dir=/root/data/snapshots
owner_private_key=
owner_public_key=EOS53J3bUWyCHTVWtwGDjSMY2XxPauvuw3o4jwdVGKfPUtkE3m2g1
ssh_public_key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC5govVMkNP5HyBQ+DBWSbUe97qyKVzoI5s1lR+x1HCSdetS8dacN6e86eWaWNUQBBr6O0AttbXULqxvOBNF1GzWFw0T1jFr9lCtuz2Y06KGjJBHRHXopeSp6VHJr+BG4Q4l9fzguYO/EmQf9Y48eCXCs4eFkKE6mFlfGkNvRInpz6bbRvwYOFEEKiTyLXE6y1910dVrgLTd2P1kyh88aCwuF4GnexM4AsipzKpSCR3/s/gqxK4YpW8KsMBCdcQMYHZ2dgxoscudcp2l88hgnQJOriYOfjAnXSKttaGNRsER/hEcKGKJsRPELJZLCn+Ahv322GTsnTRMvipfXUtDqoTdpteM5lSz+GlUe6get+O501kTz9xF9aMK7fJdj264mzj8JfvxKsZFKfsDJvTkoIV8GPdzSk5fYr8W+lFzrNXKqHBeR8+WXdVYKIq8l6Y3NOCUcf6I+kYeHPKOAqkl8mSue2Q9GPGTn8z3tAg1ASuNxFQCqhcDCyF4RcZzVMfTO6tTe56Udt/mOr2QRb6C8+wI4YK9l6Un+S6MLAt1EQZyHEm/uI0Cv4SIvh2X4ksZLEgNNAcw63MxEOLnUiGacrhKG1v4qixtjaZITkc0M518J43FK8157q0DJwbMDQCOLCWyqoytRYNhfdNvTc6sefJBJOMqKbUwGxvrZue9T6BnQ== root@REMBLOCK"

#----------------------------------------------------------------------------------------------------#
# CREATE DIRECTORIES IF THEY DON'T EXIST                                                             #
#----------------------------------------------------------------------------------------------------#

if [ ! -d "$create_data_dir" -o -d "$create_config_dir" -o -d "$create_snapshot_dir" ]
then
  mkdir -p $create_ssh_dir
  mkdir -p $create_data_dir
  mkdir -p $create_config_dir
  mkdir -p $create_snapshot_dir
fi

#----------------------------------------------------------------------------------------------------#
# ADJUSTING SERVER HOSTNAME                                                                          #
#----------------------------------------------------------------------------------------------------#

old_hostname=$(hostname)
sudo hostnamectl set-hostname $new_hostname
sed -i "s/$old_hostname/$new_hostname/g" /etc/hosts

#----------------------------------------------------------------------------------------------------#
# UPDATING AND UPGRADING PACKAGE DATABASE                                                            #
#----------------------------------------------------------------------------------------------------#

sudo -S apt update -y && sudo -S apt upgrade -y
sudo apt install linux-tools-common -y
sudo apt install linux-cloud-tools-generic -y
sudo apt install linux-tools-4.15.0-115-generic -y
sudo apt install linux-cloud-tools-4.15.0-115-generic -y

#----------------------------------------------------------------------------------------------------#
# INSTALLING CANONICAL LIVEPATCH SERVICE                                                             #
#----------------------------------------------------------------------------------------------------#

sudo apt install snapd -y
sudo snap install canonical-livepatch

#----------------------------------------------------------------------------------------------------#
# FETCHING THE TELOS TESTNET GENESIS.JSON AND SNAPSHOT                                               #
#----------------------------------------------------------------------------------------------------#

wget https://github.com/remblock/ORE-Protocol/raw/master/ore-claim-rewards.sh
wget https://github.com/remblock/ORE-Protocol/raw/master/ore-restore-snapshot.sh
wget https://raw.githubusercontent.com/Open-Rights-Exchange/ore-bp-docs/master/config-templates/genesis.json

#----------------------------------------------------------------------------------------------------#
# ADJUSTING SERVER TIMEZONE TO UTC                                                                   #
#----------------------------------------------------------------------------------------------------#

sudo timedatectl set-timezone UTC

#----------------------------------------------------------------------------------------------------#
# FETCHING YES OR NO ANSWER FROM USER                                                                #
#----------------------------------------------------------------------------------------------------#

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
# CHANGING DEFAULT SSH PORT NUMBER                                                                   #
#----------------------------------------------------------------------------------------------------#

while [ : ]
do
	 read -p "PLEASE ENTER A RANDOM 5 DIGIT PORT NUMBER: " port

         if [[ ${#port} -ne 5 ]]
         then
                 printf "\nERROR: PORT NUMBER SHOULD BE EXACTLY 5 DIGITS.\n\n"
                 continue
         elif [[ ! -z "${port//[0-9]}" ]]
         then
                 printf "\nERROR: PORT NUMBER SHOULD CONTAIN NUMBERS ONLY.\n\n"
                 continue
         else
                 sudo -S sed -i "/^#Port 22/s/#Port 22/Port $port/" /etc/ssh/sshd_config && sed -i '/^PermitRootLogin/s/yes/without-password/' /etc/ssh/sshd_config && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
		 echo ""
		 break
         fi
done

#----------------------------------------------------------------------------------------------------#
# SETUP GRACEFUL SHUTDOWN                                                                            #
#----------------------------------------------------------------------------------------------------#

echo '#!/bin/sh
nodeos_pid=$(pgrep nodeos)
if [ ! -z "$nodeos_pid" ]; then
cleos wallet unlock -n walletpass < walletpass > /dev/null 2>&1
cleos system unregprod remblock21bp
sleep 10
if ps -p $nodeos_pid > /dev/null; then
kill -SIGINT $nodeos_pid
fi
while ps -p $nodeos_pid > /dev/null; do
sleep 1
done
fi
' > /root/node_shutdown.sh
echo '[Unit]
Description=Gracefully shut down nodeos to avoid database dirty flag
DefaultDependencies=no
After=poweroff.target shutdown.target reboot.target halt.target kexec.target
Requires=network-online.target network.target
[Service]
Type=oneshot
ExecStop=/root/node_shutdown.sh
RemainAfterExit=yes
KillMode=none
[Install]
WantedBy=multi-user.target' > /etc/systemd/system/node_shutdown.service
sudo chmod +x /root/node_shutdown.sh
systemctl daemon-reload
systemctl enable node_shutdown
systemctl restart node_shutdown

#----------------------------------------------------------------------------------------------------#
# RESTART ALL PROCESSES ON REBOOT                                                                    #
#----------------------------------------------------------------------------------------------------#

echo '#!/bin/bash
data_dir=/root/data
config_dir=/root/config
nodeos_log_file=/root/nodeos.log
sudo resize2fs /dev/nvme1n1
cpupower frequency-set --governor performance
sudo nodeos --config-dir $config_dir --data-dir $data_dir >> $nodeos_log_file 2>&1 &
exit 0' > /etc/rc.local

sudo chmod +x /etc/rc.local

#----------------------------------------------------------------------------------------------------#
# INSTALLING EOSIO PROTOCOL BINARIES                                                                 #
#----------------------------------------------------------------------------------------------------#

wget https://github.com/eosio/eos/releases/download/v2.0.7/eosio_2.0.7-1-ubuntu-18.04_amd64.deb
sudo apt install ./eosio_2.0.7-1-ubuntu-18.04_amd64.deb -y

#----------------------------------------------------------------------------------------------------#
# CREATING ORE MAINNET WALLET                                                                        #
#----------------------------------------------------------------------------------------------------#

cleos wallet create -n $wallet_name --file $wallet_name
walletpass=$(cat $wallet_name)

#----------------------------------------------------------------------------------------------------#
# IMPORTING YOUR ORE OWNER KEY                                                                       #
#----------------------------------------------------------------------------------------------------#

cleos wallet lock -n $wallet_name > /dev/null 2>&1
cleos wallet unlock -n $wallet_name --password=$walletpass > /dev/null 2>&1
cleos wallet import -n $wallet_name --private-key=$owner_private_key

#----------------------------------------------------------------------------------------------------#
# CREATING YOUR ORE ACTIVE KEY                                                                       #
#----------------------------------------------------------------------------------------------------#

cleos create key --file active_key
cp active_key active_key1
echo "Active Keys:" > ore_keys.txt
echo "" >> ore_keys.txt
cat active_key >> ore_keys.txt
sudo -S sed -i "/^Private key: /s/Private key: //" active_key1 && sudo -S sed -i "/^Public key: /s/Public key: //" active_key1
active_public_key=$(head -n 2 active_key1 | tail -1)
active_private_key=$(head -n 1 active_key1 | tail -1)
cleos wallet lock -n $wallet_name > /dev/null 2>&1
cleos wallet unlock -n $wallet_name --password=$walletpass > /dev/null 2>&1
cleos wallet import -n $wallet_name --private-key=$active_private_key

#----------------------------------------------------------------------------------------------------#
# CREATING YOUR ORE SIGNATURE KEY                                                                    #
#----------------------------------------------------------------------------------------------------#

cleos create key --file signature_key
cp signature_key signature_key1
echo "" >> ore_keys.txt
echo "Signature Keys:" >> ore_keys.txt
echo "" >> ore_keys.txt
cat signature_key >> ore_keys.txt
sudo -S sed -i "/^Private key: /s/Private key: //" signature_key1 && sudo -S sed -i "/^Public key: /s/Public key: //" signature_key1
signature_public_key=$(head -n 2 signature_key1 | tail -1)
signature_private_key=$(head -n 1 signature_key1 | tail -1)
cleos wallet lock -n $wallet_name > /dev/null 2>&1
cleos wallet unlock -n $wallet_name --password=$walletpass > /dev/null 2>&1
cleos wallet import -n $wallet_name --private-key=$signature_private_key

#----------------------------------------------------------------------------------------------------#
# CREATING YOUR ORE PRODUCER KEY                                                                     #
#----------------------------------------------------------------------------------------------------#

cleos create key --file producer_key
cp producer_key producer_key1
echo "" >> ore_keys.txt
echo "Producer Keys:" >> ore_keys.txt
echo "" >> ore_keys.txt
cat producer_key >> ore_keys.txt
sudo -S sed -i "/^Private key: /s/Private key: //" producer_key1 && sudo -S sed -i "/^Public key: /s/Public key: //" producer_key1
producer_public_key=$(head -n 2 producer_key1 | tail -1)
producer_private_key=$(head -n 1 producer_key1 | tail -1)
cleos wallet lock -n $wallet_name > /dev/null 2>&1
cleos wallet unlock -n $wallet_name --password=$walletpass > /dev/null 2>&1
cleos wallet import -n $wallet_name --private-key=$producer_private_key

#----------------------------------------------------------------------------------------------------#
# CONFIGURATION FILE (CONFIG/CONFIG.INI)                                                             #
#----------------------------------------------------------------------------------------------------#

echo -e "#------------------------------------------------------------------------------#" > $config_file
echo -e "# EOSIO PLUGINS                                                                #" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "\nplugin = eosio::chain_plugin\nplugin = eosio::net_api_plugin\nplugin = eosio::producer_plugin\nplugin = eosio::chain_api_plugin\n" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "# CONFIG SETTINGS                                                              #" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "\nchain-threads = 8\neos-vm-oc-enable = true\npause-on-startup = false\nwasm-runtime = eos-vm-jit\nmax-transaction-time = 30\nkeosd-provider-timeout = 5\neos-vm-oc-compile-threads = 8\nchain-state-db-size-mb = 100480\nenable-stale-production = false\nmax-irreversible-block-age = -1\nchain-state-db-guard-size-mb = 128\nreversible-blocks-db-size-mb = 10480\nreversible-blocks-db-guard-size-mb = 2\n" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "# PRODUCER SETTINGS                                                            #" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "\nagent-name = $producer\nproducer-name = $producer\nsignature-provider = $signature_public_key=KEY:$signature_private_key\n" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "# ORE MAINNET P2P PEER ADDRESSES                                               #" >> $config_file
echo -e "#------------------------------------------------------------------------------#\n" >> $config_file
wget https://github.com/remblock/ORE-Protocol/raw/master/ore-testnet-peer-list.ini
cat /root/ore-testnet-peer-list.ini >> $config_file
echo -e "\n#-------------------------------------------------------------------------------\n" >> $config_file

#----------------------------------------------------------------------------------------------------#
# RESTORING ORE MAINNET SNAPSHOT                                                                     #
#----------------------------------------------------------------------------------------------------#

sudo chmod u+x ore-restore-snapshot.sh
sudo ./ore-restore-snapshot.sh

#----------------------------------------------------------------------------------------------------#
# CREATING ORE KEY PERMISSIONS                                                                       #
#----------------------------------------------------------------------------------------------------#

cleos wallet lock -n $wallet_name > /dev/null 2>&1
cleos wallet unlock -n $wallet_name --password=$walletpass > /dev/null 2>&1
cleos set account permission $producer active $active_public_key -x 120 -p $producer@owner
cleos set account permission $producer producer $producer_public_key active -x 120 -p $producer@owner
cleos set action permission $producer eosio unregprod NULL -x 120 -p $producer@owner > /dev/null 2>&1
cleos set action permission $producer eosio claimrewards NULL -x 120 -p $producer@owner > /dev/null 2>&1
cleos set action permission $producer eosio voteproducer NULL -x 120 -p $producer@owner > /dev/null 2>&1
cleos set action permission $producer eosio unregprod producer -x 120 -p $producer@owner
cleos set action permission $producer eosio claimrewards producer -x 120 -p $producer@owner
cleos set action permission $producer eosio voteproducer producer -x 120 -p $producer@owner

#----------------------------------------------------------------------------------------------------#
# REGISTER ORE MAINNET PRODUCER                                                                      #
#----------------------------------------------------------------------------------------------------#

cleos wallet lock -n $wallet_name > /dev/null 2>&1
cleos wallet unlock -n $wallet_name --password=$walletpass > /dev/null 2>&1
cleos system regproducer $producer $signature_public_key $bp_json $country_code -x 120 -p $producer@active

#----------------------------------------------------------------------------------------------------#
# REMOVING OWNER AND ACTIVE KEYS                                                                     #
#----------------------------------------------------------------------------------------------------#

cleos wallet lock -n $wallet_name > /dev/null 2>&1
cleos wallet unlock -n $wallet_name --password=$walletpass > /dev/null 2>&1
cleos wallet remove_key -n $wallet_name $owner_public_key --password=$walletpass
cleos wallet remove_key -n $wallet_name $active_public_key --password=$walletpass

#----------------------------------------------------------------------------------------------------#
# INSTALLING UNCOMPLICATED FIREWALL                                                                  #
#----------------------------------------------------------------------------------------------------#

sudo -S apt-get install ufw -y
sudo -S ufw allow ssh/tcp
sudo -S ufw limit ssh/tcp
sudo -S ufw allow 8888/tcp
sudo -S ufw allow 9876/tcp
sudo -S ufw allow $port/tcp
sudo -S ufw logging on
sudo -S ufw enable

#----------------------------------------------------------------------------------------------------#
# INSTALLING FAIL2BAN                                                                                #
#----------------------------------------------------------------------------------------------------#

sudo -S apt install fail2ban -y
sudo -S systemctl enable fail2ban
sudo -S systemctl start fail2ban

#----------------------------------------------------------------------------------------------------#
# CLEANUP INSTALLATION FILES                                                                         #
#----------------------------------------------------------------------------------------------------#

rm /root/active_key
rm /root/active_key1
rm /root/producer_key
rm /root/producer_key1
rm /root/signature_key
rm /root/signature_key1
rm /root/ore-bp1-mainnet.sh
rm /root/ore-mainnet-peer-list.ini
rm /root/eosio_2.0.7-1-ubuntu-18.04_amd64.deb

#----------------------------------------------------------------------------------------------------#
# ADDING SSH PUBLIC KEY TO SERVER                                                                    #
#----------------------------------------------------------------------------------------------------#

echo $ssh_public_key > ~/.ssh/id_rsa.pub
cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys
sudo -S service sshd restart
echo ""
echo "====================================="
echo "ORE-BP1-MAINNET SETUP HAS COMPLETED"
echo "====================================="
echo ""
