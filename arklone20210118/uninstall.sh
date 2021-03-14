#!/bin/bash
RIDGEK_DATE="20210118"
RIDGEK_LOCK="/home/ark/.config/.arklone${RIDGEK_DATE}"
# @todo Delete this if this script gets appended to Update-RG351P.sh
RIDGEK_LOG="/home/ark/arklone${RIDGEK_DATE}.log"

if [ -f "${RIDGEK_LOCK}" ]; then
	# Begin logging
	if [ ! -f "${RIDGEK_LOG}" ]; then
		touch "${RIDGEK_LOG}"
	fi

	exec &> >(tee -a "${RIDGEK_LOG}")

	printf "\nUninstalling cloud sync services\n"

	# Revert EmulationStation
	sudo cp /etc/emulationstation/es_systems.cfg.arklone${RIDGEK_DATE}.bak /etc/emulationstation/es_systems.cfg

	sudo rm -v "/opt/system/Cloud Settings.sh"

	# Remove joy2key
	"/opt/joy2key/uninstall.sh" \
		&& sudo rm -rfv "/opt/joy2key"

	# Remove arklone
	"/opt/arklone/uninstall.sh" \
		&& sudo rm -rfv "/opt/arklone"

	# Remove rclone
	sudo rm -rfv "/home/ark/.config/rclone"
	sudo rm -rfv "/roms/backup/rclone"
	sudo apt remove rclone -y

	sudo rm -v "${RIDGEK_LOCK}"
fi
