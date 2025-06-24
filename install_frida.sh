#!/usr/bin/sh

FRIDA=frida
REPO=$FRIDA/$FRIDA
ARCH=arm64
RELEASES_ENDPOINT=https://api.github.com/repos/${REPO}/releases
API_URL=${RELEASES_ENDPOINT}/latest

# Parse command line arguments
# Stolen from here: https://joshtronic.com/2023/03/12/parsing-arguments-in-shell-script/
while [[ $# -gt 0 ]] do
    case $1 in
        --arch)
            ARCH=$2
            shift
            shift
            ;;

        --tag)
            API_URL=${RELEASES_ENDPOINT}/tags/$2
            shift
            shift
            ;;

        *)
            printf "Invalid option\n"
            exit 1
    esac
done

# local install directory
INSTALL_DIRECTORY=~/tmp/frida_install

FRIDA_SERVER=$FRIDA-server
mkdir -p $INSTALL_DIRECTORY
cd $INSTALL_DIRECTORY

# Download
TAG=$(curl -s $API_URL | jq -r '.tag_name')
printf "tag name: %s\n" $TAG

NAME=$(curl -s $API_URL | jq -r --arg arch "$ARCH" '.assets[] | select(.name | startswith("frida-server")) | select(.name | endswith("android-\($arch).xz")) | .name')
printf "Downloading %s\n" $NAME


FRIDA_DOWNLOAD_URL=$(curl -s $API_URL | jq -r --arg arch "$ARCH" '.assets[] | select(.name | startswith("frida-server")) | select(.name | endswith("android-\($arch).xz")) | .browser_download_url')
printf "Download url: %s\n" $FRIDA_DOWNLOAD_URL

wget -O $NAME $FRIDA_DOWNLOAD_URL

FRIDA_SERVER_XZ=$FRIDA_SERVER.xz
mv $NAME $FRIDA_SERVER_XZ
unxz --force $FRIDA_SERVER_XZ

# install directory on my phone
FRIDA_INSTALL_PATH=/data/local/tmp/$FRIDA_SERVER

ADB_ROOT=$(adb root)

adb push $FRIDA_SERVER $FRIDA_INSTALL_PATH
if [[ $ADB_ROOT == "adbd cannot run as root in production builds" ]]; then
    # Look for the su binary
    SU=$(adb shell which su)
    if [[ $? -ne 0 ]]; then
        printf "Root needed to install frida\n"
        adb shell rm $FRIDA_INSTALL_PATH
        exit 1
    fi
    adb shell su -c chmod 755 $FRIDA_INSTALL_PATH
    adb shell su -c $FRIDA_INSTALL_PATH &
else
    adb shell chmod 755 $FRIDA_INSTALL_PATH
    adb shell $FRIDA_INSTALL_PATH &
fi

printf "Frida is running...\n"
sleep 1
exit 0
