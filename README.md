Raspberry PI Smart Thermostat deploy tools
==========================================

Deploy tools (mainly scripts) for managing the thermostat firmware.
After setting up a SD card with some preconfigured stuff, the system
will access the Internet and self-install all the required software,
meaning the thermostat will be completely autonomous.

## First time setup
Flash a plain Raspbian image from the Raspberry site. Keep the SD card inside
and mount both partitions (boot and root) onto two different directories.

Copy the file `local.properties.dist` to `local.properties` and edit it. This will be the
configuration file for your thermostat. All configuration properties are well
commented and explained in the file itself.

Run the setup script **as root**:

```
# ./setup
```

Unmount both SD card partitions and put the SD card in your Raspberry PI.

After you power on your device, wait a few minutes and try to login via SSH.
You'll need to run the updater script once to install the required software.
The script itself is configured as a daily cronjob and it will keep the software
updated.

```
$ sudo /etc/cron.daily/thermostat-updater
```

The thermostat software should now be up and running in the background.

## Access web interface and control
You can check the thermostat daemon status via systemctl:

```
$ systemctl status thermostatd
```

You can access the web interface (change the IP address to the one you set in
the configuration file):

```
http://192.168.0.250/
```

If your computer has a mDNS/Avahi/Bonjour client, you can also use the hostname
followed by `.local`:

```
http://thermostat.local/
```

Please refer to the [web UI repository](//github.com/daniele-athome/thermorasp-webui) for further
information on its configuration capabilities.
