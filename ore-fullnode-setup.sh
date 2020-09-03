#!/bin/bash

#****************************************************************************************************#
#                                    ORE-PROTOCOL-FULLNODE-SETUP                                     #
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

portnumber=18990
domain=ore.remblock.io
contact=contact@remblock.io
ssh_public_key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC5govVMkNP5HyBQ+DBWSbUe97qyKVzoI5s1lR+x1HCSdetS8dacN6e86eWaWNUQBBr6O0AttbXULqxvOBNF1GzWFw0T1jFr9lCtuz2Y06KGjJBHRHXopeSp6VHJr+BG4Q4l9fzguYO/EmQf9Y48eCXCs4eFkKE6mFlfGkNvRInpz6bbRvwYOFEEKiTyLXE6y1910dVrgLTd2P1kyh88aCwuF4GnexM4AsipzKpSCR3/s/gqxK4YpW8KsMBCdcQMYHZ2dgxoscudcp2l88hgnQJOriYOfjAnXSKttaGNRsER/hEcKGKJsRPELJZLCn+Ahv322GTsnTRMvipfXUtDqoTdpteM5lSz+GlUe6get+O501kTz9xF9aMK7fJdj264mzj8JfvxKsZFKfsDJvTkoIV8GPdzSk5fYr8W+lFzrNXKqHBeR8+WXdVYKIq8l6Y3NOCUcf6I+kYeHPKOAqkl8mSue2Q9GPGTn8z3tAg1ASuNxFQCqhcDCyF4RcZzVMfTO6tTe56Udt/mOr2QRb6C8+wI4YK9l6Un+S6MLAt1EQZyHEm/uI0Cv4SIvh2X4ksZLEgNNAcw63MxEOLnUiGacrhKG1v4qixtjaZITkc0M518J43FK8157q0DJwbMDQCOLCWyqoytRYNhfdNvTc6sefJBJOMqKbUwGxvrZue9T6BnQ== root@REMBLOCK"

#----------------------------------------------------------------------------------------------------#

create_ssh_dir=/root/.ssh
create_data_dir=/root/data
state_dir=/root/data/state
blocks_dir=/root/data/blocks
create_config_dir=/root/config
nodeos_log_file=/root/nodeos.log
create_certs_dir=/root/data/certs
config_file=/root/config/config.ini
genesis_json_file=/root/genesis.json
create_rocksdb_dir=/root/data/rocksdb
create_shpdata_dir=/root/data/shpdata
create_snapshot_dir=/root/data/snapshots

#----------------------------------------------------------------------------------------------------#
# CREATE DIRECTORY IF IT DOESN'T EXIST                                                               #
#----------------------------------------------------------------------------------------------------#

if [ ! -d "$create_data_dir" -o -d "$create_config_dir" -o -d "$create_rocksdb_dir" -o -d "$create_shpdata_dir" -o -d "$create_snapshot_dir" ]
then
  mkdir -p $create_ssh_dir
  mkdir -p $create_data_dir
  mkdir -p $create_certs_dir
  mkdir -p $create_config_dir
  mkdir -p $create_rocksdb_dir
  mkdir -p $create_shpdata_dir
  mkdir -p $create_snapshot_dir
fi

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
# CREATE CONFIG.INI FILE & CHANGING SSH PORT NUMBER                                                  #
#----------------------------------------------------------------------------------------------------#

echo -e "#-------------------------------------------------------------------------------" > $config_file
echo -e "\nplugin = eosio::net_plugin\nplugin = eosio::chain_plugin\n\nhttp-server-address = 0.0.0.0:8888\n" >> $config_file
echo -e "#-------------------------------------------------------------------------------" >> $config_file
echo -e "\nchain-threads = 8\ntrace-history = true\neos-vm-oc-enable = true\nwasm-runtime = eos-vm-jit\nchain-state-history = true\nverbose-http-errors = true\nhttp-validate-host = false\neos-vm-oc-compile-threads = 8\nhttp-max-response-time-ms = 100\nchain-state-db-size-mb = 100480\nhttp-server-address = 0.0.0.0:80\nhttps-server-address = 0.0.0.0:443\np2p-listen-endpoint = 0.0.0.0:9876\nabi-serializer-max-time-ms = 15000\nstate-history-endpoint = 0.0.0.0:8080\nstate-history-dir = /root/data/shpdata\n" >> $config_file
echo -e "#-------------------------------------------------------------------------------\n" >> $config_file
wget https://github.com/remblock/ORE-Protocol/raw/master/ore-peer-list.ini
cat /root/ore-peer-list.ini >> $config_file
echo -e "\n#-------------------------------------------------------------------------------" >> $config_file
sudo -S sed -i "/^#Port 22/s/#Port 22/Port $portnumber/" /etc/ssh/sshd_config && sed -i '/^PermitRootLogin/s/yes/without-password/' /etc/ssh/sshd_config && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

