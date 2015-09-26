#!/usr/bin/env bash
set -Eeux
set -o posix
set -o pipefail

# Suppress dialogs when installing things
export DEBIAN_FRONTEND=noninteractive

# read config file
. /vagrant/conf/th.conf

# Set up logging
declare -r guest_log="/vagrant/guest_logs/vagrant_mmc_bootstrap.log"
echo "$0 will append logs to $guest_log"
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

# add 2G swap to get around ENOMEM problems (does not persist across reboot)
echo_log "create swap"
mkdir -p /var/cache/swap/
dd if=/dev/zero of=/var/cache/swap/swap0 bs=1M count=2048
chmod 0600 /var/cache/swap/swap0
mkswap /var/cache/swap/swap0
swapon /var/cache/swap/swap0

# baseline system prep
echo_log "base system update"
apt-get update

# Python stuff
echo_log "getting Python stuff"
apt-get install -y python2.7 python-crypto python-mysqldb python-pip
apt-get install -y python-dev # needed for things like building python profiling

# add blockchain tools to path
sudo -u vagrant cp -r /vagrant/tools /home/vagrant
cat >>/home/vagrant/.bashrc <<EOL

# add blockchain tools to path
PATH=$PATH:/home/vagrant/tools
EOL

#Install coins
IFS="," read -ra COINS <<< "$INSTALL_COINS"
for COIN in "${COINS[@]}"; do
    ~vagrant/tools/coin_install "$COIN"
done

#Run coins
IFS="," read -ra COINS <<< "$RUN_COINS"
for COIN in "${COINS[@]}"; do
    ~vagrant/tools/coin_start "$COIN"
done

#Check coin status
for COIN in "${COINS[@]}"; do
    ~vagrant/tools/coin_status "$COIN"
done

# Install Abe & dependencies
if [ "$INSTALL_ABE" = true ]; then
    # get MySQL
    echo_log "getting MySQL stuff"
    apt-get install -y mysql-client
    apt-get install -y mysql-server-5.5
    
    # Prep abe
    echo_log "Set up DB"
    mysql -u root < /vagrant/setup_mysql.sql
    (cd /vagrant/ThirdParty/abe && python setup.py install)
fi

# Nagios - system monitoring and alerting
if [ "$INSTALL_NAGIOS" = true ]; then
    echo_log "getting email stuff"
    apt-get install -y postfix mailutils libsasl2-2 ca-certificates libsasl2-modules
    echo_log "tweaking postfix configuration"
    cat /vagrant/conf/system_bootstrap/etc/postfix/main.cf.append >> /etc/postfix/main.cf
    echo '[smtp.gmail.com]:587    USERNAMEFILLME@gmail.com:PASSWORDFILLME' > /etc/postfix/sasl_passwd
    chmod 400 /etc/postfix/sasl_passwd
    cp /etc/ssl/certs/Thawte_Premium_Server_CA.pem /etc/postfix/cacert.pem
    postmap /etc/postfix/sasl_passwd
    echo_log "XXXXX EMAIL TEMPLATE CONF CREATED - PLEASE EDIT /etc/postfix/sasl_passwd XXXXX"
    echo_log "getting nagios"
    apt-get install -y nagios3 nagios-nrpe-plugin
    echo_log "setting up nagios"
    usermod -a -G nagios www-data
    chmod -R +x /var/lib/nagios3/
    htpasswd -b -c /etc/nagios3/htpasswd.users nagiosadmin nagiosadmin
    cp /vagrant/conf/system_bootstrap/etc/nagios3/nagios.cfg /etc/nagios3/nagios.cfg
    cp /vagrant/conf/system_bootstrap/etc/nagios3/commands.cfg /etc/nagios3/commands.cfg
    cp /vagrant/conf/system_bootstrap/etc/nagios3/conf.d/contacts_nagios2.cfg /etc/nagios3/conf.d/contacts_nagios2.cfg
    cp /vagrant/conf/system_bootstrap/etc/nagios3/conf.d/localhost_nagios2.cfg /etc/nagios3/conf.d/localhost_nagios2.cfg
    service nagios3 restart
fi

echo_log "current procs: $(ps -aux)"
echo_log "current df: $(df -h /)"

echo_log "complete"
echo "$0 all done!"
