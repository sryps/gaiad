#!/bin/bash
### TESTED WITH UBUNTU 22.04
### Run as root but not best practises - TESTING ONLY

set -e
cd
clear

echo "update packages and install dependencies..."
sudo apt update -y
sudo apt-get install -y make gcc jq git

# INSTALL GOLANG
echo "install go..."
curl -OL https://golang.org/dl/go1.19.3.linux-amd64.tar.gz

sudo tar -C /usr/local -xvf go1.19.3.linux-amd64.tar.gz

echo 'export GOROOT=/usr/local/go' >> ~/.profile
echo 'export GOPATH=$HOME/go' >> ~/.profile
echo 'export PATH=$GOPATH/bin:$GOROOT/bin:$PATH' >> ~/.profile

source ~/.profile
rm go1.19.3.linux-amd64.tar.gz


# INSTALL GAIAD
echo "install gaiad"
cd ~
git clone -b v7.1.0 https://github.com/cosmos/gaia
cd ~/gaia 
make install

gaiad init temp --chain-id temp-1

SEED=ade4d8bc8cbe014af6ebdf3cb7b1e9ad36f412c0@seeds.polkachu.com:14956
sed -i.bak -e "s/^seeds *=.*/seeds = \"$SEED\"/" $HOME/.gaia/config/config.toml

rm ~/.gaia/config/genesis.json
wget https://raw.githubusercontent.com/cosmos/mainnet/master/genesis/genesis.cosmoshub-4.json.gz
gzip -d genesis.cosmoshub-4.json.gz
mv genesis.cosmoshub-4.json ~/.gaia/config/genesis.json

sed -i.bak -E "s|^(pruning[[:space:]]+=[[:space:]]+).*$|\1\"custom\"| ; \
s|^(pruning-keep-every[[:space:]]+=[[:space:]]+).*$|\10| ; \
s|^(minimum-gas-prices[[:space:]]+=[[:space:]]+).*$|\1\"0.002uatom\"| ; \
s|^(pruning-keep-recent[[:space:]]+=[[:space:]]+).*$|\1500| ; \
s|^(pruning-interval[[:space:]]+=[[:space:]]+).*$|\1100| ; \
s|^(snapshot-interval[[:space:]]+=[[:space:]]+).*$|\12000| ; \
s|^(snapshot-keep-recent[[:space:]]+=[[:space:]]+).*$|\12|" $HOME/.gaia/config/app.toml


SNAP_RPC="https://cosmos-rpc.polkachu.com:443"

LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height); \
BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000)); \
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC,$SNAP_RPC\"| ; \
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"|" $HOME/.gaia/config/config.toml


echo "create systemd service & start syncing..."
cat > /etc/systemd/system/gaiad.service << EOF
[Unit]
Description=gaiad
After=network-online.target
[Service]
User=root
ExecStart=/root/go/bin/gaiad start
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF
source ~/.profile
systemctl daemon-reload
systemctl enable gaiad
systemctl start gaiad
