# Squeezebox-CDRipper
Bundle of Squeezebox frontend CD ripping status and an automatic CD ripping system based on Whipper


How to install:
Download and install Lyrion Media Server on Debian. Check for the user (usually squeezeboxserver)
Download the full content of the repository, and extract it in : /var/lib/squeezeboxserver/Plugins

Modify the variables on top of the file /var/lib/squeezeboxserver/Plugins/CDRipStatus/bin/autorip.sh

This is the list of variables to check:
DRIVE="/dev/sr0" (maybe to modify)
CDROM_ID="/usr/lib/udev/cdrom_id" (maybe to modify)
MUSIC_DIR="/home/lyrionmusicserver/music" (set your music folder writable by Lyrion Server)
PLUGIN_DIR="/var/lib/squeezeboxserver/Plugins/CDRipStatus" (should not change)
LYRION_USER="squeezeboxserver" (should not change)


On first run, Whipper is certenly not installed.
Run /var/lib/squeezeboxserver/Plugins/CDRipStatus/bin/autorip.sh --configure
Follow the steps. Prepare a very common CD, as Whipper requires to test the DVD drive, and you want it to be compared to common CDs. This is automatic.

Finished. The script creats a systemd file which starts the automatic system in the background.
A menu in Lyrion will show up in the Apps section. This is showing up in the Web GUI but also on any Lyrion Device, like a Squeezebox Duet Controller.

Tested on a Mac Mini 2010 (with slot loading DVD Drive running Proxmox, and hosting Lyrion on a Debian 13 Virtual Machine.
Tested with a Squeezebox Duet Controller