#----------------------------------------------------------------------------------------------------#
# INSTALLING PROTOCOL BINARIES                                                                       #
#----------------------------------------------------------------------------------------------------#

cd ~
sudo -S apt update -y && sudo -S apt upgrade -y
wget https://github.com/EOSIO/eos/releases/download/v2.0.7/eosio_2.0.7-1-ubuntu-18.04_amd64.deb
sudo apt install -y ./eosio_2.0.7-1-ubuntu-18.04_amd64.deb
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
# RESTORE FROM SNAPSHOT                                                                              #
#----------------------------------------------------------------------------------------------------#

sudo wget https://github.com/remblock/ORE-Protocol/raw/master/ore-restore-snapshot.sh
sudo chmod u+x ore-restore-snapshot.sh
sudo ./ore-restore-snapshot.sh

#----------------------------------------------------------------------------------------------------#
# CREATE API CONFIG.INI FILE                                                                         #
#----------------------------------------------------------------------------------------------------#

echo -e "#-------------------------------------------------------------------------------" > $config_file
echo -e "\nplugin = eosio::net_plugin\nplugin = eosio::http_plugin\nplugin = eosio::chain_plugin\nplugin = eosio::net_api_plugin\nplugin = eosio::chain_api_plugin\nplugin = eosio::state_history_plugin\n" >> $config_file
echo -e "#-------------------------------------------------------------------------------" >> $config_file
echo -e "\nchain-threads = 8\ntrace-history = true\neos-vm-oc-enable = true\nwasm-runtime = eos-vm-jit\nchain-state-history = true\nverbose-http-errors = true\nhttp-validate-host = false\neos-vm-oc-compile-threads = 8\nhttp-max-response-time-ms = 100\nchain-state-db-size-mb = 100480\nhttp-server-address = 0.0.0.0:80\nhttps-server-address = 0.0.0.0:443\np2p-listen-endpoint = 0.0.0.0:9876\nabi-serializer-max-time-ms = 15000\nstate-history-endpoint = 0.0.0.0:8080\nstate-history-dir = /root/data/shpdata\n" >> $config_file
echo -e "#-------------------------------------------------------------------------------\n" >> $config_file
cat /root/ore-peer-list.ini >> $config_file
echo -e "\n#-------------------------------------------------------------------------------\n" >> $config_file

#----------------------------------------------------------------------------------------------------#
# GRACEFULLY STOP ORE PROTOCOL                                                                       #
#----------------------------------------------------------------------------------------------------#

nodeos_pid=$(pgrep nodeos)

if [ ! -z "$nodeos_pid" ];
then
  if ps -p $nodeos_pid > /dev/null;
  then
    kill -SIGINT $nodeos_pid
  fi
  while ps -p $nodeos_pid > /dev/null; do
    sleep 1
  done
fi

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
# START NODEOS IN THE BACKGROUND                                                                     #
#----------------------------------------------------------------------------------------------------#

nodeos --config-dir $create_config_dir --data-dir $create_data_dir --state-history-dir $create_shpdata_dir --disable-replay-opts >> $nodeos_log_file 2>&1 &

#----------------------------------------------------------------------------------------------------#
# INSTALL CLANG 8 AND OTHER NEEDED TOOLS                                                             #
#----------------------------------------------------------------------------------------------------#

apt update -y && apt install -y wget gnupg
wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -

cat <<EOT >>/etc/apt/sources.list
deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic main
deb-src http://apt.llvm.org/bionic/ llvm-toolchain-bionic main
deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic-8 main
deb-src http://apt.llvm.org/bionic/ llvm-toolchain-bionic-8 main
EOT

sudo -S apt update -y && sudo -S apt upgrade -y \
    autoconf2.13        \
    build-essential     \
    bzip2               \
    cargo               \
    clang-8             \
    git                 \
    libgmp-dev          \
    libpq-dev           \
    lld-8               \
    lldb-8              \
    ninja-build         \
    nodejs              \
    npm                 \
    pkg-config          \
    postgresql-server-dev-all \
    python2.7-dev       \
    python3-dev         \
    rustc               \
    zlib1g-dev

update-alternatives --install /usr/bin/clang clang /usr/bin/clang-8 100
update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-8 100

#----------------------------------------------------------------------------------------------------#
# INSTALL BOOST 1.70                                                                                 #
#----------------------------------------------------------------------------------------------------#

cd ~
wget https://dl.bintray.com/boostorg/release/1.70.0/source/boost_1_70_0.tar.gz
tar xf boost_1_70_0.tar.gz
cd boost_1_70_0
./bootstrap.sh
./b2 toolset=clang -j10 install

