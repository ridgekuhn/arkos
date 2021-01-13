#!/bin/bash
# arklone retroarch systemd unit generator
# by ridgek
########
# CONFIG
########
source "/opt/arklone/config.sh"

#########
# HELPERS
#########
# Check if a unit for this path and ${savetype} (filter) already exists
#
# @param $1 {string} The local directory to watch
# @param $2 {string} The rclone filter in ${ARKLONE_DIR}/rclone/filters,
# 	named "retroarch-${savetype}" (no extension)
#
# @returns 1 if a unit already exists
function unitExists() {
	local localDir="${1}"
	local filter="${2}"
	local existingUnits=($(find "${ARKLONE_DIR}/systemd/units/"*".path"))

	for existingUnit in ${existingUnits[@]}; do
		local pathChanged=$(awk -F '=' '/PathChanged/ {print $2}' "${existingUnit}")
		local escInstanceName=$(awk -F "=" '/Unit/ {split($2, arr, "arkloned@"); print arr[2]}' "${existingUnit}")
		local existingFilter=$(systemd-escape -u -- "${escInstanceName}" | awk -F '@' '{split($3, arr, ".service"); print arr[1]}')

		if [ "${pathChanged}" = "${localDir}" ] && [ "${existingFilter}" = "${filter}" ]; then
			return 1
		fi
	done
}

# Make a new path unit
#
# If ! -z ${AUTOSYNC}, also enables and starts the new unit
#
# @param $1 {string} Absolute path to the new unit file. Must end in .auto.path
# @param $2 {string} The directory to watch for changes
# @param $3 {string} The remote directory to sync rclone to
# @param [$4] {string} The rclone filter in ${ARKLONE_DIR}/rclone/filters (no extension)
function makePathUnit() {
	local newUnit="${1}"
	local localDir="${2}"
	local remoteDir="${3}"
	local filter="${4}"

	local instanceName=$(systemd-escape "${localDir}@${remoteDir}@${filter}")

	# Skip if a unit already exists for this path
	unitExists "${localDir}" "${filter}"

	if [ $? != 0 ]; then
		echo "A path unit for ${filter} in ${localDir} already exists. Skipping..."
		return
	fi

	# Generate new unit
	echo "Generating new path unit: ${newUnit}"
	sudo cat <<EOF > "${newUnit}"
[Path]
PathChanged=${localDir}
Unit=arkloned@${instanceName}.service

[Install]
WantedBy=multi-user.target
EOF

	# Enable unit if auto-syncing is enabled
	if [ ! -z ${AUTOSYNC} ]; then
		sudo systemctl enable "${newUnit}" \
			&& sudo systemctl start "${newUnit##*/}"
	fi
}

