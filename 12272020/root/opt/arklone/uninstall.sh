#!/bin/bash
###########
# PREFLIGHT
###########
source "/opt/arklone/config.sh"

UNITS=($(systemctl list-unit-files | awk '/arkloned/ && /enabled/ || linked {print $1}'))

#########
# arklone
#########
# Remove units from systemd
if [ ! -z $UNITS ]; then
	for unit in ${UNITS[@]}; do
		sudo systemctl disable "${unit}"
	done
fi

# Unlink settings dialog script from Emulationstation
sudo rm "/opt/system/Cloud Settings.sh"

# Remove arklone user config dir
sudo rm -r "${USER_CONFIG_DIR}/arklone"

# Print confirmation
echo "======================================================================"
echo "arklone has been uninstalled, but some files must be deleted manually:"
echo "${USER_CONFIG_DIR}/rclone/"
echo "/roms/backup/rclone.conf"
echo ""
echo "For the ultra-paranoid, please also check the directories listed here:"
echo "https://manpages.debian.org/buster/systemd/systemd.unit.5.en.html"
