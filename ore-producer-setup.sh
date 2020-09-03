#!/bin/bash

#****************************************************************************************************#
#                                     ORE-PROTOCOL-PRODUCER-SETUP                                    #
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

producer=remblock21bp
domain=ore.api.remblock.io
create_ssh_dir=/root/.ssh
create_data_dir=/root/data
state_dir=/root/data/state
contact=contact@remblock.io
blocks_dir=/root/data/blocks
create_config_dir=/root/config
nodeos_log_file=/root/nodeos.log
config_file=/root/config/config.ini
create_snapshot_dir=/root/data/snapshots
bp_public_key=EOS6yscG41Q39rkYKJ61DtYeYdCW7kaETsfnYgQCq2wcu5mzGLyi5
bp_private_key=
ssh_public_key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC5govVMkNP5HyBQ+DBWSbUe97qyKVzoI5s1lR+x1HCSdetS8dacN6e86eWaWNUQBBr6O0AttbXULqxvOBNF1GzWFw0T1jFr9lCtuz2Y06KGjJBHRHXopeSp6VHJr+BG4Q4l9fzguYO/EmQf9Y48eCXCs4eFkKE6mFlfGkNvRInpz6bbRvwYOFEEKiTyLXE6y1910dVrgLTd2P1kyh88aCwuF4GnexM4AsipzKpSCR3/s/gqxK4YpW8KsMBCdcQMYHZ2dgxoscudcp2l88hgnQJOriYOfjAnXSKttaGNRsER/hEcKGKJsRPELJZLCn+Ahv322GTsnTRMvipfXUtDqoTdpteM5lSz+GlUe6get+O501kTz9xF9aMK7fJdj264mzj8JfvxKsZFKfsDJvTkoIV8GPdzSk5fYr8W+lFzrNXKqHBeR8+WXdVYKIq8l6Y3NOCUcf6I+kYeHPKOAqkl8mSue2Q9GPGTn8z3tAg1ASuNxFQCqhcDCyF4RcZzVMfTO6tTe56Udt/mOr2QRb6C8+wI4YK9l6Un+S6MLAt1EQZyHEm/uI0Cv4SIvh2X4ksZLEgNNAcw63MxEOLnUiGacrhKG1v4qixtjaZITkc0M518J43FK8157q0DJwbMDQCOLCWyqoytRYNhfdNvTc6sefJBJOMqKbUwGxvrZue9T6BnQ== root@REMBLOCK"

#----------------------------------------------------------------------------------------------------#
# CREATE DIRECTORY IF IT DOESN'T EXIST                                                               #
#----------------------------------------------------------------------------------------------------#

if [ ! -d "$create_data_dir" -o -d "$create_config_dir" -o -d "$create_snapshot_dir" ]
then
  mkdir -p $create_ssh_dir
  mkdir -p $create_data_dir
  mkdir -p $create_config_dir
  mkdir -p $create_snapshot_dir
fi

#----------------------------------------------------------------------------------------------------#
# CHANGE HOSTNAME FROM DEFAULT                                                                       #
#----------------------------------------------------------------------------------------------------#

sudo hostnamectl set-hostname ore.bp1.remblock

#----------------------------------------------------------------------------------------------------#
# INSTALLING EOS PROTOCOL BINARIES                                                                   #
#----------------------------------------------------------------------------------------------------#

wget https://github.com/eosio/eos/releases/download/v2.0.7/eosio_2.0.7-1-ubuntu-18.04_amd64.deb
sudo apt install ./eosio_2.0.7-1-ubuntu-18.04_amd64.deb -y
rm ./eosio_2.0.7-1-ubuntu-18.04_amd64.deb

#----------------------------------------------------------------------------------------------------#
# FETCHING ORE PROTOCOL GENESIS.JSON                                                                 #
#----------------------------------------------------------------------------------------------------#

wget https://raw.githubusercontent.com/Open-Rights-Exchange/ore-bp-docs/master/config-templates/genesis.json

#----------------------------------------------------------------------------------------------------#
# SET SERVER TIMEZONE TO UTC                                                                         #
#----------------------------------------------------------------------------------------------------#

sudo timedatectl set-timezone UTC

