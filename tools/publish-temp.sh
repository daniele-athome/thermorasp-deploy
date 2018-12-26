#!/bin/bash

mosquitto_pub -t \
 homeassistant/thermorasp/sensor/$1/temperature \
 -r -m \
 "{\"unit\": \"celsius\", \"timestamp\": \"$(date +'%Y-%m-%dT%H:%M:%S.000000')\", \"value\": $2}"
