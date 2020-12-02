# ubuntu

Stuff related to the ubuntu platform used by raalabs

## autoinstaller boot image

Download the original installer image

`wget http://releases.ubuntu.com/20.04/ubuntu-20.04-live-server-amd64.iso`

Unpack the ISO image into a new folder called `ubuntu-content`

```bash
7z x ubuntu-20.04.1-live-server-amd64.iso -oubuntu-content
rm -rf ubuntu-content/'[BOOT]'
```

We need a folder to hold the boot files used during installation.
We need a file called `user-data` which will hold all the installation parameters.
We need a file called `meta-data` which the installation tool will use for meta data during the installation.

```bash
mkdir ./ubuntu-content/nocloud
touch ./ubuntu-content/nocloud/user-data
touch ./ubuntu-content/nocloud/meta-data
```

We can then fill the user-data file with the options we want.
NB: The formatting of the user-data file is YAML, so the indentation and format of the file is important. The example below might be outdated, use one of the user-data files in this repository that have no formmating who messes thing up.

`vi ./ubuntu-content/nocloud/user-data`

```config
#cloud-config
autoinstall:
  version: 1
  early-commands:
    - systemctl stop ssh # otherwise packer tries to connect and exceed max attempts
  network:
    network:
      version: 2
      ethernets:
        eth0:
          dhcp4: yes
          dhcp-identifier: mac
  apt:
    preserve_sources_list: false
    primary:
      - arches: [amd64]
        uri: "http://archive.ubuntu.com/ubuntu/"
  ssh:
    install-server: yes
    authorized-keys:
      - "your SSH pub key here"
    allow-pw: no
  identity:
    hostname: ubuntu-00
    password: "$6$exDY1mhS4KUYCE/2$zmn9ToZwTKLhCw.b4/b.ZRTIZM30JZ4QrOQ2aOXJ8yk96xpcCof0kxKwuX1kqLG/ygbJ1f8wxED22bTL4F46P0"
    username: ubuntu # root doesn't work
  packages:
    - open-vm-tools
  user-data:
    disable_root: false
  late-commands:
    - echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/ubuntu
    - sed -ie 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="net.ifnames=0 ipv6.disable=1 biosdevname=0"/' /target/etc/default/grub
    - curtin in-target --target /target update-grub2
```

### Config needed for ISOLINUX and creating a bootable ISO file

We then need to set the correct boot parameters for the ISO so it uses our installer script.

`vi ./ubuntu-content/isolinux/txt.cfg`

The original txt.cfg should look something like this

```config
default live
label live
  menu label ^Install Ubuntu Server
  kernel /casper/vmlinuz
  append   initrd=/casper/initrd quiet  ---
label live-nomodeset
  menu label ^Install Ubuntu Server (safe graphics)
  kernel /casper/vmlinuz
  append   initrd=/casper/initrd quiet  nomodeset ---
label memtest
  menu label Test ^memory
  kernel /install/mt86plus
label hd
  menu label ^Boot from first hard disk
  localboot 0x80
```

As we can see here it wants to default boot the label called `label live`, so we have do add config for where to find our `user-data` and `meta-data` files like this by editing the `append` line.

```config
default live
label live
  menu label ^Install Ubuntu Server
  kernel /casper/vmlinuz
  append   initrd=/casper/initrd quiet autoinstall ds=nocloud;s=/cdrom/nocloud/ ---
label live-nomodeset
  menu label ^Install Ubuntu Server (safe graphics)
  kernel /casper/vmlinuz
  append   initrd=/casper/initrd quiet  nomodeset ---
label memtest
  menu label Test ^memory
  kernel /install/mt86plus
label hd
  menu label ^Boot from first hard disk
  localboot 0x80
```

We then need to recreate a bootable iso file of the folder structure again with.

```bash
sudo mkisofs -o raalabs-ubuntu-20.04.iso -ldots -allow-multidot -d -r -l -J -no-emul-boot -boot-load-size 4 -boot-info-table -b isolinux/isolinux.bin -c isolinux/boot.cat ubuntu-content
```

### Config needed for GRUB and creating a bootable USB stick

To boot an USB stick it uses the grub boot loader, and not isolinux as it did with the ISO earlier.
This mean we have to edit the bootloader configuration and make it aware that we want it to autoinstall, and also where to find the autoinstal config file `user-data`.

Here is an example of the `/boot/grub/grub.cfg` file. This example is just put here to show what needs to be changed. The currently used and updated version resides in the `/boot/grub/` directory that is alongside this readme.

```cfg

if loadfont /boot/grub/font.pf2 ; then
	set gfxmode=auto
	insmod efi_gop
	insmod efi_uga
	insmod gfxterm
	terminal_output gfxterm
fi

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

set timeout=5
menuentry "Install RaaLabs Ubuntu Server" {
	set gfxpayload=keep
	linux	/casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ quiet  ---
	initrd	/casper/initrd
}
menuentry "Install Ubuntu Server (safe graphics)" {
	set gfxpayload=keep
	linux	/casper/vmlinuz   quiet  nomodeset ---
	initrd	/casper/initrd
}
grub_platform
if [ "$grub_platform" = "efi" ]; then
menuentry 'Boot from next volume' {
	exit
}
menuentry 'UEFI Firmware Settings' {
	fwsetup
}
fi
```

