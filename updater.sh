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
    apt-get -qqy install git python3-pip nginx-light
    apt-get -qq clean

    # we need npm for webui
    if ! command -v npm &>/dev/null; then
        curl "https://nodejs.org/dist/v9.5.0/node-v9.5.0-linux-armv6l.tar.gz" >/tmp/nodejs.tar.gz
        tar -C /tmp -xzf /tmp/nodejs.tar.gz
        cp -R /tmp/node-v*/bin /tmp/node-v*/include /tmp/node-v*/lib /tmp/node-v*/share /usr/local
        rm -fR /tmp/nodejs.tar.gz /tmp/node-v*
    fi

    # update nginx
    cat <<EOF >/etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name  localhost;

    charset utf-8;
    root /home/pi/webui/app;

    gzip on;
    gzip_types text/plain text/javascript text/css application/javascript application/json;
    gzip_min_length 256;
    gzip_comp_level 6;
    gzip_buffers 16 8k;

    location /api/ {
        proxy_pass  http://localhost:7475/;
    }
}
EOF

    systemctl reload nginx

    # re-run as user
    sudo -u pi $0

else
    cd /home/pi

    # install software
    [[ ! -d daemon ]] && git clone -b ${BRANCH} https://github.com/daniele-athome/thermorasp-daemon.git daemon
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

    cd ..

    [[ ! -d webui ]] && git clone -b ${BRANCH} https://github.com/daniele-athome/thermorasp-webui.git webui
    cd webui
    git pull

    COMMIT=$(git rev-parse HEAD)
    if [[ ! -a .version ]] || [[ "$(cat .version)" != "${COMMIT}" ]]; then
        npm install
        echo ${COMMIT} >.version
    fi

fi
