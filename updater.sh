#!/usr/bin/env bash
# Updater script for Raspberry PI system for a smart thermostat
# to be run as a root crontab (e.g. in /etc/cron.hourly)

cd "$(dirname "$0")"

sudo_path=`which sudo`

install_sudo() {
    echo "You need sudo to run this script."
    exit 1
}

check_prereqs() {
    if [ -z "${sudo_path}" ]; then
        install_sudo
    fi
}

# check prerequisites
check_prereqs

# load configuration
set -a
. local.properties
set +a

BRANCH=master

set -e

if [ $(id -u) = "0" ]; then
    # install some packages
    apt-get -qq update
    apt-get -qqy install git python3-pip

    # install systemd unit and reload daemon
    cp daemon-systemd.service /usr/lib/systemd/user/thermostatd.service
    systemctl daemon-reload

    # re-run as user
    sudo -u pi $0
else:
    cd /home/pi

    # install software
    [[ ! -d daemon ]] && git clone -b ${BRANCH} https://daniele@git.casaricci.it/thermostat-daemon.git daemon
    cd daemon
    git pull
    sudo pip3 install -r requirements.txt
    ./setup.py build
    sudo ./setup.py install

    # create env
    sudo mkdir -p /var/lib/thermostat
    sudo chown -R pi:pi /var/lib/thermostat

    # init/upgrade database
    ./migrate generate
    ./migrate upgrade

    # TODO restart daemon only if changed
    systemd restart thermostatd
fi
