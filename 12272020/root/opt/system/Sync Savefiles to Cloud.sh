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

# @todo These should come from parsing retroarch.cfg
CONTENT_DIRS_SAVES=true
CONTENT_DIRS_STATES=true

#########################
# SYNC SAVEFILES TO CLOUD
#########################
# Savefiles
printf "\nSyncing RetroArch savefiles with remote...\n" | tee -a "${LOG_FILE}"
if [ ${CONTENT_DIRS_SAVES} = true ]; then
	# Send
	rclone copy /roms/ ${REMOTE}:retroarch/roms/ --filter-from /roms/backup/rclone/rclone-filters.conf -v | tee -a "${LOG_FILE}"

	# Receive
	rclone copy ${REMOTE}:retroarch/roms/ /roms/ --filter-from /roms/backup/rclone/rclone-filters.conf -v | tee -a "${LOG_FILE}"
else
	# @todo This should come from parsing retroarch.cfg
	savesDir="/roms/retroarch/saves"

	# Send
	rclone copy ${savesDir}/ ${REMOTE}:retroarch/saves/ -v | tee -a "${LOG_FILE}"

	# Receive
	rclone copy ${REMOTE}:retroarch/saves/ ${savesDir}/ -v | tee -a "${LOG_FILE}"
fi

# Savestates
printf "\nSyncing RetroArch savestates with remote...\n" | tee -a "${LOG_FILE}"
if [ ${CONTENT_DIRS_STATES} = true ]; then
	# Send
	rclone copy /roms/ ${REMOTE}:retroarch/roms/ --filter "+ *.state*" --filter "- *" | tee -a "${LOG_FILE}"

	# Receive
	rclone copy ${REMOTE}:retroarch/roms/ /roms/ --filter "+ *.state*" --filter "- *" | tee -a "${LOG_FILE}"
else
	# @todo This should come from parsing retroarch.cfg
	statesDir="/roms/retroarch/states"

	# Send
	rclone copy ${statesDir}/ ${REMOTE}:retroarch/states/ -v | tee -a "${LOG_FILE}"

	# Receive
	rclone copy ${REMOTE}:retroarch/states/ ${statesDir}/ -v | tee -a "${LOG_FILE}"
fi

# Amiberry Savestates
printf "\nSyncing Amiberry savestates with remote...\n" | tee -a "${LOG_FILE}"
# Send
rclone copy /opt/amiberry/savestates/ ${REMOTE}:amiberry/savestates/ -v | tee -a "${LOG_FILE}"

# Receive
rclone copy ${REMOTE}:amiberry/savestates/ /opt/amiberry/savestates/ -v | tee -a "${LOG_FILE}"

##########
# TEARDOWN
##########
# Release input
if [ ! -z ${STANDALONE} ]; then
	sudo kill $(pidof rg351p-js2xbox)
	sudo rm /dev/input/by-path/platform-odroidgo2-joypad-event-joystick
fi
