#!/bin/bash

# Warna untuk output teks
GREEN="\e[1m\e[1;32m"
RED="\e[1m\e[1;31m"
BLUE='\033[0;34m'
NC="\e[0m"
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
ORANGE='\033[0;33m'
PINK='\033[1;35m'

# URL untuk mengunduh snapshot
SNAPSHOT_URL="https://snapshot.sipalingtestnet.com/symphony/symphony.tar.lz4"

# Path untuk menyimpan dan mengekstrak snapshot
SNAPSHOT_PATH="$HOME/.symphonyd"
SNAPSHOT_FILE="$SNAPSHOT_PATH/symphony.tar.lz4"

# Seed nodes untuk bootstrap jaringan
SEEDS="0bec7d2970be72fd1e8352141a46da3a0398c498@2a01:4f9:6b:2099::2:12656"

# Peer nodes untuk sinkronisasi jaringan
PEERS="$(curl -sS https://rpc.symphony.sipalingtestnet.com/net_info | jq -r '.result.peers[] | "\(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr)"' | awk -F ':' '{print $1":"$(NF)}' | sed -z 's|\n|,|g;s|.$||')"
GENESIS="https://snapshot.sipalingtestnet.com/symphony/genesis.json"
ADDR="https://snapshot.sipalingtestnet.com/symphony/addrbook.json"

# Export ke environment variables
export SNAPSHOT_URL
export SNAPSHOT_PATH
export SNAPSHOT_FILE
export SEEDS
export PEERS
export GENESIS
export ADDR