The specific line that have been changed is the line starting with `linux` which is the loading of the kernel parameters. We have just added the nocloud config part as paremeters to the loading of the kernel like this

`linux	/casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ quiet  ---`

If you want to use a web directory to serve the config file, the parameters should be changed to

`linux	/casper/vmlinuz autoinstall ds=nocloud-net\;s=http://my-config-files.com/ quiet  ---`

An important thing to notice is that Grub parses the config a bit differently than ISOlinux, so we need to escape the semicolon between the `ds=nocloud` and the `s=....` with a `\` as you can see in the config above. As mentioned, this is not necessary with the ISOlinux config, just the grub config.

To actually make the USB, we start by formatting an USB stick with a `fat32` filesystem.

Then copy all the content from where we earlier unpacked the live-iso and made our changes, into the USB drive. Use a command like this

```bash
cp -r <my-unpacked-live-folder>/* /media/bt/USB\ STICK/
```
The destination folder can vary on your system.

For the USB stick to be able to boot we also need a hidden folder from the unpacket live-iso directory called `.disk`. This must also be copied to the root of the usb stick like this.

```bash
cp -r <my-unpacked-live-folder>/.disk /media/bt/USB\ STICK/
```

## Apply specific config at first boot

Ubuntu uses Cloud Init for configuring the initial state of the system.
All configuration files for Cloud Init can be found int `/etc/cloud`.
If we want to add some specific config file we can do that by creating a config file under `/etc/cloud/cloud.cfg.d/`

The format of the config files and all the options can be found here:\
<https://cloudinit.readthedocs.io/en/latest/topics/examples.html>

The init will be run at first boot of the new system and the way it keeps track of earlier runs is by creating state content under `/var/lib/cloud/instance/`

If you have made any changes to the config file and you want to rerun the initial configuration you delete all the content in the state directory by:

`rm -rf /var/lib/cloud/instance/*`

And reboot the server.

### runcmd

runcmd will be run at first boot

Example use of run command

`/etc/cloud/cloud.cfg.d/99-message.cfg`

```yaml
# final_message
# default: cloud-init boot finished at $TIMESTAMP. Up $UPTIME seconds
# this message is written by cloud-final when the system is finished
# its first boot
final_message: "*** The system is finally up, after $UPTIME seconds ***"

runcmd:
 - [ ls, -l, / ]
 - [ sh, -xc, "echo $(date) ': hello world!'" ]
 - [ sh, -c, echo "=========hello world'=========" ]
 - ls -l /root
 # Note: Don't write files to /tmp from cloud-init use /run/somedir instead.
 # Early boot environments can race systemd-tmpfiles-clean LP: #1707222.
 - mkdir /run/mydir
 - [ wget, "http://slashdot.org", -O, /run/mydir/index.html ]
```

Another example of run command

```yaml
 final_message
# default: cloud-init boot finished at $TIMESTAMP. Up $UPTIME seconds
# this message is written by cloud-final when the system is finished
# its first boot
final_message: "*** The system is finally up, after $UPTIME seconds ***"

runcmd:
 - [ netplan, apply ]
```

When adding more cloud init files the should be put into the `/files` folder on the root level in the ISO image directory. If you look at the `/nocloud/user-data` file that is in the same directory as this readme you will see that there is specified a late-command right at the end that will copy over all the files that are in the /files directory over to the /target directory where /target will be the actual disk being installed into when this USB/ISO is booted later on.
By using this structure we can simpy add more cloud init files to be automatically executed on first bootup after installation is done by adding the appropriate init file into the `/files/etc/cloud/cloud.cfg.d` directory.
NB: Just make sure you add the same hierarchy in the `/files` folder as you want it to be on the actual installed server.

## References

<https://gist.github.com/s3rj1k/55b10cd20f31542046018fcce32f103e>\
<https://qiita.com/YasuhiroABE/items/637f1046a15938f9d3e9>\
<https://utcc.utoronto.ca/~cks/space/blog/linux/Ubuntu2004ISOWithUEFI>\
<https://help.ubuntu.com/community/Installation/iso2usb>\
<https://askubuntu.com/questions/1269961/establish-internet-connection-with-lte-card-and-netplan>

Example of user-datas files\
<https://gist.github.com/wpbrown/b688a934339cb4228c3faf5b527fbe5b>\
<https://gist.github.com/tlhakhan/97ee4d9f22eed7530c4be339a80a6f68>\
<https://gist.github.com/s3rj1k/55b10cd20f31542046018fcce32f103e>

Autoinstall references\
<https://ubuntu.com/server/docs/install/autoinstall-reference>\
<https://ubuntu.com/server/docs/install/autoinstall-quickstart>

How to make an ISO\
<https://ubuntuusertips.wordpress.com/2013/07/16/modify-an-iso-image-for-a-custom-install-cdrom/>

<https://curtin.readthedocs.io/en/latest/topics/overview.html>

<https://cloudinit.readthedocs.io/en/latest/topics/examples.html>

<http://ftp.labdoo.org/download/Public/manuals/manuals-ubuntu/EN/ubuntu-server-guide.pdf>