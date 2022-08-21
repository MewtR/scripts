#!/usr/bin/zsh

# Script to pull the base.apk to the current directory
# or an arbitrary directory if provided

if [[ $# -lt 1 ]]; then
    printf "Pass in a package or app name\n" >&2
    exit 1
fi

APP=$1
NAME="${1}_base.apk"

RESULTS=$(adb shell pm list packages | grep -i $APP | cut -d: -f2 | wc -l)

if [[ $RESULTS -gt 1 ]]; then
    printf "Too many hits, be more specific\n" >&2
    exit 1
fi

if [[ $RESULTS -eq 0 ]]; then
    printf "No package found\n" >&2
    exit 1
fi

PACKAGE_NAME=$(adb shell pm list packages | grep -i $APP | cut -d: -f2)

BASEAPK_PATH=$(adb shell pm path $PACKAGE_NAME | grep -i base | cut -d: -f2)

if [[ -d $2 ]]; then
    adb pull $BASEAPK_PATH $2/$NAME
else
    adb pull $BASEAPK_PATH ./$NAME
fi