# Fungsi untuk mencetak logo (printLogo dan printLine diambil dari common.sh)
source <(curl -s https://raw.githubusercontent.com/sipalingtestnet/komponenporto/main/logo.sh)

# Input dari pengguna
printLogo
echo -e "${CYAN}Enter WALLET name:${NC}"
read -p "" WALLET
echo 'export WALLET='$WALLET
echo -e "${CYAN}Enter your MONIKER:${NC}"
read -p "" MONIKER
echo 'export MONIKER='$MONIKER
echo -e "${CYAN}Enter your PORT (for example 17, default port=26):${NC}"
read -p "" PORT
echo 'export PORT='$PORT

# Set variabel lingkungan
echo "export WALLET=\"$WALLET\"" >> $HOME/.bash_profile
echo "export MONIKER=\"$MONIKER\"" >> $HOME/.bash_profile
echo "export SYMPHONY_CHAIN_ID=\"symphony-testnet-3\"" >> $HOME/.bash_profile
echo "export SYMPHONY_PORT=\"$PORT\"" >> $HOME/.bash_profile
source $HOME/.bash_profile

printLine
echo -e "${YELLOW}Moniker:${NC}        ${GREEN}$MONIKER${NC}"
echo -e "${YELLOW}Wallet:${NC}         ${GREEN}$WALLET${NC}"
echo -e "${YELLOW}Chain id:${NC}       ${GREEN}$SYMPHONY_CHAIN_ID${NC}"
echo -e "${YELLOW}Node custom port:${NC}  ${GREEN}$SYMPHONY_PORT${NC}"
printLine
sleep 1


printGreen "1. Install Pack" && sleep 1
sudo apt update
sudo apt install curl git wget htop tmux build-essential jq make lz4 gcc unzip -y

# Instalasi Go
printGreen "2. Installing Go..." && sleep 1
cd $HOME
VER="1.22.3"
wget "https://golang.org/dl/go$VER.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$VER.linux-amd64.tar.gz"
rm "go$VER.linux-amd64.tar.gz"
[ ! -f ~/.bash_profile ] && touch ~/.bash_profile
echo "export PATH=\$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
source $HOME/.bash_profile
[ ! -d ~/go/bin ] && mkdir -p ~/go/bin

echo $(go version) && sleep 1




# Instalasi binary
printGreen "3. Installing binary" && sleep 1
cd $HOME
rm -rf symphony
git clone https://github.com/Orchestra-Labs/symphony symphony
cd symphony
git checkout v0.3.0
make install
echo done

# Konfigurasi dan inisialisasi aplikasi
printGreen "4. Configuring and init app..." && sleep 1
symphonyd init $MONIKER --chain-id $SYMPHONY_CHAIN_ID
sed -i -e "s|^node *=.*|node = \"tcp://localhost:${SYMPHONY_PORT}657\"|" $HOME/.symphonyd/config/client.toml
sed -i -e "s|^keyring-backend *=.*|keyring-backend = \"os\"|" $HOME/.symphonyd/config/client.toml
sed -i -e "s|^chain-id *=.*|chain-id = \"$SYMPHONY_CHAIN_ID\"|" $HOME/.symphonyd/config/client.toml
sleep 1
echo done

# Unduh genesis dan addrbook
printGreen "5. Downloading genesis and addrbook..." && sleep 1
curl -Ls $GENESIS > $HOME/.symphonyd/config/genesis.json
curl -Ls $ADDR > $HOME/.symphonyd/config/addrbook.json
sleep 1
echo done

# Tambahkan seeds, peers, konfigurasi port custom, pruning, dan gas price minimum
printGreen "6. Adding seeds, peers, configuring custom ports, pruning, minimum gas price..." && sleep 1
sed -i.bak -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.symphonyd/config/config.toml

# Set custom ports di app.toml
sed -i.bak -e "s%:1317%:${SYMPHONY_PORT}317%g;
s%:8080%:${SYMPHONY_PORT}080%g;
s%:9090%:${SYMPHONY_PORT}090%g;
s%:9091%:${SYMPHONY_PORT}091%g;
s%:8545%:${SYMPHONY_PORT}545%g;
s%:8546%:${SYMPHONY_PORT}546%g;
s%:6065%:${SYMPHONY_PORT}065%g" $HOME/.symphonyd/config/app.toml

# Set custom ports di config.toml
sed -i.bak -e "s%:26658%:${SYMPHONY_PORT}658%g;
s%:26657%:${SYMPHONY_PORT}657%g;
s%:6060%:${SYMPHONY_PORT}060%g;
s%:26656%:${SYMPHONY_PORT}656%g;
s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${SYMPHONY_PORT}656\"%;
s%:26660%:${SYMPHONY_PORT}660%g" $HOME/.symphonyd/config/config.toml

# Konfigurasi pruning
sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.symphonyd/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.symphonyd/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" $HOME/.symphonyd/config/app.toml

# Set minimum gas price, aktifkan prometheus, dan nonaktifkan indexing
sed -i 's|minimum-gas-prices =.*|minimum-gas-prices = "0.25note"|g' $HOME/.symphonyd/config/app.toml
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.symphonyd/config/config.toml
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.symphonyd/config/config.toml
sleep 1
echo done

# Buat service file
sudo tee /etc/systemd/system/symphonyd.service > /dev/null <<EOF
[Unit]
Description=symphony node
After=network-online.target
[Service]
User=$USER
WorkingDirectory=$HOME/.symphonyd
ExecStart=$(which symphonyd) start --home $HOME/.symphonyd
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

# Unduh snapshot dan mulai node
printGreen "7. Downloading snapshot and starting node..." && sleep 1
symphonyd tendermint unsafe-reset-all --home $HOME/.symphonyd
if curl -sI $SNAPSHOT_URL | grep -q '200 OK'; then
  curl -L $SNAPSHOT_URL | tar -Ilz4 -xf - -C $SNAPSHOT_PATH
else
  echo -e "${RED}Failed to download snapshot. Starting node without snapshot.${NC}"
fi

# Mulai service dan cek status
sudo systemctl daemon-reload
sudo systemctl enable symphonyd
sudo systemctl restart symphonyd

printGreen "8. Check service logs..." && sleep 1
sudo journalctl -u symphonyd -f --no-hostname -o cat
