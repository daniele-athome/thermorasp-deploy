Raspberry PI Smart Thermostat deploy tools
==========================================

Deploy tools (mainly Ansible recipes) for managing the thermostat software:
remote installation, over-the-air updates, system updates.

The `raspbian` directory contains a script for configuring a just-flashed Raspbian Lite SD card.
It will set up a base system for connecting to a WiFi network and opening an SSH access for remote install.

The `ota` directory contains mainly Ansible recipes for managing your thermostat remotely. You will use it also for
installing the thermostat software for the first time, after having prepared the SD card with the scripts in `raspbian`.

## First time setup
*TODO*

* copy local.properties.dist to local.properties and edit it
* run setup
