#!/bin/bash
# rclone cloud syncing for ArkOS
# by ridgek
#
# @param $1 {string} systemd-escape string in format: remoteDir@localDir
#
#	@usage
#		$ /opt/arklone/arklone.sh retroarch-roms\x40-roms.service
###########
# PREFLIGHT
###########
LOCALDIR=${1#*@}
REMOTEDIR=${1%@*}
REMOTE=$(awk '{print $1}' /opt/arklone/rclone/remote.conf)
RETROARCH_CONFIGS=(/home/ark/.config/retroarch/retroarch.cfg /home/ark/.config/retroarch32/retroarch.cfg)
LOG_FILE=/home/ark/arklone.log

# Delete log if last modification is older than system uptime
if [ -f "${LOG_FILE}" ] && [ $(($(date +%s) - $(date +%s -r "${LOG_FILE}"))) -gt $(awk -F . '{print $1}' "/proc/uptime") ]; then
	rm -f "${LOG_FILE}"
fi

# Begin logging
touch "${LOG_FILE}" && chown ark:ark "${LOG_FILE}" && chmod a+r+w "${LOG_FILE}" && exec &> >(tee -a "${LOG_FILE}")

printf "\n======================================================\n"
echo "Started new cloud sync at $(date)"
echo "------------------------------------------------------"

# Exit if no internet
if ! : >/dev/tcp/8.8.8.8/53; then
	echo "No internet connection. Exiting..."
	exit
fi

# Exit if nothing to do
if [ "${LOCALDIR}" = "/roms" ]; then
	continueSync=false

	for config in ${RETROARCH_CONFIGS[@]}; do
		savefiles_in_content_dir=$(awk '/^savefiles_in_content_dir/{ gsub("\"","",$3); print $3}' "${config}")
		savestates_in_content_dir=$(awk '/^savestates_in_content_dir/{ gsub("\"","",$3); print $3}' "${config}")

		if [ "${savefiles_in_content_dir}" = "true" ] || [ "${savestates_in_content_dir}" = "true" ]; then
			continueSync=true
			break;
		fi
	done

	if [ "${continueSync}" != "true" ]; then
		echo "Nothing to do. Exiting..."
		exit
	fi
fi

#########################
# SYNC SAVEFILES TO CLOUD
#########################
echo "Sending ${LOCALDIR}/ to ${REMOTE}:${REMOTEDIR}/"
rclone copy "${LOCALDIR}/" "${REMOTE}:${REMOTEDIR}/" --filter-from /opt/arklone/rclone/filters.conf -v

echo "Receiving ${REMOTE}:${REMOTEDIR}/ to ${LOCALDIR}/"
rclone copy "${REMOTE}:${REMOTEDIR}/" "${LOCALDIR}/" --filter-from /opt/arklone/rclone/filters.conf -v

##########
# TEARDOWN
##########
echo "Finished cloud sync at $(date)"
