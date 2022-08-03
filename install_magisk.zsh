#!/usr/bin/zsh

INSTALL_DIRECTORY=/tmp/magisk_install
mkdir -p $INSTALL_DIRECTORY
cd $INSTALL_DIRECTORY

# Download
REPO=topjohnwu/Magisk
TAG=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | jq -r '.tag_name')
printf "tag name: %s\n" $TAG

NAME=$(curl -s https://api.github.com/repos/topjohnwu/Magisk/releases/latest | jq -r '.assets[] | select(.name|match("^Magisk")) | .name')
printf "Downloading %s\n" $NAME 
MAGISK_DOWNLOAD_URL=$(curl -s https://api.github.com/repos/topjohnwu/Magisk/releases/latest | jq -r '.assets[] | select(.name|match("^Magisk")) | .browser_download_url')

wget -O $NAME $MAGISK_DOWNLOAD_URL

# install
adb install $NAME

# Get lineageos build date and version
DEVICE_NAME=$(adb shell getprop ro.build.product)
LINEAGEOS_VERSION=$(adb shell getprop ro.lineage.version | cut -d- -f1)
BUILD_DATE=$(adb shell getprop ro.lineage.version | cut -d- -f2)
PACKAGE_NAME=lineage-${LINEAGEOS_VERSION}-${BUILD_DATE}-nightly-${DEVICE_NAME}-signed
PACKAGE_NAME_ZIP=${PACKAGE_NAME}.zip
LINEAGEOS_DOWNLOAD_URL=https://mirrorbits.lineageos.org/full/${DEVICE_NAME}/${BUILD_DATE}/${PACKAGE_NAME_ZIP}
LINEAGEOS_DOWNLOAD_URL_SHA256=$LINEAGEOS_DOWNLOAD_URL\?sha256
#printf "%s\n" $LINEAGEOS_DOWNLOAD_URL_SHA256
SHA256=$(curl -s $LINEAGEOS_DOWNLOAD_URL_SHA256 | cut -d ' ' -f1)

printf "sha256 %s\n" $SHA256
wget -O $PACKAGE_NAME_ZIP $LINEAGEOS_DOWNLOAD_URL

MYSHA256=$(sha256sum $PACKAGE_NAME_ZIP | cut -d ' ' -f1)
printf "mysha256 %s\n" $MYSHA256

if [[ $SHA256 != $MYSHA256 ]] {
    printf "sha256 mismatch, aborting..."
    exit 1
}

# Extracting proprietary blobs 
# See https://wiki.lineageos.org/extracting_blobs_from_zips#extracting-proprietary-blobs-from-payload-based-otas
PAYLOAD_FILE=payload.bin
unzip $PACKAGE_NAME_ZIP $PAYLOAD_FILE

git clone --depth 1 https://github.com/LineageOS/scripts
python scripts/update-payload-extractor/extract.py $PAYLOAD_FILE

BOOT_IMG=boot.img
DOWNLOAD_DIRECTORY=/sdcard/Download
adb push output/$BOOT_IMG $DOWNLOAD_DIRECTORY/$BOOT_IMG
# got com.topjohnwu.magisk/.ui.MainActivity from doing ( adb shell ) dumpsys package com.topjohnwu.magisk | grep -i activity
adb shell am start -n com.topjohnwu.magisk/.ui.MainActivity

read -s -k $'?Patch boot.img in the Magisk app then press any key to continue.\n'

MAGISK_IMAGE=$(adb shell ls $DOWNLOAD_DIRECTORY | grep -i magisk)
print "Magisk image is %s\n" $MAGISK_IMAGE
adb pull $DOWNLOAD_DIRECTORY/$MAGISK_IMAGE .

# Clean up the images
adb shell rm $DOWNLOAD_DIRECTORY/$BOOT_IMG
adb shell rm $DOWNLOAD_DIRECTORY/$MAGISK_IMAGE

# Reboot into fastboot
adb reboot bootloader
sleep 5
fastboot flash boot $MAGISK_IMAGE
sleep 5
fastboot flash vbmeta --disable-verity --disable-verification output/vbmeta.img
sleep 5
fastboot reboot
