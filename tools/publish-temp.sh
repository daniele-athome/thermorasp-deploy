#!/bin/bash

if [[ "$1" == "" ]] || [[ "$2" == "" ]]; then
  echo "Usage: $0 sensor_id temperature [validity]"
  exit 1
fi

VALIDITY=$3
if [[ "${VALIDITY}" == "" ]]; then
  VALIDITY=900
fi

mosquitto_pub -t \
 homeassistant/thermorasp/sensor/$1/temperature \
 -r -m \
 "{\"unit\": \"celsius\", \"timestamp\": \"$(date +'%Y-%m-%dT%H:%M:%S.000000')\", \"value\": $2, \"validity\": ${VALIDITY}}"
