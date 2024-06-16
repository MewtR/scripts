#!/usr/bin/zsh

# local install directory
INSTALL_DIRECTORY=~/tmp/frida_install

FRIDA=frida
FRIDA_SERVER=$FRIDA-server
mkdir -p $INSTALL_DIRECTORY
cd $INSTALL_DIRECTORY

# Download
REPO=$FRIDA/$FRIDA
TAG=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | jq -r '.tag_name')
printf "tag name: %s\n" $TAG

NAME=$(curl -s https://api.github.com/repos/$REPO/releases/latest | jq -r '.assets[] | select(.name | startswith("frida-server")) | select(.name | endswith("android-arm64.xz")) | .name')
printf "Downloading %s\n" $NAME 


FRIDA_DOWNLOAD_URL=$(curl -s https://api.github.com/repos/$REPO/releases/latest | jq -r '.assets[] | select(.name | startswith("frida-server")) | select(.name | endswith("android-arm64.xz")) | .browser_download_url')
printf "Download url: %s\n" $FRIDA_DOWNLOAD_URL

wget -O $NAME $FRIDA_DOWNLOAD_URL

unxz $NAME
NAME_WITHOUT_EXTENSION=$(printf "${NAME%.*}")
mv $NAME_WITHOUT_EXTENSION $FRIDA_SERVER

# install directory on my phone
FRIDA_INSTALL_PATH=/data/local/tmp/$FRIDA_SERVER

adb root
adb push $FRIDA_SERVER $FRIDA_INSTALL_PATH
adb shell chmod 755 $FRIDA_INSTALL_PATH
adb shell $FRIDA_INSTALL_PATH &

printf "Frida is running...\n"
sleep 1
exit 0
