#!/usr/bin/sh

INSTALL_DIRECTORY=~/tmp/magisk_install
mkdir -p $INSTALL_DIRECTORY
cd $INSTALL_DIRECTORY

# Download
REPO=topjohnwu/Magisk
TAG=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | jq -r '.tag_name')
printf "tag name: %s\n" $TAG

NAME=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | jq -r '.assets[] | select(.name|match("^Magisk")) | .name')
printf "Downloading %s\n" $NAME 
MAGISK_DOWNLOAD_URL=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | jq -r '.assets[] | select(.name|match("^Magisk")) | .browser_download_url')

wget -O $NAME $MAGISK_DOWNLOAD_URL

adb root
# install
adb install -r $NAME

# Get lineageos build date and version
DEVICE_NAME=$(adb shell getprop ro.build.product)
LINEAGEOS_VERSION=$(adb shell getprop ro.lineage.version | cut -d- -f1)
BUILD_DATE=$(adb shell getprop ro.lineage.version | cut -d- -f2)
PACKAGE_NAME=lineage-${LINEAGEOS_VERSION}-${BUILD_DATE}-nightly-${DEVICE_NAME}-signed
PACKAGE_NAME_ZIP=${PACKAGE_NAME}.zip
LINEAGEOS_DOWNLOAD_URL=https://mirrorbits.lineageos.org/full/${DEVICE_NAME}/${BUILD_DATE}/${PACKAGE_NAME_ZIP}
LINEAGEOS_DOWNLOAD_URL_SHA256=$LINEAGEOS_DOWNLOAD_URL\?sha256
SHA256=$(curl -s $LINEAGEOS_DOWNLOAD_URL_SHA256 | cut -d ' ' -f1)

printf "sha256 %s\n" $SHA256
wget -O $PACKAGE_NAME_ZIP $LINEAGEOS_DOWNLOAD_URL

MYSHA256=$(sha256sum $PACKAGE_NAME_ZIP | cut -d ' ' -f1)
printf "mysha256 %s\n" $MYSHA256

if [ $SHA256 != $MYSHA256 ]; then 
    printf "sha256 mismatch, aborting..."
    exit 1
fi

# Extracting proprietary blobs 
# See https://wiki.lineageos.org/extracting_blobs_from_zips#extracting-proprietary-blobs-from-payload-based-otas
PAYLOAD_FILE=payload.bin
unzip $PACKAGE_NAME_ZIP $PAYLOAD_FILE

PARTITION_BOOT=boot
PARTITION_VBMETA=vbmeta
git clone --depth 1 https://github.com/LineageOS/android_prebuilts_extract-tools android/prebuilts/extract-tools

./android/prebuilts/extract-tools/linux-x86/bin/ota_extractor --partitions $PARTITION_BOOT,$PARTITION_VBMETA --payload $PAYLOAD_FILE

BOOT_IMG=${PARTITION_BOOT}.img
VBMETA_IMG=${PARTITION_VBMETA}.img
DOWNLOAD_DIRECTORY=/sdcard/Download
adb push $BOOT_IMG $DOWNLOAD_DIRECTORY/$BOOT_IMG
# got com.topjohnwu.magisk/.ui.MainActivity from doing ( adb shell ) dumpsys package com.topjohnwu.magisk | grep -i activity
adb shell am start -n com.topjohnwu.magisk/.ui.MainActivity

printf "Patch boot.img in the Magisk app then press any key to continue.\n"
read $RESPONSE

MAGISK_IMAGE=$(adb shell ls -t $DOWNLOAD_DIRECTORY | grep -m 1 magisk_patched)
printf "Magisk image is %s\n" $MAGISK_IMAGE
printf "Path is %s\n" $DOWNLOAD_DIRECTORY/$MAGISK_IMAGE
adb pull $DOWNLOAD_DIRECTORY/$MAGISK_IMAGE .

# Clean up the images
adb shell rm $DOWNLOAD_DIRECTORY/$BOOT_IMG
adb shell rm $DOWNLOAD_DIRECTORY/$MAGISK_IMAGE

# Reboot into fastboot
adb reboot bootloader
sleep 1
fastboot flash boot $MAGISK_IMAGE
sleep 1
# This next step is optional, also it could potentially wipe all my data
# according to the doc.
fastboot flash vbmeta --disable-verity --disable-verification $VBMETA_IMG
sleep 1
fastboot reboot

# Clean install directory
rm -rf $INSTALL_DIRECTORY
cd