#----------------------------------------------------------------------------------------------------#
# GET YES OR NO ANSWER FROM USER                                                                     #
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
# CONFIGURATION FILE (CONFIG/CONFIG.INI)                                                             #
#----------------------------------------------------------------------------------------------------#

echo -e "#------------------------------------------------------------------------------#" > $config_file
echo -e "# EOSIO PLUGINS                                                                #" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "\nplugin = eosio::net_plugin\nplugin = eosio::http_plugin\nplugin = eosio::chain_plugin\nplugin = eosio::net_api_plugin\nplugin = eosio::producer_plugin\nplugin = eosio::chain_api_plugin\n" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "# CONFIG SETTINGS                                                              #" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "\nmax-clients = 50\nchain-threads = 8\nsync-fetch-span = 200\neos-vm-oc-enable = false\npause-on-startup = false\nwasm-runtime = eos-vm-jit\nmax-transaction-time = 30\nverbose-http-errors = true\nkeosd-provider-timeout = 5\ntxn-reference-block-lag = 0\neos-vm-oc-compile-threads = 8\nconnection-cleanup-period = 30\nchain-state-db-size-mb = 100480\nenable-stale-production = false\nmax-irreversible-block-age = -1\nhttp-server-address = 0.0.0.0:80\nhttps-server-address = 0.0.0.0:443\np2p-listen-endpoint = 0.0.0.0:9876\nreversible-blocks-db-size-mb = 10480\n" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "# PRODUCER SETTINGS                                                            #" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "\nproducer-name = $producer\nsignature-provider = $bp_public_key=KEY:$bp_private_key\n" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "# ORE PROTOCOL P2P PEER ADDRESSES                                              #" >> $config_file
echo -e "#------------------------------------------------------------------------------#\n" >> $config_file
wget https://github.com/remblock/ORE-Protocol/raw/master/ore-peer-list.ini
cat /root/ore-peer-list.ini >> $config_file
echo -e "\n#-------------------------------------------------------------------------------" >> $config_file

#----------------------------------------------------------------------------------------------------#
# DOMAIN | INSTALL AND INIT SSL CERTIFCATE                                                           #
#----------------------------------------------------------------------------------------------------#

cd ~
if [ "$ssl_certificate_path" ] || [ "$ssl_private_key_path" ]
then
  ssl_certificate_path=$(certbot certificates | grep 'Certificate Path:' | awk '{print $3}')
  ssl_private_key_path=$(certbot certificates | grep 'Private Key Path:' | awk '{print $4}')
fi
if [ -z "$ssl_certificate_path" ] || [ -z "$ssl_private_key_path" ]
then
  if get_user_answer_yn "CREATE A NEW SSL CERTIFCATE?"
  then
    sudo apt-get install software-properties-common -y
    sudo add-apt-repository universe
    sudo add-apt-repository ppa:certbot/certbot -y
    sudo apt-get update
    sudo apt-get install certbot -y
    sudo certbot certonly --standalone --agree-tos --noninteractive --preferred-challenges http --email $contact --domains $domain
    ssl_certificate_path=$(certbot certificates | grep 'Certificate Path:' | awk '{print $3}')
    ssl_private_key_path=$(certbot certificates | grep 'Private Key Path:' | awk '{print $4}')
    echo "https-private-key-file = $ssl_private_key_path" >> $config_file
    echo "https-certificate-chain-file = $ssl_certificate_path" >> $config_file
    echo -e "\n#-------------------------------------------------------------------------------\n" >> $config_file
  else
    echo ""
    read -p "ENTER YOUR SSL CERTIFCATE PATH: " -e ssl_certificate_path
    echo ""
    read -p "ENTER YOUR SSL PRIVATE KEY PATH: " -e ssl_private_key_path
    echo ""
    echo "https-private-key-file = $ssl_private_key_path" >> $config_file
    echo "https-certificate-chain-file = $ssl_certificate_path" >> $config_file
    echo -e "\n#-------------------------------------------------------------------------------\n" >> $config_file
 fi
