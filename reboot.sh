#!/bin/bash

# Stupid script I run in a loop to detect pi disconnects

RESULT=$(iw dev wlan0 link 2>&1 | head -n 1)
FILE=/path/to/reboot.log

if [ ! -f $FILE ]; then
    touch $FILE
fi

DATE=$(date)

if [[ $RESULT == "Not connected." ]]; then
    printf "\n" >> $FILE
    printf "%s Rebooting because of lack of wifi\n" "$DATE" >> $FILE
    reboot
elif [[ $RESULT == *"Connected"* ]]; then
    printf "." >> $FILE
fi
