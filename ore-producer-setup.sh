#!/bin/bash

#****************************************************************************************************#
#                                     REMBLOCK-ORE-PRODUCER-SETUP                                    #
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

create_ssh_dir="/root/.ssh"
create_data_dir="/root/data"
state_dir="/root/data/state"
blocks_dir="/root/data/blocks"
create_config_dir="/root/config"
nodeos_log_file="/root/nodeos.log"
config_file="/root/config/config.ini"
create_snapshot_dir="/root/data/snapshots"

#----------------------------------------------------------------------------------------------------#
# CREATE DIRECTORY IF IT DOESN'T EXIST                                                               #
#----------------------------------------------------------------------------------------------------#

if [ ! -d "$create_data_dir" -o -d "$create_config_dir" -o -d "$create_snapshot_dir" ]
then
  mkdir -p "$create_ssh_dir"
  mkdir -p "$create_data_dir"
  mkdir -p "$create_config_dir"
  mkdir -p "$create_snapshot_dir"
fi

#----------------------------------------------------------------------------------------------------#
# CHANGE HOSTNAME FROM DEFAULT                                                                       #
#----------------------------------------------------------------------------------------------------#

sudo hostnamectl set-hostname ore.bp1.remblock

#----------------------------------------------------------------------------------------------------#
# INSTALLING EOS PROTOCOL BINARIES                                                                   #
#----------------------------------------------------------------------------------------------------#

wget https://github.com/eosio/eos/releases/download/v2.0.7/eosio_2.0.7-1-ubuntu-18.04_amd64.deb
sudo apt install ./eosio_2.0.7-1-ubuntu-18.04_amd64.deb
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
# CONFIGURATION FILE (CONFIG/CONFIG.INI)                                                             #
#----------------------------------------------------------------------------------------------------#

echo -e "plugin = eosio::net_plugin\nplugin = eosio::chain_plugin\nplugin = eosio::producer_plugin\nplugin = eosio::chain_api_plugin\n\nhttp-server-address = 0.0.0.0:8888\np2p-peer-address = ore.csx.io:9876\np2p-peer-address = peer.ore.alohaeos.com:9876\np2p-peer-address = peer1-ore.eosphere.io:9876\np2p-peer-address = ore-seed1.openrights.exchange:9876\np2p-peer-address = ore-seed2.openrights.exchange:9876\np2p-peer-address = peer.ore-mainnet.eosblocksmith.io:5060\n\nmax-clients = 50\nchain-threads = 8\nsync-fetch-span = 200\neos-vm-oc-enable = false\npause-on-startup = false\nwasm-runtime = eos-vm-jit\nmax-transaction-time = 30\nverbose-http-errors = true\nkeosd-provider-timeout = 5\ntxn-reference-block-lag = 0\nproducer-name = remblock21bp\neos-vm-oc-compile-threads = 8\nconnection-cleanup-period = 30\nchain-state-db-size-mb = 100480\nenable-stale-production = false\nmax-irreversible-block-age = -1\nreversible-blocks-db-size-mb = 10480\n\nsignature-provider = EOS6yscG41Q39rkYKJ61DtYeYdCW7kaETsfnYgQCq2wcu5mzGLyi5=KEY:" > ./config/config.ini

#----------------------------------------------------------------------------------------------------#
# UPDATING AND UPGRADING PACKAGE DATABASE                                                            #
#----------------------------------------------------------------------------------------------------#

sudo apt install linux-tools-common -y
sudo apt install linux-tools-4.15.0-88-generic -y
sudo -S apt update && sudo -S apt upgrade -y

#----------------------------------------------------------------------------------------------------#
# INSTALL ORE SNAPSHOT DEPENDENCIES                                                                  #
#----------------------------------------------------------------------------------------------------#

sudo apt install curl -y
sudo apt-get install jq -y

#----------------------------------------------------------------------------------------------------#
# CREATING ORE PROTOCOL WALLET                                                                       #
#----------------------------------------------------------------------------------------------------#

cleos wallet create -n walletpass --file walletpass
echo " "
echo " "

#----------------------------------------------------------------------------------------------------#
# CHANGING DEFAULT SSH PORT NUMBER                                                                   #
#----------------------------------------------------------------------------------------------------#

while [ : ]
do

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
remnode_pid=$(pgrep nodeos)
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
sudo resize2fs /dev/nvme1n1
sudo nodeos --config-dir /root/config/ --data-dir /root/data/ >> /root/nodeos.log 2>&1 &
cpupower frequency-set --governor performance
exit 0' > /etc/rc.local
sudo chmod +x /etc/rc.local

#----------------------------------------------------------------------------------------------------#
# ADDING SSH PUBLIC KEY TO SERVER                                                                    #
#----------------------------------------------------------------------------------------------------#

echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC5govVMkNP5HyBQ+DBWSbUe97qyKVzoI5s1lR+x1HCSdetS8dacN6e86eWaWNUQBBr6O0AttbXULqxvOBNF1GzWFw0T1jFr9lCtuz2Y06KGjJBHRHXopeSp6VHJr+BG4Q4l9fzguYO/EmQf9Y48eCXCs4eFkKE6mFlfGkNvRInpz6bbRvwYOFEEKiTyLXE6y1910dVrgLTd2P1kyh88aCwuF4GnexM4AsipzKpSCR3/s/gqxK4YpW8KsMBCdcQMYHZ2dgxoscudcp2l88hgnQJOriYOfjAnXSKttaGNRsER/hEcKGKJsRPELJZLCn+Ahv322GTsnTRMvipfXUtDqoTdpteM5lSz+GlUe6get+O501kTz9xF9aMK7fJdj264mzj8JfvxKsZFKfsDJvTkoIV8GPdzSk5fYr8W+lFzrNXKqHBeR8+WXdVYKIq8l6Y3NOCUcf6I+kYeHPKOAqkl8mSue2Q9GPGTn8z3tAg1ASuNxFQCqhcDCyF4RcZzVMfTO6tTe56Udt/mOr2QRb6C8+wI4YK9l6Un+S6MLAt1EQZyHEm/uI0Cv4SIvh2X4ksZLEgNNAcw63MxEOLnUiGacrhKG1v4qixtjaZITkc0M518J43FK8157q0DJwbMDQCOLCWyqoytRYNhfdNvTc6sefJBJOMqKbUwGxvrZue9T6BnQ== root@REMBLOCK' > ~/.ssh/id_rsa.pub
cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys
echo ""
echo "================================"
echo "ORE-PRODUCER SETUP HAS COMPLETED"
echo "================================"
echo ""
sudo -S service sshd restart
rm ./ore-producer-setup.sh
reboot
