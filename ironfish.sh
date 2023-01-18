#!/bin/bash

while true
do

# Logo

echo -e '\e[40m\e[91m'
echo -e '  ____                  _                    '
echo -e ' / ___|_ __ _   _ _ __ | |_ ___  _ __        '
echo -e '| |   |  __| | | |  _ \| __/ _ \|  _ \       '
echo -e '| |___| |  | |_| | |_) | || (_) | | | |      '
echo -e ' \____|_|   \__  |  __/ \__\___/|_| |_|      '
echo -e '            |___/|_|                         '
echo -e '    _                 _                      '
echo -e '   / \   ___ __ _  __| | ___ _ __ ___  _   _ '
echo -e '  / _ \ / __/ _  |/ _  |/ _ \  _   _ \| | | |'
echo -e ' / ___ \ (_| (_| | (_| |  __/ | | | | | |_| |'
echo -e '/_/   \_\___\__ _|\__ _|\___|_| |_| |_|\__  |'
echo -e '                                       |___/ '
echo -e '\e[0m'

sleep 2

# Menu

PS3='Select an action: '
options=(
"Install"
"Exit")
select opt in "${options[@]}"
do
case $opt in

"Install")
echo "============================================================"
echo "Install start"
echo "============================================================"

exists()
{
  command -v "$1" >/dev/null 2>&1
}

service_exists() {
    local n=$1
    if [[ $(systemctl list-units --all -t service --full --no-legend "$n.service" | sed 's/^\s*//g' | cut -f1 -d' ') == $n.service ]]; then
        return 0
    else
        return 1
    fi
}

if exists curl; then
	echo ''
else
  sudo apt install curl -y < "/dev/null"
fi
unalias ironfish 2>/dev/null
sed -i.bak '/alias ironfish/d' $HOME/.bash_profile 2>/dev/null
bash_profile=$HOME/.bash_profile
if [ -f "$bash_profile" ]; then
    . $HOME/.bash_profile
fi

function setupVars {
	if [ ! $IRONFISH_WALLET ]; then
		read -p "Enter wallet name: " IRONFISH_WALLET
		echo 'export IRONFISH_WALLET='${IRONFISH_WALLET} >> $HOME/.bash_profile
	fi
	echo -e '\n\e[42mYour wallet name:' $IRONFISH_WALLET '\e[0m\n'
	if [ ! $IRONFISH_NODENAME ]; then
		read -p "Enter node name: " IRONFISH_NODENAME
		echo 'export IRONFISH_NODENAME='${IRONFISH_NODENAME} >> $HOME/.bash_profile
	fi
	echo -e '\n\e[42mYour node name:' $IRONFISH_NODENAME '\e[0m\n'
	if [ ! $IRONFISH_THREADS ]; then
		read -e -p "Enter your threads [-1]: " IRONFISH_THREADS
		echo 'export IRONFISH_THREADS='${IRONFISH_THREADS:--1} >> $HOME/.bash_profile
	fi
	echo -e '\n\e[42mYour threads count:' $IRONFISH_THREADS '\e[0m\n'
	echo 'source $HOME/.bashrc' >> $HOME/.bash_profile
	. $HOME/.bash_profile
	sleep 1
}

function installSnapshot {
	systemctl stop ironfishd
#	rm -rf $HOME/.ironfish/databases/default/
	sleep 5
	ironfish chain:download --confirm
	sleep 3
	systemctl restart ironfishd
}

function setupSwap {
	curl -s https://api.nodes.guru/swap4.sh | bash
}

function backupWallet {
	echo -e '\n\e[42mPreparing to backup default wallet...\e[0m\n' && sleep 1
	echo -e '\n\e[42mYou can just press enter if you want backup your default wallet\e[0m\n' && sleep 1
	read -e -p "Enter your wallet name [default]: " IRONFISH_WALLET_BACKUP_NAME
	IRONFISH_WALLET_BACKUP_NAME=${IRONFISH_WALLET_BACKUP_NAME:-default}
	cd $HOME/ironfish/ironfish-cli/
	mkdir -p $HOME/.ironfish/keys
	ironfish accounts:export $IRONFISH_WALLET_BACKUP_NAME $HOME/.ironfish/keys/$IRONFISH_WALLET_BACKUP_NAME.json
	echo -e '\n\e[42mYour key file:\e[0m\n' && sleep 1
	walletBkpPath="$HOME/.ironfish/keys/$IRONFISH_WALLET_BACKUP_NAME.json"
	cat $HOME/.ironfish/keys/$IRONFISH_WALLET_BACKUP_NAME.json
	echo -e "\n\nImport command:"
	echo -e "\e[7mironfish accounts:import $walletBkpPath\e[0m"
	cd $HOME
}

function installDeps {
	cd $HOME
	sudo apt update
	sudo curl https://sh.rustup.rs -sSf | sh -s -- -y
	. $HOME/.cargo/env
#	curl https://deb.nodesource.com/setup_16.x | sudo bash
	curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
	sudo apt install curl make clang pkg-config libssl-dev build-essential git jq nodejs -y < "/dev/null"
	sudo apt install npm 
}

function createConfig {
	mkdir -p $HOME/.ironfish
	echo "{
		\"nodeName\": \"${IRONFISH_NODENAME}\",
		\"blockGraffiti\": \"${IRONFISH_NODENAME}\"
	}" > $HOME/.ironfish/config.json
	systemctl restart ironfishd ironfishd-miner
}

function installSoftware {
	. $HOME/.bash_profile
	. $HOME/.cargo/env
	cd $HOME
	npm install -g ironfish
}

function updateSoftware {
	if service_exists ironfishd-pool; then
		sudo systemctl stop ironfishd-pool
	fi
	sudo systemctl stop ironfishd ironfishd-miner
	sed -i.bak '/alias ironfish/d' $HOME/.bash_profile
	rm -rf $HOME/ironfish $(which ironfish)
	unalias ironfish 2>/dev/null
	. $HOME/.bash_profile
	. $HOME/.cargo/env
	cp -r $HOME/.ironfish/accounts $HOME/ironfish_accounts_$(date +%s)
	cd $HOME
	npm install -g ironfish
	sleep 5
	npm update -g ironfish
}

function installService {
echo "[Unit]
Description=IronFish Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which ironfish) start
Restart=always
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
" > $HOME/ironfishd.service
sudo mv $HOME/ironfishd.service /etc/systemd/system
sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
sudo systemctl enable ironfishd ironfishd-miner
sudo systemctl restart ironfishd ironfishd-miner
. $HOME/.bash_profile
}

break
;;

"Exit")
exit
;;
*) echo "invalid option $REPLY";;
esac
done
done
