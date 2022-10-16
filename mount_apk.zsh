#!/usr/bin/zsh

# Script to mount install an apk, heavily inspired by some revanced scripts.
# Pass in the patched apk and the target package.
if [[ $# -lt 2 ]]; then
    printf "Pass in the patched apk and the target package.\n" >&2
    exit 1
fi

APK_MAGIC_BYTES=504b0304

PATCHED_APK=$1
TARGET_PACKAGE=$2
MAGIC_BYTES=$(od -N 4 -x --endian=big -A n $PATCHED_APK | tr -d ' ')
printf "Magic bytes are %s\n" $MAGIC_BYTES

if [[ $MAGIC_BYTES != $APK_MAGIC_BYTES ]]; then
    printf "Input file isn't an apk bro. Like it's not even a zip\n"
    exit 1
fi

adb root

# Check for root
if ! adb shell su -c exit 2> /dev/null; then
    printf "You need root for this to work\n"
    exit 1
fi

# Check for magisk
if ! adb shell magisk -c &> /dev/null; then
    printf "Please have magisk installed\n"
    exit 1
fi

RESULTS=$(adb shell pm list packages | grep -i $TARGET_PACKAGE | cut -d: -f2 | wc -l)

if [[ $RESULTS -gt 1 ]]; then
    printf "Too many hits, be more specific\n" >&2
    exit 1
fi

if [[ $RESULTS -eq 0 ]]; then
    printf "No package found\n" >&2
    exit 1
fi

TARGET_FULL_NAME=$(adb shell pm list packages | grep -i $TARGET_PACKAGE | sed 's/package://g')
TARGET_FULL_NAME_APK=$TARGET_FULL_NAME.apk
printf "Target's full name is: %s\n" $TARGET_FULL_NAME
TARGET_FULL_PATH=$(adb shell pm path $TARGET_FULL_NAME | grep base | sed 's/package://g')
printf "Target's full path is: %s\n" $TARGET_FULL_PATH


MAGISKTMP=$(adb shell magisk --path)
MIRROR=$MAGISKTMP/.magisk/mirror
DEST_DIR=/data/adb/patched
DEST_FULL_PATH=$DEST_DIR/$TARGET_FULL_NAME_APK

while [ $(adb shell getprop sys.boot_completed | tr -d '\r')  != "1" ]
do
    printf "Waiting for device to boot fully...\n"
    sleep 1;
done

#Start off by removing any existing links
adb shell umount -l $TARGET_FULL_PATH

adb shell mkdir -p $DEST_DIR
adb push $PATCHED_APK $DEST_FULL_PATH
adb shell chmod 644 $DEST_FULL_PATH
adb shell chown system:system $DEST_FULL_PATH
adb shell chcon u:object_r:apk_data_file:s0 $DEST_FULL_PATH
adb shell mount -o bind $MIRROR$DEST_FULL_PATH $TARGET_FULL_PATH

