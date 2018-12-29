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
    if [[ -z "${sudo_path}" ]]; then
        install_sudo
    fi
}

self_chksum() {
    sha1sum $0 | cut -d' ' -f1
}

# check prerequisites
check_prereqs

BRANCH=mqtt
MAINUSER=$(getent passwd 1000 | cut -d: -f1)
CHKFILE=/tmp/thermostat-updater.chk

set -e

if [[ $(id -u) = "0" ]]; then
    if [[ ! -a "${CHKFILE}" ]] || [[ "$(cat ${CHKFILE})" != "$(self_chksum)" ]]; then
        # install some packages
        apt-get -qq update
        apt-get -qqy install git python3-pip nginx-light mosquitto curl
        apt-get -qq clean

        # update mDNS service
        cat <<EOF >/etc/avahi/services/thermostat.service
<?xml version="1.0" standalone='no'?><!--*-nxml-*-->
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">

<service-group>

  <name replace-wildcards="no">Thermorasp</name>

  <service>
    <type>_http._tcp</type>
    <port>80</port>
  </service>

</service-group>
EOF

        systemctl reload avahi-daemon

        # update nginx
        cat <<EOF >/etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name  localhost;

    charset utf-8;
    root /home/${MAINUSER}/webui/;

    gzip on;
    gzip_types text/plain text/javascript text/css application/javascript application/json;
    gzip_min_length 256;
    gzip_comp_level 6;
    gzip_buffers 16 8k;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api/ {
        proxy_pass  http://localhost:7475/;
    }

    location /mqtt/ {
        proxy_pass  http://localhost:9001/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
    }
}
EOF

        systemctl reload nginx

        # update mosquitto
        cat <<EOF >/etc/mosquitto/conf.d/thermostat.conf
listener 1883 0.0.0.0
listener 9001 127.0.0.1
protocol websockets
EOF

        systemctl restart mosquitto
        sleep 1
        systemctl restart thermostatd || true

        self_chksum >"${CHKFILE}"
    fi

    # re-run as user
    sudo -u "${MAINUSER}" $0

else
    cd "/home/${MAINUSER}"

    # install software
    [[ ! -d daemon ]] && git clone -b ${BRANCH} https://github.com/daniele-athome/thermorasp-daemon.git daemon
    cd daemon
    git pull
    git checkout ${BRANCH}

    COMMIT=$(git rev-parse HEAD)
    if [[ ! -a .version ]] || [[ "$(cat .version)" != "${COMMIT}" ]]; then
        # install systemd unit and reload daemon
        sed  "s/@@MAINUSER@@/${MAINUSER}/g" daemon-systemd.service | sudo tee /etc/systemd/system/thermostatd.service >/dev/null
        sudo systemctl daemon-reload

        sudo pip3 install -r requirements.txt -r requirements-prod.txt
        ./setup.py build
        sudo ./setup.py install

        # create env
        sudo mkdir -p /var/lib/thermostat
        sudo chown -R "${MAINUSER}:${MAINUSER}" /var/lib/thermostat

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

    [[ ! -d webui ]] && git clone -b ${BRANCH}-dist https://github.com/daniele-athome/thermorasp-webui.git webui
    cd webui
    git pull
    git checkout ${BRANCH}-dist

    COMMIT=$(git rev-parse HEAD)
    if [[ ! -a .version ]] || [[ "$(cat .version)" != "${COMMIT}" ]]; then
        echo ${COMMIT} >.version
    fi

fi
