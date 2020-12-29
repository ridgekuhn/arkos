#!/bin/bash
# ArkOS Update Cloud Backup Update
# By ridgek
RIDGEK_DATE="12272020"
# @todo Use production URL
# RIDGEK_URL="https://raw.githubusercontent.com/christianhaitian/arkos/main/${RIDGEK_DATE}"
RIDGEK_URL="https://raw.githubusercontent.com/ridgekuhn/arkos/dropbox/${RIDGEK_DATE}"
# @todo Delete this if this script gets appended to Update-RG351P.sh
LOG_FILE="/home/ark/update${RIDGEK_DATE}.log"

if [ ! -f "/home/ark/.config/.update${RIDGEK_DATE}" ]; then
	printf "\nInstall cloud sync services\n" | tee -a "$LOG_FILE"

	# Install rclone
	if ! rclone --version &> /dev/null; then
		sudo apt update && sudo apt install rclone -y || (printf "\nCould not install required dependencies\n" | tee -a "$LOG_FILE" && exit 1)
	fi

	# Install pip
	if ! pip3 --version &> /dev/null; then
		sudo apt update && sudo apt install python3-pip -y || (printf "\nCould not install required dependencies\n" | tee -a "$LOG_FILE" && exit 1)
	fi

	# Install python modules
	if ! pip3 list | grep pyudev &> /dev/null; then
		pip3 install pyudev
	fi

	# Install update payload
	sudo wget ${RIDGEK_URL}/arkosupdate${RIDGEK_DATE}.zip -O /home/ark/arkosupdate${RIDGEK_DATE}.zip -a "$LOG_FILE"
	if [ -f "/home/ark/arkosupdate${RIDGEK_DATE}.zip" ]; then
		# Payload
		sudo unzip -X -o /home/ark/arkosupdate${RIDGEK_DATE}.zip -d / | tee -a "$LOG_FILE"
		sudo rm -v /home/ark/arkosupdate${RIDGEK_DATE}.zip | tee -a "$LOG_FILE"

		# Use symbolic link so rclone uses default config path, but file is still editable for end-users on EASYROMS partition
		ln -s /roms/backup/rclone/rclone.conf /home/ark/.config/rclone/rclone.conf

		# Grant executable permissions to new scripts
		sudo chmod -v a+x "/opt/joy2key/RetroPie-Setup/scriptmodules/helpers.sh" | tee -a "$LOG_FILE"
		sudo chmod -v a+x "/opt/joy2key/RetroPie-Setup/scriptmodules/supplementary/runcommand/joy2key.py" | tee -a "$LOG_FILE"
		sudo chmod -v a+x "/opt/system/Sync Savefiles to Cloud.sh" | tee -a "$LOG_FILE"
		sudo chmod -v a+x "/opt/system/Advanced/Backup Settings to Cloud.sh" | tee -a "$LOG_FILE"
	else
		printf "\nThe update couldn't complete because the package did not download correctly.\nPlease retry the update again." | tee -a "$LOG_FILE"
		echo $c_brightness > /sys/devices/platform/backlight/backlight/backlight/brightness
		exit 1
	fi

	if [ -f "/home/ark/.config/.update${RIDGEK_DATE}" ]; then
	printf "\nUpdate boot text to reflect current version of ArkOS\n" | tee -a "$LOG_FILE"
		sudo sed -i "/title\=/c\title\=ArkOS 1.5 ($UPDATE_DATE)" /usr/share/plymouth/themes/text.plymouth
	else
		printf "\nThe update couldn't complete because the package did not download correctly.\nPlease retry the update again." | tee -a "$LOG_FILE"
		echo $c_brightness > /sys/devices/platform/backlight/backlight/backlight/brightness
		exit 1
	fi

	touch "/home/ark/.config/.update${RIDGEK_DATE}"
fi
