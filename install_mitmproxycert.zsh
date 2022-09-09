#!/usr/bin/zsh

if [[ $# -ne 1 ]]; then
    printf "Pass in the path to the certificate\n" >&2
    exit 1
fi

PATHTOFILE=$1
FILE=$(basename $PATHTOFILE)
adb root
adb remount 
adb push $PATHTOFILE /system/etc/security/cacerts 
adb shell chmod 664 /system/etc/security/cacerts/$FILE
adb reboot
