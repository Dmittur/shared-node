#!/bin/bash
sudo ufw disable
sudo apt update
sudo apt-get update && apt-get upgrade -y
sudo apt full-upgrade -y
#Files
sudo echo "DefaultLimitNOFILE=65535" >> /etc/systemd/system.conf
#swap file 4 Gb
sudo swapon --show
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
sudo swapon --show
sudo echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
cat /proc/sys/vm/swappiness
sudo echo 'vm.swappiness=25' >> /etc/sysctl.conf
#Time
sudo apt install ntpsec
sudo service ntpsec restart
#iptables
sudo iptables -A INPUT -p tcp -m tcp --dport 22 -m state --state NEW -m hashlimit --hashlimit 1/hour --hashlimit-burst 2 --hashlimit-mode srcip --hashlimit-name SSH --hashlimit-htable-expire 60000 -j ACCEPT
sudo iptables -A INPUT -p tcp -m tcp --dport 22 --tcp-flags SYN,RST,ACK SYN -j DROP
sudo iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
sudo apt install iptables-persistent -y
sudo service netfilter-persistent save
sudo iptables -L -n --line-numbers
sudo apt-get install zip git unzip curl screen wget -y
#idena-node-proxy
if [ -d "/root/idena-node-proxy" ]; then
echo "idena-node-proxy already installed"
else
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install git unzip curl screen -y
# Node.js 16.13 instalation
wget https://github.com/rioda-org/idena/raw/main/node-v16.13.0-linux-x64.tar.xz
sudo mkdir -p /usr/local/lib/nodejs
sudo tar -xJvf node-v16.13.0-linux-x64.tar.xz -C /usr/local/lib/nodejs
rm node-v16.13.0-linux-x64.tar.xz
echo "export PATH=/usr/local/lib/nodejs/node-v16.13.0-linux-x64/bin:$PATH" >> ~/.profile
. ~/.profile

mkdir datadir && cd datadir
mkdir idenachain.db && cd idenachain.db
wget "https://sync.idena.site/idenachain.db.zip"
unzip idenachain.db.zip && rm idenachain.db.zip
cd ../..

curl -s https://api.github.com/repos/idena-network/idena-go/releases/latest \
| grep browser_download_url \
| grep idena-node-linux-0.* \
| cut -d '"' -f 4 \
| wget -qi -
mv idena-* idena-go && chmod +x idena-go
bash -c 'echo "{\"IpfsConf\":{\"Profile\": \"server\" ,\"FlipPinThreshold\":1},\"Sync\": {\"LoadAllFlips\": true, \"AllFlipsLoadingTime\":7200000000000}}" > config.json'

#this is conf for minimal test node
#bash -c 'echo "{\"P2P\":{\"MaxInboundPeers\":4,\"MaxOutboundPeers\":1},\"IpfsConf\":{\"Profile\":\"server\",\"BlockPinThreshold\":0.1,\"FlipPinThreshold\":0.1}}" > config.json'

touch node-restarted.log

tee update << 'EOF'
killall screen
rm idena-go
curl -s https://api.github.com/repos/idena-network/idena-go/releases/latest | grep browser_download_url | grep idena-node-linux-0.* | cut -d '"' -f 4 | wget -qi -
mv idena-node-linux* idena-go
chmod +x idena-go
screen -dmS node $PWD/start
echo Update was successfull
EOF
chmod +x update

tee version << 'EOF'
curl 'http://127.0.0.1:9009/' -H 'Content-Type: application/json' --data '{"method":"dna_version","params":[{}],"id":1,"key":"123"}'
EOF
chmod +x version

bash -c 'echo "while :
do
./idena-go --config=config.json --profile=shared --apikey=123
date >> node-restarted.log
done" > start'
chmod +x start
(crontab -l 2>/dev/null; echo "@reboot screen -dmS node $PWD/start") | crontab -

npm i npm@latest -g
git clone https://github.com/idena-network/idena-node-proxy
npm i -g pm2

cd idena-node-proxy
wget https://raw.githubusercontent.com/rioda-org/idena/main/index.html

bash -c 'echo "AVAILABLE_KEYS=[\"api1\",\"api2\"]
IDENA_URL=\"http://localhost:9009\"
IDENA_KEY=\"123\"
PORT=80" > .env'
#GOD_API_KEY=\"test\"
#REMOTE_KEYS_ENABLED=0

npm install
sed -i 's/stdout/file/g' config_default.json
npm start
pm2 startup
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw reload
ulimit -n 200000
fi