fi
if [ ! -z "$ssl_certificate_path" ] || [ ! -z "$ssl_private_key_path" ]
then
  ssl_certificate_path=$(certbot certificates | grep 'Certificate Path:' | awk '{print $3}')
  ssl_private_key_path=$(certbot certificates | grep 'Private Key Path:' | awk '{print $4}')
  echo -e "\nhttps-private-key-file = $ssl_private_key_path" >> $config_file
  echo -e "https-certificate-chain-file = $ssl_certificate_path" >> $config_file
  echo -e "\n#-------------------------------------------------------------------------------\n" >> $config_file
fi

#----------------------------------------------------------------------------------------------------#
# UPDATING AND UPGRADING PACKAGE DATABASE                                                            #
#----------------------------------------------------------------------------------------------------#

sudo apt install linux-tools-common -y
sudo apt install linux-cloud-tools-generic -y
sudo apt install linux-tools-4.15.0-112-generic -y
sudo apt install linux-cloud-tools-4.15.0-112-generic -y
sudo -S apt update -y && sudo -S apt upgrade -y

#----------------------------------------------------------------------------------------------------#
# CHANGING DEFAULT SSH PORT NUMBER                                                                   #
#----------------------------------------------------------------------------------------------------#

while [ : ]
do
         echo ""
	 read -p "PLEASE ENTER A RANDOM 5 DIGIT PORT NUMBER: " portnumber

         if [[ ${#portnumber} -ne 5 ]]
         then
                 printf "\nERROR: PORT NUMBER SHOULD BE EXACTLY 5 DIGITS.\n\n"
                 continue
         elif [[ ! -z "${portnumber//[0-9]}" ]]
         then
                 printf "\nERROR: PORT NUMBER SHOULD CONTAIN NUMBERS ONLY.\n\n"
                 continue
         else
                 sudo -S sed -i "/^#Port 22/s/#Port 22/Port $portnumber/" /etc/ssh/sshd_config && sed -i '/^PermitRootLogin/s/yes/without-password/' /etc/ssh/sshd_config && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
		 echo ""
		 break
         fi
done

#----------------------------------------------------------------------------------------------------#
# INSTALLING UNCOMPLICATED FIREWALL                                                                  #
#----------------------------------------------------------------------------------------------------#

sudo -S apt-get install ufw -y
sudo -S ufw allow ssh/tcp
sudo -S ufw limit ssh/tcp
sudo -S ufw allow $portnumber/tcp
sudo -S ufw allow 8888/tcp
sudo -S ufw allow 9876/tcp
sudo -S ufw logging on
sudo -S ufw enable

#----------------------------------------------------------------------------------------------------#
# INSTALLING FAIL2BAN                                                                                #
#----------------------------------------------------------------------------------------------------#

sudo -S apt install fail2ban -y
sudo -S systemctl enable fail2ban
sudo -S systemctl start fail2ban

#----------------------------------------------------------------------------------------------------#
# INSTALLING CANONICAL LIVEPATCH SERVICE                                                             #
#----------------------------------------------------------------------------------------------------#

sudo apt install snapd -y
sudo snap install canonical-livepatch

#----------------------------------------------------------------------------------------------------#
# SETUP GRACEFUL SHUTDOWN                                                                            #
#----------------------------------------------------------------------------------------------------#

echo '#!/bin/sh
nodeos_pid=$(pgrep nodeos)
if [ ! -z "$nodeos_pid" ]; then
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
# RESTORE FROM SNAPSHOT                                                                              #
#----------------------------------------------------------------------------------------------------#

sudo wget https://github.com/remblock/ORE-Protocol/raw/master/ore-restore-snapshot.sh
sudo chmod u+x ore-restore-snapshot.sh
sudo ./ore-restore-snapshot.sh

#----------------------------------------------------------------------------------------------------#
# CREATING ORE PROTOCOL WALLET                                                                       #
#----------------------------------------------------------------------------------------------------#

cleos wallet create -n walletpass --file walletpass

#----------------------------------------------------------------------------------------------------#
# ADDING SSH PUBLIC KEY TO SERVER                                                                    #
#----------------------------------------------------------------------------------------------------#

echo $ssh_public_key > ~/.ssh/id_rsa.pub
cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys
sudo -S service sshd restart
rm /root/ore-peer-list.ini
rm /root/ore-producer-setup.sh
rm /root/ore-restore-snapshot.sh
echo ""
echo "================================"
echo "ORE PRODUCER SETUP HAS COMPLETED"
echo "================================"
echo ""
