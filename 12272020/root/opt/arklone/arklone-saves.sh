#!/bin/bash
# rclone cloud syncing for ArkOS
# by ridgek
#
# @param $1 {string} directory paths in format: "sourceDir@targetDir@filterFile"
#
#	@usage
#		$ /opt/arklone/arklone.sh "/roms@retroarch/roms"
########
# CONFIG
########
source "/opt/arklone/config.sh"

###########
# PREFLIGHT
###########
IFS="@" read -r LOCALDIR REMOTEDIR FILTER <<< "${1}"
LOG_FILE="${USER_CONFIG_DIR}/arklone/arklone-saves.log"

# Delete log if last modification is older than system uptime
if [ -f "${LOG_FILE}" ] \
	&& [ $(($(date +%s) - $(date +%s -r "${LOG_FILE}"))) -gt $(awk -F . '{print $1}' "/proc/uptime") ]
then
	rm -f "${LOG_FILE}"
fi

# Begin logging
if touch "${LOG_FILE}" \
	&& chown ark:ark "${LOG_FILE}" \
	&& chmod a+r+w "${LOG_FILE}"
then
	exec &> >(tee -a "${LOG_FILE}")
else
	echo "Could not open log file. Exiting..."
	exit 1
fi

printf "\n======================================================\n"
echo "Started new cloud sync at $(date)"
echo "------------------------------------------------------"

# Exit if no internet
if ! : >/dev/tcp/8.8.8.8/53; then
	echo "No internet connection. Exiting..."
	exit 1
fi

# Exit if nothing to do
if [ "${LOCALDIR}" = "/roms" ]; then
	continueSync=false

	for retroarch in ${RETROARCHS[@]}; do
		savefiles_in_content_dir=$(awk '/^savefiles_in_content_dir/{ gsub("\"","",$3); print $3}' "${retroarch}/retroarch.cfg")
		savestates_in_content_dir=$(awk '/^savestates_in_content_dir/{ gsub("\"","",$3); print $3}' "${retroarch}/retroarch.cfg")

		if [ "${savefiles_in_content_dir}" = "true" ] \
			|| [ "${savestates_in_content_dir}" = "true" ]
		then
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
if [ ! -z "${FILTER}" ]; then
	FILTER_STRING="--filter-from \"/opt/arklone/rclone/${FILTER}.filter\""
fi

echo "Sending ${LOCALDIR}/ to ${REMOTE_CURRENT}:${REMOTEDIR}/"
rclone copy "${LOCALDIR}/" "${REMOTE_CURRENT}:${REMOTEDIR}/" -v ${FILTER_STRING}

echo "Receiving ${REMOTE_CURRENT}:${REMOTEDIR}/ to ${LOCALDIR}/"
rclone copy "${REMOTE_CURRENT}:${REMOTEDIR}/" "${LOCALDIR}/" -v ${FILTER_STRING}

##########
# TEARDOWN
##########
echo "Finished cloud sync at $(date)"
