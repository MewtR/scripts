#!/usr/bin/zsh

# Script to mount install an apk
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

RESULTS=$(adb shell pm list packages | grep -i $TARGET_PACKAGE | cut -d: -f2 | wc -l)

if [[ $RESULTS -gt 1 ]]; then
    printf "Too many hits, be more specific\n" >&2
    exit 1
fi

if [[ $RESULTS -eq 0 ]]; then
    printf "No package found\n" >&2
    exit 1
fi
