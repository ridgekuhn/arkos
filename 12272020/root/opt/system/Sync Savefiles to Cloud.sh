#!/bin/bash
# ArkOS Sync Savefiles to Cloud
# By ridgek
###########
# PREFLIGHT
###########
# Capture input if script is running standalone
# (If script was called from "/opt/system/Advanced/Backup Settings to Cloud.sh", the process is already running)
if [ -z rg351p-js2box ]; then
	STANDALONE=true
	sudo rg351p-js2xbox --silent -t oga_joypad &
	sudo ln -s /dev/input/event3 /dev/input/by-path/platform-odroidgo2-joypad-event-joystick
	sudo chmod 777 /dev/input/by-path/platform-odroidgo2-joypad-event-joystick
fi

LOG_FILE="/roms/backup/rcloud.log"
RETROARCH_CONFIGS=(/home/ark/.config/retroarch/retroarch.cfg /home/ark/.config/retroarch32/retroarch32.cfg)

# Get user's cloud storage selection
REMOTE="remote"
# @todo What's the best way to implement user selection?
#				A select list would be ideal, instead of having the user type it in
# REMOTE=`osk "Enter the name of the remote" | tail -n 1`

# Logging
if [ -f "${LOG_FILE}" ]; then
	rm "${LOG_FILE}"
fi

touch "${LOG_FILE}"

#########################
# SYNC SAVEFILES TO CLOUD
#########################
# retroarch and retroarch32
for config in ${RETROARCH_CONFIGS[@]}; do
	savetypes=(savefile savestate)

	# Loop through savetypes
	for savetype in ${savetypes[@]}; do
		# Savefiles
		savetypes_in_content_dir=$(awk '/^'${savetype}'s_in_content_dir/{ gsub("\"","",$3); print $3}' "${config}")

		printf "\nSyncing RetroArch ${savetype}s with ${REMOTE}...\n" | tee -a "${LOG_FILE}"

		if [ ${savetypes_in_content_dir} = true ]; then
			# Send
			rclone copy "/roms/" "${REMOTE}:retroarch/roms/" --filter-from /roms/backup/rclone/rclone-filters.conf -v | tee -a "${LOG_FILE}"

			# Receive
			rclone copy "${REMOTE}:retroarch/roms/" "/roms/" --filter-from /roms/backup/rclone/rclone-filters.conf -v | tee -a "${LOG_FILE}"
		else
			savetype_directory=$(awk '/^'${savetype}'_directory/{ gsub("\"","",$3); print $3}' "${config}")

			# Send
			rclone copy "${savetype_directory}/" "${REMOTE}:retroarch/${savetype}/" -v | tee -a "${LOG_FILE}"

			# Receive
			rclone copy "${REMOTE}:retroarch/saves/" "${savetype_directory}/" -v | tee -a "${LOG_FILE}"
		fi
	done
done

# Amiberry Savestates
printf "\nSyncing Amiberry savestates with ${REMOTE}...\n" | tee -a "${LOG_FILE}"

# Send
rclone copy "/opt/amiberry/savestates/" "${REMOTE}:amiberry/savestates/" -v | tee -a "${LOG_FILE}"

# Receive
rclone copy "${REMOTE}:amiberry/savestates/" "/opt/amiberry/savestates/" -v | tee -a "${LOG_FILE}"

##########
# TEARDOWN
##########
# Release input
if [ ! -z ${STANDALONE} ]; then
	sudo kill $(pidof rg351p-js2xbox)
	sudo rm /dev/input/by-path/platform-odroidgo2-joypad-event-joystick
fi
