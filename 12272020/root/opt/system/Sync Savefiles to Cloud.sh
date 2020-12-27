#!/bin/bash
# ArkOS Sync Savefiles to Cloud
# By ridgek
###########
# PREFLIGHT
###########
# Log file
LOG_FILE="/roms/backup/rcloud.log"

if [ -f "${LOG_FILE}" ]; then
	rm "${LOG_FILE}"
fi

touch "${LOG_FILE}"

# Capture input if script is running standalone
# (If script was called from "/opt/system/Advanced/Backup Settings to Cloud.sh", the process is already running)
if [ -z rg351p-js2box ]; then
	STANDALONE=true
	sudo rg351p-js2xbox --silent -t oga_joypad &
	sudo ln -s /dev/input/event3 /dev/input/by-path/platform-odroidgo2-joypad-event-joystick
	sudo chmod 777 /dev/input/by-path/platform-odroidgo2-joypad-event-joystick
fi

# Get user's cloud storage selection
REMOTE="remote"

# @todo What's the best way to implement user selection?
#				A select list would be ideal, instead of having the user type it in
# REMOTE=`osk "Enter the name of the remote" | tail -n 1`

#########################
# SYNC SAVEFILES TO CLOUD
#########################
# Send
printf "\nUploading new savefiles to remote...\n" | tee -a "${LOG_FILE}"
rclone copy /roms/retroarch/saves/ ${REMOTE}:retroarch/saves/ -v | tee -a "${LOG_FILE}"
rclone copy /roms/retroarch/states/ ${REMOTE}:retroarch/states/ -v | tee -a "${LOG_FILE}"
rclone copy /opt/amiberry/savestates/ ${REMOTE}:amiberry/savestates/ -v | tee -a "${LOG_FILE}"

# Receive
printf "\nDownloading new savefiles from remote...\n" | tee -a "${LOG_FILE}"
rclone copy ${REMOTE}:retroarch/saves/ /roms/retroarch/saves/ -v | tee -a "${LOG_FILE}"
rclone copy ${REMOTE}:retroarch/states/ /roms/retroarch/states/ -v | tee -a "${LOG_FILE}"
rclone copy ${REMOTE}:amiberry/savestates/ /opt/amiberry/savestates/ -v | tee -a "${LOG_FILE}"

##########
# TEARDOWN
##########
# Release input
if [ ! -z ${STANDALONE} ]; then
	sudo kill $(pidof rg351p-js2xbox)
	sudo rm /dev/input/by-path/platform-odroidgo2-joypad-event-joystick
fi
