#!/bin/bash
# ArkOS Update Cloud Backup Update
# By ridgek
RIDGEK_DATE="12272020"
# @todo Use production URL
# RIDGEK_URL="https://raw.githubusercontent.com/christianhaitian/arkos/main/${RIDGEK_DATE}"
RIDGEK_URL="https://raw.githubusercontent.com/ridgekuhn/arkos/cloudbackups/${RIDGEK_DATE}"
# @todo Delete this if this script gets appended to Update-RG351P.sh
LOG_FILE="/home/ark/update${RIDGEK_DATE}.log"
c_brightness="$(cat /sys/devices/platform/backlight/backlight/backlight/brightness)"

if [ ! -f "/home/ark/.config/.update${RIDGEK_DATE}" ]; then
	# Begin logging
	if [ ! -f "${LOG_FILE}" ]; then
		touch "${LOG_FILE}"
	fi

	exec &> >(tee -a "${LOG_FILE}")

	printf "\nInstalling cloud sync services\n"

	# Install update
	sudo wget ${RIDGEK_URL}/arkosupdate${RIDGEK_DATE}.zip -O /home/ark/arkosupdate${RIDGEK_DATE}.zip
	if [ -f "/home/ark/arkosupdate${RIDGEK_DATE}.zip" ]; then
		# Payload
		sudo unzip -X -o /home/ark/arkosupdate${RIDGEK_DATE}.zip -d /
		sudo rm -v /home/ark/arkosupdate${RIDGEK_DATE}.zip

		# Install arklone
		sudo chown -R ark:ark /opt/arklone \
			&& sudo chmod a+x "/opt/arklone/install.sh"
		"/opt/arklone/install.sh"

		# Set up joy2key
		sudo chown -R ark:ark /opt/joy2key \
			&& sudo chmod a+x "/opt/joy2key/install.sh"
		"/opt/joy2key/install.sh"

		# Grant permissino to ES arklone launcher
		sudo chmod -v a+r+x "/opt/system/Cloud Settings.sh"

		# Modify es_systems.cfg
		sudo cp /etc/emulationstation/es_systems.cfg /etc/emulationstation/es_systems.cfg.update${RIDGEK_DATE}.bak

		oldESstring='<command>sudo chmod 666 /dev/tty1; %ROM% > /dev/tty1; printf "\\033c" >> /dev/tty1</command>'
		newESstring='<command>%ROM% \&lt;/dev/tty \&gt;/dev/tty 2\&gt;/dev/tty</command>'
		sudo sed -i "s|${oldESstring}|${newESstring}|" /etc/emulationstation/es_systems.cfg
	else
		printf "\nThe update couldn't complete because the package did not download correctly.\nPlease retry the update again."
		echo $c_brightness > /sys/devices/platform/backlight/backlight/backlight/brightness
		exit 1
	fi

	if [ -f "/home/ark/.config/.update${RIDGEK_DATE}" ]; then
	printf "\nUpdate boot text to reflect current version of ArkOS\n"
		sudo sed -i "/title\=/c\title\=ArkOS 1.5 ($UPDATE_DATE)" /usr/share/plymouth/themes/text.plymouth
	else
		printf "\nThe update couldn't complete because there was a problem with the package.\nPlease retry the update again."
		echo $c_brightness > /sys/devices/platform/backlight/backlight/backlight/brightness
		exit 1
	fi

	touch "/home/ark/.config/.update${RIDGEK_DATE}"
fi
