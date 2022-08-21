#!/usr/bin/zsh

JADX=jadx
JADXGUI=jadx-gui
INSTALL_DIRECTORY=~/Documents/tools/jadx
BIN_DIRECTORY=~/bin
cd $INSTALL_DIRECTORY

# Download
REPO=skylot/jadx
TAG=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | jq -r '.tag_name')
printf "tag name: %s\n" $TAG

NAME=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | jq -r '[.assets[] | select(.name|match("^jadx")) | .name][0]')
printf "Downloading %s\n" $NAME 


JADX_DOWNLOAD_URL=$(curl -s https://api.github.com/repos/${REPO}/releases/latest | jq -r '[.assets[] | select(.name|match("^jadx")) | .browser_download_url][0]')
printf "Download url: %s\n" $JADX_DOWNLOAD_URL

wget -O $NAME $JADX_DOWNLOAD_URL

unzip -o $NAME # unzip and overwrite files

# '-f' option to replace symlink if it already exists.
ln -sf $INSTALL_DIRECTORY/bin/$JADX $BIN_DIRECTORY/$JADX
ln -sf $INSTALL_DIRECTORY/bin/$JADXGUI $BIN_DIRECTORY/$JADXGUI

rm *.zip
