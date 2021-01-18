#!/bin/bash
# ArkOS Update Cloud Backup Update
# By ridgek
RIDGEK_DATE="20210118"
RIDGEK_LOCK="/home/ark/.config/.arklone${RIDGEK_DATE}"
# @todo Use production URL
# RIDGEK_URL="https://raw.githubusercontent.com/christianhaitian/arkos/main/${RIDGEK_DATE}"
RIDGEK_URL="https://raw.githubusercontent.com/ridgekuhn/arkos/cloudbackups/${RIDGEK_DATE}"
# @todo Delete this if this script gets appended to Update-RG351P.sh
RIDGEK_LOG="/home/ark/arklone${RIDGEK_DATE}.log"

if [ ! -f "${RIDGEK_LOCK}" ]; then
	# Begin logging
	if [ ! -f "${RIDGEK_LOG}" ]; then
		touch "${RIDGEK_LOG}"
	fi

	exec &> >(tee -a "${RIDGEK_LOG}")

	printf "\nInstalling cloud sync services\n"

	# Install update
	sudo wget ${RIDGEK_URL}/arkosupdate${RIDGEK_DATE}.zip -O /home/ark/arkosupdate${RIDGEK_DATE}.zip
	if [ -f "/home/ark/arkosupdate${RIDGEK_DATE}.zip" ]; then
		# Payload
		sudo unzip -X -o /home/ark/arkosupdate${RIDGEK_DATE}.zip -d /
		sudo rm -v /home/ark/arkosupdate${RIDGEK_DATE}.zip

		# Install arklone
		sudo chown -R ark:ark /opt/arklone \
			&& sudo chmod a+x "/opt/arklone/install.sh" \
			&& sudo chmod a+x "/opt/arklone/uninstall.sh"
		"/opt/arklone/install.sh"

		# Set up joy2key
		sudo chown -R ark:ark /opt/joy2key \
			&& sudo chmod a+x "/opt/joy2key/install.sh" \
			&& sudo chmod a+x "/opt/joy2key/uninstall.sh"
		"/opt/joy2key/install.sh"

		# Grant permissino to ES arklone launcher
		sudo chmod -v a+r+x "/opt/system/Cloud Settings.sh"

		# Modify es_systems.cfg
		sudo cp /etc/emulationstation/es_systems.cfg /etc/emulationstation/es_systems.cfg.arklone${RIDGEK_DATE}.bak

		oldESstring='<command>sudo chmod 666 /dev/tty1; %ROM% > /dev/tty1; printf "\\033c" >> /dev/tty1</command>'
		newESstring='<command>%ROM% \&lt;/dev/tty \&gt;/dev/tty 2\&gt;/dev/tty</command>'
		sudo sed -i "s|${oldESstring}|${newESstring}|" /etc/emulationstation/es_systems.cfg

		touch "${RIDGEK_LOCK}"
	else
		printf "\nThe update couldn't complete because the package did not download correctly.\nPlease retry the update again."
		exit 1
	fi
fi
