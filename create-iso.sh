#!/bin/bash

# This script is for creating the RaaLabs install iso.
# The packages needed to be installed for this script are
# apt install p7zip git mkisofs

RELEASEISONAME="raalabs-ubuntu-20.04.1.iso"
IMAGEURL="https://releases.ubuntu.com/20.04.1/ubuntu-20.04.1-live-server-amd64.iso"
INSTALLREPO="git@github.com:RaaLabs/ubuntuinstallmedia.git"

wget $IMAGEURL
IMAGEFILE=$(basename $IMAGEURL)

UBUNTUCONTENT="ubuntu-content"
7z x $IMAGEFILE -o$UBUNTUCONTENT
rm -rf $UBUNTUCONTENT/'[BOOT]'

REPOFOLDER=$(basename $INSTALLREPO| awk -F'.' '{print $1}')
rm -rf $REPOFOLDER
git clone $INSTALLREPO

cp -a $REPOFOLDER/* $UBUNTUCONTENT

sudo mkisofs -o $RELEASEISONAME -ldots -allow-multidot -d -r -l -J -no-emul-boot -boot-load-size 4 -boot-info-table -b isolinux/isolinux.bin -c isolinux/boot.cat $UBUNTUCONTENT