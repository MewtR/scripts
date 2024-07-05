#!/usr/bin/sh

INSTALL_DIRECTORY=~/tmp/termux_install
mkdir -p $INSTALL_DIRECTORY
cd $INSTALL_DIRECTORY

# Download
REPO=termux/termux-app
TAG=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | jq -r '.tag_name')
printf "tag name: %s\n" $TAG

ARCH=arm64
NAME=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | jq -r '.assets[] | select(.name|match("'$ARCH'")) | .name')
printf "Downloading %s\n" $NAME 
TERMUX_DOWNLOAD_URL=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | jq -r '.assets[] | select(.name|match("'$ARCH'")) | .browser_download_url')

HASH=sha256
SHA_FILE=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | jq -r '.assets[] | select(.name|match("'$HASH'")) | .name')
TERMUX_SHA_DOWNLOAD_URL=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | jq -r '.assets[] | select(.name|match("'$HASH'")) | .browser_download_url')

wget -O $NAME $TERMUX_DOWNLOAD_URL
wget -O $SHA_FILE $TERMUX_SHA_DOWNLOAD_URL

SHA_FROM_FILE=$(cat $SHA_FILE | grep $NAME | cut -d ' ' -f1)
SHA_FROM_APK=$(sha256sum $NAME | cut -d ' ' -f1)

if [ $SHA_FROM_FILE != $SHA_FROM_APK ]; then
    printf "sha256 mismatch, aborting..."
    exit 1
fi

adb root
# $? is the return value of the last command
if [ $? -ne 0 ]; then
    printf "Connect a device to proceed with installation"
    exit 1
fi

adb install $NAME

# Now comes the tricky part, 
# running commands in termux from adb on my pc.
# Presumably doable with run-as. https://android.stackexchange.com/questions/225260/termux-running-termux-via-adb-without-any-direct-interaction-with-the-device
