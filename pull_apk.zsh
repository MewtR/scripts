#!/usr/bin/zsh

# Script to pull the base.apk to the current directory
# or an arbitrary directory if provided

if [[ $# -lt 1 ]]; then
    printf "Pass in a package or app name\n" >&2
    exit 1
fi

APP=$1
NAME="${1}_base.apk"

PACKAGE_NAME=$(adb shell pm list packages | grep -i $APP | cut -d: -f2)

if [[ -z $PACKAGE_NAME ]]; then
    printf "No package found\n" >&2
    exit 1
fi

#TODO: handle the case of too many results
BASEAPK_PATH=$(adb shell pm path $PACKAGE_NAME | grep -i base | cut -d: -f2)

if [[ -d $2 ]]; then
    adb pull $BASEAPK_PATH $2/$NAME
else
    adb pull $BASEAPK_PATH ./$NAME
fi
