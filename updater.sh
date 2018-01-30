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

BRANCH=master

set -e

if [ $(id -u) = "0" ]; then
    # install some packages
    apt-get -qq update
    apt-get -qqy install git python3-pip
    apt-get -qq clean

    # re-run as user
    sudo -u pi $0

else
    cd /home/pi

    # install software
    [[ ! -d daemon ]] && git clone -b ${BRANCH} https://daniele@git.casaricci.it/thermostat-daemon.git daemon
    cd daemon
    git pull

    COMMIT=$(git rev-parse HEAD)
    if [[ ! -a .version ]] || [[ "$(cat .version)" != "${COMMIT}" ]]; then
        # install systemd unit and reload daemon
        sudo cp daemon-systemd.service /etc/systemd/system/thermostatd.service
        sudo systemctl daemon-reload

        sudo pip3 install -r requirements.txt -r requirements-prod.txt
        ./setup.py build
        sudo ./setup.py install

        # create env
        sudo mkdir -p /var/lib/thermostat
        sudo chown -R pi:pi /var/lib/thermostat

        # create configuration
        sudo cp thermostat.conf.dist /etc/thermostat.conf

        # init/upgrade database
        # FIXME this might create git conflicts
        sed -i 's/^config_file = \(.*\)$/config_file = \/etc\/thermostat.conf/' alembic.ini
        ./migrate generate
        ./migrate upgrade

        # restart daemon and store version
        sudo systemctl restart thermostatd
        echo ${COMMIT} >.version
    fi

fi
