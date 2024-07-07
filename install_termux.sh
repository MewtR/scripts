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
    printf "sha256 mismatch, aborting...\n"
    exit 1
fi

adb root &> /dev/null
# $? is the return value of the last command
if [ $? -ne 0 ]; then
    printf "Connect a device to proceed with installation\n"
    exit 1
fi

adb install $NAME

# stderr is redirected to stdout which is redirected to /dev/null
# same as &>
aapt v > /dev/null 2>&1

if [ $? -ne 0 ]; then
    printf "aapt needs to be installed for this script to work\n"
    exit 1
fi

PACKAGE_NAME=$(aapt dump badging $NAME | grep 'package: name=' | cut -d \' -f2) # this would be com.termux
adb shell pm grant $PACKAGE_NAME android.permission.WRITE_EXTERNAL_STORAGE

# Now comes the tricky part, 
# running commands in termux from adb on my pc.
# Presumably doable with run-as. https://android.stackexchange.com/questions/225260/termux-running-termux-via-adb-without-any-direct-interaction-with-the-device

# Main activity for termux is called the HomeActivity
# xargs to remove leading whitespace from dumpsys' output
HOME_ACTIVITY=$(adb shell dumpsys package $PACKAGE_NAME | grep -i homeactivity | xargs | cut -d ' ' -f2)
adb shell am start -n $HOME_ACTIVITY

INDEX=0
while [ $INDEX -le 8 ]; do
    sleep 1
    printf "%s Waiting for initial package bootstrap...\n" $INDEX
    INDEX=$(( INDEX + 1 ))
done
# Need the following to get binairies such as termux-setup-storage
SETUP_SCRIPT=termux_setup.sh
SETUP_SCRIPT_PATH=/data/data/$PACKAGE_NAME/files/home/$SETUP_SCRIPT
if [ ! -f $SETUP_SCRIPT ]; then
    touch $SETUP_SCRIPT
fi

printf "#!/bin/sh\n" >> $SETUP_SCRIPT
printf "\n" >> $SETUP_SCRIPT
printf "run-as $PACKAGE_NAME /data/data/$PACKAGE_NAME/files/usr/bin/sh -c " >> $SETUP_SCRIPT
printf "'export PATH=/data/data/$PACKAGE_NAME/files/usr/bin:$PATH;" >> $SETUP_SCRIPT
printf "export LD_PRELOAD=/data/data/$PACKAGE_NAME/files/usr/lib/libtermux-exec.so;" >> $SETUP_SCRIPT
printf "termux-setup-storage'\n" >> $SETUP_SCRIPT

adb push $SETUP_SCRIPT $SETUP_SCRIPT_PATH
adb shell exec /system/bin/sh $SETUP_SCRIPT_PATH

# Clean up
rm $SETUP_SCRIPT
adb shell rm $SETUP_SCRIPT_PATH
