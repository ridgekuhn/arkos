#!/bin/bash
# arklone settings utility
# by ridgek
########
# CONFIG
########
source "/opt/arklone/config.sh"

#########
# HELPERS
#########
# Print items formatted for whiptail menu
#
# @param $1 {string} space-delimited array of menu options
#
# @returns {string} space-delimited array of menu indexes and options
function printMenu() {
	local items=($1)

	for (( i = 0; i < ${#items[@]}; i++ )); do
		printf "$i ${items[i]} "
	done
}

# Get instance names of all systemd path modules
#
# @returns {string} space-delimted array of unescaped instance names
function getInstanceNames() {
	local units=($(find "${ARKLONE_DIR}/systemd/"*".path"))

	for (( i = 0; i < ${#units[@]}; i++ )); do
		local escapedName=$(awk -F '@' '/Unit/ {split($2, arr, ".service"); print arr[1]}' "${units[i]}")
		local instanceName=$(systemd-escape -u -- "${escapedName}")

		printf "${instanceName} "
	done
}

# Check if script is already running
#
# $log_file is passed in as an argument instead of detected in this function
# for sanity when referencing the same $log_file in the caller function
#
# @param $1 {string} executable command

# @param [$2] {string} path to log file
function alreadyRunning() {
	local script="${1}"

	if [ ! -z $2 ]; then
		local log_file="${2}"
	else
		local log_file=$(awk '/^LOG_FILE/ { split($1, a, "="); gsub("\"", "", a[2]); print a[2]}' "${ARKLONE_DIR}/${script}")
	fi

	local running=$(pgrep "${script}")

	if [ ! -z "${running}" ]; then
		whiptail \
			--title "${TITLE}" \
			--yesno \
				"${script} is already running. Would you like to see the 10 most recent lines of the log file?" \
				16 60

		if [ $? = 0 ]; then
			whiptail \
				--title "${log_file}" \
				--scrolltext \
				--msgbox \
					"$(tail -10 ${log_file})" \
					16 60
		fi

		return 1
	fi
}

###########
# PREFLIGHT
###########
TITLE="arklone cloud sync utility"
INSTANCES=$(getInstanceNames)

#######
# VIEWS
#######
# Point-of-entry dialog
function homeScreen() {
	# Set automatic sync mode string
	if [ -z "${AUTOSYNC}" ]; then
		local able="Enable"
	else
		local able="Disable"
	fi

	local selection=$(whiptail \
		--title "${TITLE}" \
		--menu "Choose an option:" \
			16 60 8 \
			"1" "Set cloud service (now: ${REMOTE_CURRENT})" \
			"2" "Manual sync savefiles/savestates" \
			"3" "${able} automatic saves sync" \
			"4" "Manual backup/sync ArkOS Settings" \
			"x" "Exit" \
		3>&1 1>&2 2>&3 \
	)

	case $selection in
		1) setCloudScreen ;;
		2) manualSyncSavesScreen ;;
		3) autoSyncSavesScreen ;;
#		4) manualBackupArkOSScreen ;;
	esac
}

# Cloud service selection dialog
#
# Saves selection to $ARKLONE_DIR/$REMOTE_CONF
function setCloudScreen() {
	local selection=$(whiptail \
		--title "${TITLE}" \
		--menu \
			"Choose a cloud service:" \
			16 60 8 \
			$(printMenu "${REMOTES}") \
		3>&1 1>&2 2>&3 \
	)

	if [ ! -z $selection ]; then
		local remotes=(${REMOTES})

		# Save selection to conf file
		echo ${remotes[$selection]} > $REMOTE_CONF

		# Reset string for current remote (for printing in homeScreen)
		REMOTE_CURRENT=$(awk "{print $1}" "${REMOTE_CONF}")
	fi

	homeScreen
}

# Manual sync savefiles/savestates dialog
function manualSyncSavesScreen() {
	local script="arklone-saves.sh"
	local log_file=$(awk '/^LOG_FILE/ { split($1, a, "="); gsub("\"", "", a[2]); print a[2]}' "${ARKLONE_DIR}/${script}")
	local localdirs=$(for instance in ${INSTANCES[@]}; do printf "${instance%@*@*} "; done)

	alreadyRunning "${script}" "${log_file}"

	if [ $? != 0 ]; then
		homeScreen
	else
		local selection=$(whiptail \
			--title "${TITLE}" \
			--menu \
				"Choose a directory pair to sync with (${REMOTE_CURRENT}):" \
				16 60 8 \
				$(printMenu "${localdirs}") \
			3>&1 1>&2 2>&3 \
		)

		if [ ! -z $selection ]; then
			local instances=(${INSTANCES})
			local instance=${instances[$selection]}
			IFS="@" read -r LOCALDIR REMOTEDIR FILTER <<< "${instance}"

			# Sync the local and remote directories
			"${ARKLONE_DIR}/${script}" "${instance}"

			if [ $? = 0 ]; then
				whiptail \
					--title "${TITLE}" \
					--msgbox \
						"${LOCALDIR} synced to ${REMOTE_CURRENT}:${REMOTEDIR}. Log saved to ${log_file}." \
						16 80 8
			else
				whiptail \
					--title "${TITLE}" \
					--msgbox \
						"Update failed. Please check your internet connection and settings." \
						16 80 8
			fi
		fi

		homeScreen
	fi
}

# Enable/Disable auto savefile/savestate syncing
function autoSyncSavesScreen() {
	# Enable if no units are detected
	if [ -z "${AUTOSYNC}" ]; then
		sudo systemctl link "${ARKLONE_DIR}/systemd/arkloned@.service"

		sudo find "${ARKLONE_DIR}/systemd/"*".path" \
			| xargs -I {} bash -c 'UNIT="{}" \
				&& sudo systemctl enable "${UNIT}" \
				&& sudo systemctl start "${UNIT##*/}"'

	# Disable activated units
	else
		sudo systemctl disable "arkloned@.service"

		for unit in ${AUTOSYNC[@]}; do
			sudo systemctl disable "${unit}"
		done
	fi

	# Reset able string
	AUTOSYNC=($(systemctl list-unit-files | awk '/arkloned/ && /enabled/ {print $1}'))

	homeScreen
}

# Manual backup ArkOS settings screen
# @TODO finish this
function manualBackupArkOSScreen() {
	local script="arklone-arkos.sh"
	local log_file=$(awk '/^LOG_FILE/ { split($1, a, "="); gsub("\"", "", a[2]); print a[2]}' "${ARKLONE_DIR}/${script}")

	alreadyRunning "${script}" "${log_file}"

	if [ $? != 0 ]; then
		homeScreen
	else
		echo todo

		homeScreen
	fi
}

#####
# RUN
#####
homeScreen
