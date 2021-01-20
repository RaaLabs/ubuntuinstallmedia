# ubuntuinstallmedia

File structure used on the ubuntu install media

## Make iso file to be used to install on virtual machines etc

Clone this repository

`https://github.com/RaaLabs/ubuntuinstallmedia.git`

and run the create iso script

`./create-iso.sh`

## Make an USB install media

Clone this repository

`https://github.com/RaaLabs/ubuntuinstallmedia.git`

and run the create iso script

`./create-iso.sh`

Format an USB stick with fat32 filesystem.

Copy the content of the `ubuntu-content` folder to the USB stick

`cp -a ./ubuntu-content/* <usb stick>`