# Recurse directory and make path units for subdirectories
#
# @param $1 {string} Absolute path to the directory to recurse
# @param $2 {string} Remote directory path
# @param $3 {string} The rclone filter in ${ARKLONE_DIR}/rclone/filters (no extension)
# @param [$4] {string} Absolute path to list of directory names to ignore
function makeSubdirPathUnits() {
	local subdirs=$(find "${1}" -mindepth 1 -maxdepth 1 -type d)
	local remoteDir="${2}"
	local filter="${3}"
	# @TODO move this to a separate file
	local ignoreDirs=("backup" "bios" "ports")

	# Workaround for subdirectory names with spaces
	local OIFS="$IFS"
	IFS=$'\n'

	for subdir in ${subdirs[@]}; do
		local unit="${ARKLONE_DIR}/systemd/units/arkloned-${remoteDir//\//-}-$(basename "${subdir//\ /_}").sub.auto.path"

		# Skip non-RetroArch subdirs
		if [ ! -z ${ignoreDirs} ]; then
			local skipDir=false

			for ignoreDir in ${ignoreDirs[@]}; do
				if [ "${subdir##*/}" = "${ignoreDir}" ]; then
					skipDir=true
				fi
			done

			if [ "${skipDir}" = "true" ]; then
				echo "${subdir} is in ignore list. Skipping..."
				continue
			fi
		fi

		makePathUnit "${unit}" "${subdir}" "${remoteDir}/${subdir##*/}" "${filter}"
	done

	# Reset workaround for directory names with spaces
	IFS="$OIFS"
}

#####
# RUN
#####
# Remove old units
OLD_UNITS=($(find "${ARKLONE_DIR}/systemd/units/arkloned-retroarch"*".auto.path" 2>/dev/null))

if [ ! -z ${OLD_UNITS} ]; then
	echo "Cleaning up old path units..."

	for OLD_UNIT in ${OLD_UNITS[@]}; do
		linked=$(systemctl list-unit-files | awk -v OLD_UNIT="${OLD_UNIT##*/}" '$0~OLD_UNIT {print $1}')

		printf "\nRemoving old unit: ${OLD_UNIT##*/}...\n"

		if [ ! -z $linked ]; then
			sudo systemctl disable "${OLD_UNIT##*/}"
		fi

		sudo rm -v "${OLD_UNIT}"
	done
fi

# Make RetroArch content path units
for retroarch_dir in ${RETROARCHS[@]}; do
	# Get retroarch or retroarch32
	retroarch=${retroarch_dir##*/}

	# Scenario 1:
	# savefiles_in_content_dir = "true" && savestates_in_content_dir = "true"

	# Scenario 2:
	# savefiles_in_content_dir = "false" && savestates_in_content_dir = "false" && savefile_directory == savestate_directory

	# Scenario 3:
	# Something else
	savetypes=("savefile" "savestate")

	for savetype in ${savetypes[@]}; do
		# Get settings from ${retroarch}/retroarch.cfg
		savetypes_in_content_dir=$(awk -v savetypes_in_content_dir="${savetype}s_in_content_dir" '$0~savetypes_in_content_dir { gsub("\"","",$3); print $3}' "${retroarch_dir}/retroarch.cfg")

		# Make RetroArch content directory units
		if [ "${savetypes_in_content_dir}" = "true" ]; then
			# Make RetroArch content root unit
			unit="${ARKLONE_DIR}/systemd/units/arkloned-${retroarch}-roms-${savetype}s.auto.path"
			makePathUnit "${unit}" "${RETROARCH_CONTENT_ROOT}" "${retroarch}/roms/${savetype}s" "retroarch-${savetype}"

			# Make RetroArch content subdirectory units
			# @TODO Neither `sort_${savetype}s_enable = "true"`
			# 	or `sort_${savetype}s_by_content_enable = "true"`
			#		appear to have any effect in this scenario.
			#		(Expected behavior is to
			#		store the saves in a subdirectory for each core
			#		eg, ${RETROARCH_CONTENT_ROOT}/nes/Nestopia)
			#		If this turns out to be incorrect,
			#		then we will need to recurse one more directory level:
			# systems=$(find "${RETROARCH_CONTENT_ROOT}" -mindepth 1 -maxdepth 1 -type d)
			# for system in ${systems[@]}; do
			# 	makeSubdirPathUnits "${system}" "${retroarch}" "retroarch-${savetype}"
			# done
			makeSubdirPathUnits "${RETROARCH_CONTENT_ROOT}" "${retroarch}/roms/${savetype}s" "retroarch-${savetype}"

			# Nothing else to do on this iteration, go to next ${savetype}
			continue
		fi

		# Get settings from ${retroarch}/retroarch.cfg
		savetype_directory=$(awk -v savetype_directory="${savetype}_directory" '$0~savetype_directory { gsub("\"","",$3); print $3}' "${retroarch_dir}/retroarch.cfg")
		sort_savetypes_enable=$(awk -v sort_savetypes_enable="sort_${savetype}s_enable" '$0~sort_savetypes_enable { gsub("\"","",$3); print $3}' "${retroarch_dir}/retroarch.cfg")

		# Convert home path shortcut
		if [ "${savetype_directory%%/*}" = "~" ]; then
			savetype_directory="/home/${USER}/${savetype_directory#*/}"
		fi

		# Make ${savetype_directory} root path unit
		unit="${ARKLONE_DIR}/systemd/units/arkloned-${retroarch}-${savetype}s.auto.path"
		makePathUnit "${unit}" "${savetype_directory}" "${retroarch}/${savetype}s" "retroarch-${savetype}"

		# Make ${savetype_directory} subdirectory path units
		if [ "${sort_savetypes_enable}" = "true" ]; then
			makeSubdirPathUnits "${savetype_directory}" "${retroarch}/${savetype}s" "retroarch-${savetype}"
		fi
	done
done
