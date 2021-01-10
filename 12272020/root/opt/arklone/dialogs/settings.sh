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
#
# @param [$2] {string} path to log file
#
# @returns 1 if $1 is an active process
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

# Check if RetroArch saves to content directory
#
# @returns 1 if no retroarch.cfg in ${RETROARCHS[@]} contains
#		savefiles_in_content_dir = "true" || savestates_in_content_dir = "true"
function raSavesInContentDir() {
	for retroarch_dir in ${RETROARCHS[@]}; do
		retroarch=${retroarch_dir##*/}

		for savetype in ${savetypes[@]}; do
			# Get settings from ${retroarch}/retroarch.cfg
			savetypes_in_content_dir=$(awk -v savetypes_in_content_dir="${savetype}s_in_content_dir" '$0~savetypes_in_content_dir { gsub("\"","",$3); print $3}' "${retroarch_dir}/retroarch.cfg")

			# Generate unit if ${savetype}s_in_content_dir = "false" in retroarch.cfg
			if [ "${savetypes_in_content_dir}" = "true" ]; then
				return 0
			fi
		done
	done

	return 1
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
			"5" "Regenerate RetroArch path units" \
			"x" "Exit" \
		3>&1 1>&2 2>&3 \
	)

	case $selection in
		1) setCloudScreen ;;
		2) manualSyncSavesScreen ;;
		3) autoSyncSavesScreen ;;
		4) manualBackupArkOSScreen ;;
		5) regenRAunitsScreen ;;
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
				"Choose a directory to sync with (${REMOTE_CURRENT}):" \
				16 60 8 \
				$(printMenu "${localdirs}") \
			3>&1 1>&2 2>&3 \
		)

		if [ ! -z $selection ]; then
			local instances=(${INSTANCES})
			local instance=${instances[$selection]}
			IFS="@" read -r localdir remotedir filter <<< "${instance}"

			# Sync the local and remote directories
			"${ARKLONE_DIR}/${script}" "${instance}"

			if [ $? = 0 ]; then
				whiptail \
					--title "${TITLE}" \
					--msgbox \
						"${localdir} synced to ${REMOTE_CURRENT}:${remotedir}. Log saved to ${log_file}." \
						16 56 8
			else
				whiptail \
					--title "${TITLE}" \
					--msgbox \
						"Update failed. Please check your internet connection and settings." \
						16 56 8
			fi
		fi

		homeScreen
	fi
}

# Enable/Disable auto savefile/savestate syncing
function autoSyncSavesScreen() {
	whiptail \
		--title "${TITLE}" \
		--infobox \
			"Please wait while we configure your settings..." \
			16 56 8

	# Enable if no units are linked to systemd
	if [ -z "${AUTOSYNC}" ]; then
		local units=($(find "${ARKLONE_DIR}/systemd/"*".path"))

		sudo systemctl link "${ARKLONE_DIR}/systemd/arkloned@.service"

		for unit in ${units[@]}; do
			# Skip enabling RetroArch content directory root unit for now
			if [ "${unit}" = "${ARKLONE_DIR}/systemd/arkloned-retroarch-contentroot.path" ]; then
				continue
			fi

			sudo systemctl enable "${unit}" \
				&& sudo systemctl start "${unit##*/}"
		done

		# Enable RetroArch content directory root unit
		# if any retroarch.cfg in ${RETROARCHS[@]} contains
		#	savefiles_in_content_dir = "true" || savestates_in_content_dir = "true"
		raSavesInContentDir

		if [ $? = 0 ]; then
			sudo systemctl enable "${ARKLONE_DIR}/systemd/arkloned-retroarch-contentroot.path" \
				&& sudo systemctl start "arkloned-retroarch-contentroot.path"
		fi

	# Disable enabled units
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
function manualBackupArkOSScreen() {
	local script="arklone-arkos.sh"
	local log_file=$(awk '/^LOG_FILE/ { split($1, a, "="); gsub("\"", "", a[2]); print a[2]}' "${ARKLONE_DIR}/${script}")

	alreadyRunning "${script}" "${log_file}"

	if [ $? != 0 ]; then
		homeScreen
	else
		whiptail \
			--title "${TITLE}" \
			--yesno \
				"This will create a backup of your settings at /roms/backup/arkosbackup.tar.gz. Do you want to keep this file after it is uploaded to ${REMOTE_CURRENT}?" \
				16 56

		keep=$?

		"${ARKLONE_DIR}/${script}"

		if [ $? = 0 ]; then
			if [ $keep != 0 ]; then
				sudo rm -v /roms/backup/arkosbackup.tar.gz
			fi

			whiptail \
				--title "${TITLE}" \
				--msgbox \
					"ArkOS backup synced to ${REMOTE_CURRENT}:ArkOS. Log saved to ${log_file}." \
					16 56 8
		else
			whiptail \
				--title "${TITLE}" \
				--msgbox \
					"Update failed. Please check your internet connection and settings." \
					16 56 8
		fi

		homeScreen
	fi
}

# Regenerate RetroArch savestates/savefiles units screen
function regenRAunitsScreen() {
	whiptail \
		--title "${TITLE}" \
		--infobox \
			"Please wait while we configure your settings..." \
			16 56 8

	"${ARKLONE_DIR}/generate-retroarch-units.sh"

	homeScreen
}

#####
# RUN
#####
homeScreen
