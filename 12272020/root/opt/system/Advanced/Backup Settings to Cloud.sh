#!/bin/bash
# ArkOS Backup Settings to Cloud
# By ridgek
###########
# PREFLIGHT
###########
# Use same log as "/opt/system/Advanced/Backup Settings.sh"
LOG_FILE="/roms/backup/arkosbackup.log"

# Capture input
sudo rg351p-js2xbox --silent -t oga_joypad &
sudo ln -s /dev/input/event3 /dev/input/by-path/platform-odroidgo2-joypad-event-joystick
sudo chmod 777 /dev/input/by-path/platform-odroidgo2-joypad-event-joystick

#######################
# BACKUP ARKOS TO CLOUD
#######################
# @todo Is there a way to just implement select boxes so the user doesn't have to type?
keep=`osk "This will create a backup of your settings at \"/roms/backup/arkosbackup.tar.gz\". Do you want to keep this file after it is uploaded to the cloud? (type \"y\" or \"n\")" | tail -n 1`

# Run normal ArkOS settings backup script
bash "/opt/system/Advanced/Backup Settings.sh"

if [ $? != 0 ]; then
	# Sync backup to cloud
	rclone copy /roms/backup/ remote:ArkOS/ -v | tee -a "${LOG_FILE}"

	if [ "${keep}" != "y" ] && [ "${keep}" != "Y" ]; then
		sudo rm -v /roms/backup/arkosbackup.tar.gz | tee -a "${LOG_FILE}"
	fi
else
	printf "\nCould not create backup file! Exiting...\n" | tee -a "${LOG_FILE}"
	exit 1
fi

# Sync save files to cloud
bash "/opt/system/Advanced/Sync Savefiles to Cloud.sh" | tee -a "${LOG_FILE}"

##########
# TEARDOWN
##########
# Release input
sudo kill $(pidof rg351p-js2xbox)
sudo rm /dev/input/by-path/platform-odroidgo2-joypad-event-joystick
