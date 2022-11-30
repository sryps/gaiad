#!/bin/bash
### TESTED WITH UBUNTU 22.04
### Run as root but not best practises - TESTING ONLY

set -e

clear

sudo apt update -y
sudo apt-get install -y make gcc jq git

# INSTALL GOLANG
curl -OL https://golang.org/dl/go1.19.3.linux-amd64.tar.gz

sudo tar -C /usr/local -xvf go1.19.3.linux-amd64.tar.gz

echo 'export GOROOT=/usr/local/go' >> ~/.profile
echo 'export GOPATH=$HOME/go' >> ~/.profile
echo 'export PATH=$GOPATH/bin:$GOROOT/bin:$PATH' >> ~/.profile

. ~/.profile

# INSTALL GAIAD
cd ~
git clone -b v7.1.0 https://github.com/cosmos/gaia
cd ~/gaia 
make install

gaiad init temp --chain-id temp-1

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



cat > /etc/systemd/system/gaiad.service << EOF
[Unit]
Description=gaiad
Wants=network-online.target
[Service]
User=root
ExecStart=/usr/local/bin/gaiad start
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF

systemctl enable gaiad
systemctl start gaiad
journalctl -u gaiad.service -f
