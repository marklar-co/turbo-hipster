#!/usr/bin/env bash
set -Eeux
set -o posix
set -o pipefail

declare -r guest_log="/vagrant/guest_logs/vagrant_mmc_bootstrap.log"
declare -r litecoin_target_dir="/opt/litecoin"
declare -r dogecoin_target_dir="/opt/dogecoin"
declare -r bitcoin_target_dir="/opt/bitcoin"
declare -r florincoin_target_dir="/opt/florincoin"

echo "$0 will append logs to $guest_log"
echo "$0 will install dogecoin to $dogecoin_target_dir"
echo "$0 will install florincoin to $florincoin_target_dir"
sleep 2

mkdir -p "$(dirname "$guest_log")"

declare -r exe_name="$0"
echo_log() {
	local log_target="$guest_log"
 	echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $exe_name: $@" >> $log_target
}

echo_log "start"
echo_log "uname: $(uname -a)"
echo_log "current procs: $(ps -aux)"
echo_log "current df: $(df -h /)"

# add 2G swap to get arround annoying ENOMEM problems (does not persist across reboot)
echo_log "create swap"
mkdir -p /var/cache/swap/
dd if=/dev/zero of=/var/cache/swap/swap0 bs=1M count=2048
chmod 0600 /var/cache/swap/swap0
mkswap /var/cache/swap/swap0
swapon /var/cache/swap/swap0

# baseline system prep
echo_log "base system update"
apt-get update
apt-get install -y vim #always nice to have!

# MySQL
echo_log "getting MySQL stuff"
apt-get install -y mysql-client
export DEBIAN_FRONTEND=noninteractive
apt-get install -y mysql-server-5.5

# Python stuff
echo_log "getting Python stuff"
apt-get install -y python2.7 python-crypto python-mysqldb python-pip
apt-get install -y python-dev # needed for things like building python profiling

# bitcoin
echo_log "prepping bitcoin stuff"
sudo -u vagrant mkdir -p /home/vagrant/.bitcoin
sudo -u vagrant cp /vagrant/bitcoin.conf /home/vagrant/.bitcoin/.
mkdir "$bitcoin_target_dir"
cp /vagrant/ThirdParty/bitcoin_bin/bitcoind "$bitcoin_target_dir/bitcoind"
cp /vagrant/ThirdParty/bitcoin_bin/bitcoin-cli "$bitcoin_target_dir/bitcoin-cli"
cp /vagrant/ThirdParty/bitcoin_bin/bitcoin-tx "$bitcoin_target_dir/bitcoin-tx"
chown -R vagrant:vagrant "$bitcoin_target_dir"
chmod 755 "$bitcoin_target_dir/bitcoind"
chmod 755 "$bitcoin_target_dir/bitcoin-cli"
chmod 755 "$bitcoin_target_dir/bitcoin-tx"
echo_log "starting bitcoind"
sudo -H -u vagrant "$bitcoin_target_dir/bitcoind" #note the -H... important
echo "Sleeping a while to let bitcoind get going..."
sleep 5

# Litecoin
echo_log "prepping litecoin stuff"
sudo -u vagrant mkdir -p /home/vagrant/.litecoin
sudo -u vagrant cp /vagrant/litecoin.conf /home/vagrant/.litecoin/.
mkdir "$litecoin_target_dir"
cp /vagrant/ThirdParty/litecoin_bin/litecoind-0.8.7.5-linux64 "$litecoin_target_dir/litecoind"
chown -R vagrant:vagrant "$litecoin_target_dir"
chmod 755 "$litecoin_target_dir/litecoind"
echo_log "starting litecoind"
sudo -H -u vagrant "$litecoin_target_dir/litecoind" #note the -H... important
echo "Sleeping a while to let litecoind get going..."
sleep 5

# Florincoin - from binary
echo_log "prepping florincoin stuff"
apt-get install -y libboost-all-dev libdb-dev libdb++-dev libminiupnpc-dev
sudo -u vagrant mkdir -p /home/vagrant/.florincoin
sudo -u vagrant cp /vagrant/florincoin.conf /home/vagrant/.florincoin/.
mkdir "$florincoin_target_dir"
cp /vagrant/ThirdParty/florincoin_bin/florincoind-f62498c "$florincoin_target_dir/florincoind"
chown -R vagrant:vagrant "$florincoin_target_dir"
chmod 755 "$florincoin_target_dir/florincoind"
echo_log "starting florincoind"
sudo -H -u vagrant "$florincoin_target_dir/florincoind" #note the -H... important
echo "Sleeping a while to let florincoind get going..."
sleep 5

# # Florincoin - if we need to rebuild from source
# echo_log "getting dependencies to build florincoin"
# apt-get install -y build-essential libssl-dev libdb-dev libdb++-dev libboost-all-dev libqrencode-dev libminiupnpc-dev
# echo_log "building florincoin"
# (cd /vagrant/ThirdParty/florincoin/src && make -f makefile.unix)
# sudo -u vagrant mkdir -p /home/vagrant/.florincoin
# sudo -u vagrant cp /vagrant/florincoin.conf /home/vagrant/.florincoin/.
# mkdir "$florincoin_target_dir"
# cp /vagrant/ThirdParty/florincoin/src/florincoind "$florincoin_target_dir/florincoind"
# chown -R vagrant:vagrant "$florincoin_target_dir"
# chmod 755 "$florincoin_target_dir/florincoind"
# echo_log "starting florincoind"
# sudo -H -u vagrant "$florincoin_target_dir/florincoind" #note the -H... important
# echo "Sleeping a while to let florincoind get going..."
# sleep 5

# Dogecoin
echo_log "prepping dogecoin stuff"
sudo -u vagrant mkdir -p /home/vagrant/.dogecoin
sudo -u vagrant cp /vagrant/dogecoin.conf /home/vagrant/.dogecoin/.
mkdir "$dogecoin_target_dir"
cp /vagrant/ThirdParty/dogecoin_bin/dogecoind-1.8.2-linux64 "$dogecoin_target_dir/dogecoind"
cp /vagrant/ThirdParty/dogecoin_bin/dogecoin-cli-1.8.2-linux64 "$dogecoin_target_dir/dogecoin-cli"
chown -R vagrant:vagrant "$dogecoin_target_dir"
chmod 755 "$dogecoin_target_dir/dogecoind"
chmod 755 "$dogecoin_target_dir/dogecoin-cli"
echo_log "starting dogecoind"
sudo -H -u vagrant "$dogecoin_target_dir/dogecoind" #note the -H... important
echo "Sleeping a while to let dogecoind get going..."
sleep 5

# Prep abe
echo_log "Set up DB"
mysql -u root < /vagrant/setup_mysql.sql
(cd /vagrant/ThirdParty/abe && python setup.py install)

echo_log "florincoind progress: $(tail /home/vagrant/.florincoin/testnet/debug.log || true)"
echo_log "dogecoind progress: $(tail /home/vagrant/.dogecoin/testnet3/debug.log || true)"
echo_log "current procs: $(ps -aux)"
echo_log "current df: $(df -h /)"

echo_log "complete"
echo "$0 all done!"
