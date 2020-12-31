# arklone #
rclone cloud syncing for ArkOS

---

This module contains three parts:
* A standalone script which syncs two directories using rclone
* A standalone script which syncs the ArkOS settings backup to the cloud
* A systemd service for monitoring RetroArch savefile/savestate directories
* A whiptail frontend for the script and service above

### arklone.sh ###
Syncs two directories using rclone

Executed by:
* [arkloned@.service]() when a corresponding _arkloned-*.path_ unit is started.
* [Cloud Saving.sh]() via EmulationStation
* Manually

To execute manually, pass two directories as a string to the first argument, in the format `remote@local`.
The directory string must be escaped as a systemd-escape string:

_Remote directory:_ `retroarch/roms`
_Local directory:_ `/roms`
_unescaped string:_ `retroarch/roms@/roms`
_escaped string:_ `retroarch-roms\x40-roms`

```shell
$ /opt/arklone/arklone.sh retroarch-roms\x40-roms

```

### arklone-arkos.sh ###
Calls the ArkOS backup script and syncs the resulting file to the cloud.

Executed by:
* [Cloud Settings.sh]() See below

### systemd units ###
Four path units are provided to the [arkloned@.service]() template:

* amiberry/savestates@/opt/amiberry/savestates
* retroarch/roms@/roms  
* retroarch/saves@/home/ark/.config/retroarch/saves 
* retroarch/states@/home/ark/.config/retroarch/states 

### Cloud Settings.sh ###
Four menu options are provided:
* Select cloud service
* Manual sync savefiles/savestates
* Enable/Disable automatic syncing
* Manual sync ArkOS Settings