#----------------------------------------------------------------------------------------------------#
# INSTALL CMAKE 3.14.5                                                                               #
#----------------------------------------------------------------------------------------------------#

cd ~
wget https://github.com/Kitware/CMake/releases/download/v3.14.5/cmake-3.14.5.tar.gz
tar xf cmake-3.14.5.tar.gz
cd cmake-3.14.5
./bootstrap --parallel=10
make -j10
make -j10 install

#----------------------------------------------------------------------------------------------------#
# INSTALL EOSIO CDT 1.6.3                                                                            #
#----------------------------------------------------------------------------------------------------#

cd ~
wget https://github.com/EOSIO/eosio.cdt/releases/download/v1.6.3/eosio.cdt_1.6.3-1-ubuntu-18.04_amd64.deb
sudo apt install -y ./eosio.cdt_1.6.3-1-ubuntu-18.04_amd64.deb

#----------------------------------------------------------------------------------------------------#
# BUILD HISTORY TOOLS                                                                                #
#----------------------------------------------------------------------------------------------------#

cd ~
git clone --recursive https://github.com/EOSIO/history-tools.git
cd history-tools
mkdir build
cd build
cmake -GNinja -DCMAKE_CXX_COMPILER=clang++-8 -DCMAKE_C_COMPILER=clang-8 ..
bash -c "cd ../src && npm install node-fetch"
ninja

#****************************************************************************************************#
#                                     STARTING FULL NODE PROCESSES                                   #
#****************************************************************************************************#

#----------------------------------------------------------------------------------------------------#
# SET ENVIRONMENT VARIABLES                                                                          #
#----------------------------------------------------------------------------------------------------#

nohup ~/history-tools/build/combo-rocksdb --rdb-database $create_rocksdb_dir &> /dev/null &

#----------------------------------------------------------------------------------------------------#
# RESTART ALL PROCESSES ON REBOOT                                                                    #
#----------------------------------------------------------------------------------------------------#

echo '#!/bin/bash

create_data_dir=/root/data
create_config_dir=/root/config
nodeos_log_file=/root/nodeos.log
create_shpdata_dir=/root/data/shpdata

nodeos --config-dir $create_config_dir --data-dir $create_data_dir --state-history-dir $create_shpdata_dir --disable-replay-opts >> $nodeos_log_file 2>&1 &

exit 0' > /etc/rc.local
sudo chmod +x /etc/rc.local

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
Description=Gracefully shut down remnode to avoid database dirty flag
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
# CLEANUP INSTALLATION FILES                                                                         #
#----------------------------------------------------------------------------------------------------#

rm /root/ore-peer-list.ini
rm /root/boost_1_70_0.tar.gz
rm /root/cmake-3.14.5.tar.gz
rm /root/ore-fullnode-setup.sh
rm /root/ore-restore-snapshot.sh
rm /root/eosio.cdt_1.6.3-1-ubuntu-18.04_amd64.deb
echo ""

#----------------------------------------------------------------------------------------------------#
# INSTALLING UNCOMPLICATED FIREWALL                                                                  #
#----------------------------------------------------------------------------------------------------#

sudo -S apt-get install ufw -y
sudo -S ufw allow http
sudo -S ufw allow https
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

sudo -S apt -y install fail2ban
sudo -S systemctl enable fail2ban
sudo -S systemctl start fail2ban

#----------------------------------------------------------------------------------------------------#
# INSTALLING CANONICAL LIVEPATCH SERVICE                                                             #
#----------------------------------------------------------------------------------------------------#

sudo apt install snapd -y
sudo snap install canonical-livepatch

#----------------------------------------------------------------------------------------------------#
# ADDING SSH PUBLIC KEY TO SERVER                                                                    #
#----------------------------------------------------------------------------------------------------#

echo $ssh_public_key > ~/.ssh/id_rsa.pub
cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys
sudo apt install linux-tools-common -y
sudo apt install linux-cloud-tools-generic -y
sudo apt install linux-tools-4.15.0-112-generic -y
sudo apt install linux-cloud-tools-4.15.0-112-generic -y
sudo -S apt update -y && sudo -S apt upgrade -y

#----------------------------------------------------------------------------------------------------#
# START ORE-PROTOCOL                                                                       #
#----------------------------------------------------------------------------------------------------#

nodeos --config-dir $create_config_dir --data-dir $create_data_dir --state-history-dir $create_shpdata_dir --disable-replay-opts >> $nodeos_log_file 2>&1 &
sudo -S service sshd restart
echo ""
echo "================================"
echo "ORE-FULLNODE-SETUP HAS COMPLETED"
echo "================================"
echo ""
