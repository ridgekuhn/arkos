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
	# Begin logging
	if [ ! -f "${LOG_FILE}" ]; then
		touch "${LOG_FILE}"
	fi

	exec &> >(tee -a "${LOG_FILE}")

	printf "\nInstalling cloud sync services\n"

	# Install rclone
	if ! rclone --version &> /dev/null; then
		sudo apt update && sudo apt install rclone -y || (echo "Could not install required dependencies" && exit 1)
	fi

	# Install pyudev
	if ! python3 -c 'help("modules")' | grep pyudev &> /dev/null; then
		sudo apt install python3-pyudev
	fi

	# Install update
	sudo wget ${RIDGEK_URL}/arkosupdate${RIDGEK_DATE}.zip -O /home/ark/arkosupdate${RIDGEK_DATE}.zip
	if [ -f "/home/ark/arkosupdate${RIDGEK_DATE}.zip" ]; then
		# Payload
		sudo unzip -X -o /home/ark/arkosupdate${RIDGEK_DATE}.zip -d /
		sudo rm -v /home/ark/arkosupdate${RIDGEK_DATE}.zip

		# Set up arklone
		sudo systemctl link "/opt/arklone/arkloned@.service"
		sudo find "/opt/arklone/arkloned"*".path" | xargs -I {} bash -c "sudo systemctl link {}"
		sudo chmod -v a+x "/opt/arklone/arklone.sh"
		sudo chmod -v a+x "/opt/arklone/arklone-arkos.sh"
		# Set up EmulationStation scripts
		sudo chmod -v a+x "/opt/arklone/Cloud Settings.sh"
		sudo ln -s "/opt/arklone/emulationstation/Cloud Settings.sh" "/opt/system/Cloud Settings.sh"
		# rclone.conf is stored on EASYROMS partition, link to ~/.config/rclone so rclone can find it
		ln -s /roms/backup/rclone.conf /home/ark/.config/rclone/rclone.conf
		sudo chmod 666 /roms/back/rclone/rclone.conf

		# Set up joy2key
		sudo chmod -v a+x "/opt/joy2key/listen.sh"
		sudo chmod -v a+x "/opt/joy2key/RetroPie-Setup/scriptmodules/helpers.sh"
		sudo chmod -v a+x "/opt/joy2key/RetroPie-Setup/scriptmodules/supplementary/runcommand/joy2key.py"
	else
		printf "\nThe update couldn't complete because the package did not download correctly.\nPlease retry the update again."
		echo $c_brightness > /sys/devices/platform/backlight/backlight/backlight/brightness
		exit 1
	fi

	if [ -f "/home/ark/.config/.update${RIDGEK_DATE}" ]; then
	printf "\nUpdate boot text to reflect current version of ArkOS\n"
		sudo sed -i "/title\=/c\title\=ArkOS 1.5 ($UPDATE_DATE)" /usr/share/plymouth/themes/text.plymouth
	else
		printf "\nThe update couldn't complete because the package did not download correctly.\nPlease retry the update again."
		echo $c_brightness > /sys/devices/platform/backlight/backlight/backlight/brightness
		exit 1
	fi

	touch "/home/ark/.config/.update${RIDGEK_DATE}"
fi
