#!/bin/bash
# arklone installation script
# by ridgek
########
# CONFIG
########
source "/opt/arklone/config.sh"

##############
# DEPENDENCIES
##############
# Create rclone user config dir
# rclone.conf is stored on EASYROMS partition, link to ~/.config/rclone so rclone can find it
if [ ! -d "${USER_CONFIG_DIR}/rclone" ]; then
	sudo mkdir "${USER_CONFIG_DIR}/rclone" \
		&& sudo chown ark:ark "${USER_CONFIG_DIR}/rclone" \
		&& sudo chmod 755 "${USER_CONFIG_DIR}/rclone"
fi
sudo ln -s "/roms/backup/rclone/rclone.conf" "${USER_CONFIG_DIR}/rclone/rclone.conf"
sudo chmod 666 "/roms/backup/rclone/rclone.conf"

#########
# arklone
#########
# Grant permissions to scripts
sudo chmod -v a+r+x "${ARKLONE_DIR}/uninstall.sh"
sudo chmod -v a+r+x "${ARKLONE_DIR}/dialogs/settings.sh"
sudo chmod -v a+r+x "${ARKLONE_DIR}/arklone-saves.sh"
sudo chmod -v a+r+x "${ARKLONE_DIR}/arklone-arkos.sh"
sudo chmod -v a+r+x "${ARKLONE_DIR}/dialogs/settings.sh"

# Link settings dialog script to EmulationStation
sudo ln -s "${ARKLONE_DIR}/dialogs/settings.sh" "/opt/system/Cloud Settings.sh"

# Create arklone user config dir
if [ ! -d "${USER_CONFIG_DIR}/arklone" ]; then
	sudo mkdir "${USER_CONFIG_DIR}/arklone" \
		&& sudo chown ark:ark "${USER_CONFIG_DIR}/arklone" \
		&& sudo chmod a+r+w "${USER_CONFIG_DIR}/arklone"
fi
