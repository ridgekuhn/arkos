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
# @param [$4] {string} The rclone filter in ${ARKLONE_DIR}/rclone/filters,
# 		named "retroarch-${savetype}" (no extension)
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
	echo "Generating new path unit: ${newUnit}..."
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
	savetypes=("savefile" "savestate")

	for savetype in ${savetypes[@]}; do
		# Get settings from ${retroarch}/retroarch.cfg
		savetypes_in_content_dir=$(awk -v savetypes_in_content_dir="${savetype}s_in_content_dir" '$0~savetypes_in_content_dir { gsub("\"","",$3); print $3}' "${retroarch_dir}/retroarch.cfg")

		# Make RetroArch content directory units
		if [ "${savetypes_in_content_dir}" = "true" ]; then
			subdirs=$(find ${RETROARCH_CONTENT_ROOT} -mindepth 1 -maxdepth 1 -type d)

			# Make RetroArch content root unit
			unit="${ARKLONE_DIR}/systemd/units/arkloned-${retroarch}-${savetype}s-${RETROARCH_CONTENT_ROOT##*/}.auto.path"

			printf "\nCreating new unit: ${unit}\n"

			makePathUnit "${unit}" "${RETROARCH_CONTENT_ROOT}" "${retroarch}/${RETROARCH_CONTENT_ROOT##*/}/${savetype}s" "retroarch-${savetype}"

			# Make RetroArch content root subdirectory units
			# @TODO neither sort_${savetype}s_enable or
			# 	sort_${savetype}s_by_content_enable
			#		appear to have any effect in this scenario.
			#		if this changes,
			#		then we will need to recurse one more directory level, like below
			for subdir in ${subdirs[@]}; do
				# Skip non-RetroArch subdirs
				# @TODO Use a blocklist file
				if [ "${subdir##*/}" = "backup" ] \
					|| [ "${subdir##*/}" = "bios" ] \
					|| [ "${subdir##*/}" = "ports" ]; then
					continue
				fi

				unit="${ARKLONE_DIR}/systemd/units/arkloned-${retroarch}-${savetype}s-${subdir##*/}.sub.auto.path"

				printf "\nCreating new unit: ${unit}\n"

				makePathUnit "${unit}" "${subdir}" "${retroarch}/${RETROARCH_CONTENT_ROOT##*/}/${savetype}s/${subdir##*/}" "retroarch-${savetype}"
			done

			# Nothing else to do on this iteration,
			# go to next ${savetype}
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

		printf "\nCreating new unit: ${unit}\n"

		makePathUnit "${unit}" "${savetype_directory}" "${retroarch}/${savetype}s" "retroarch-${savetype}"

		# Generate ${savetype_directory} subdirectory path units
		if [ "${sort_savetypes_enable}" = "true" ]; then
			# Workaround for filenames with spaces
			OIFS="$IFS"
			IFS=$'\n'

			# Get all subdirectories in ${savetype_directory}
			subdirs=$(find ${savetype_directory} -mindepth 1 -maxdepth 1 -type d)

			for subdir in ${subdirs[@]}; do
				# Workaround for filenames with spaces
				escSubdir=$(systemd-escape "${subdir##*/}")
				unit="${ARKLONE_DIR}/systemd/units/arkloned-${retroarch}-${savetype}s-${escSubdir}.sub.auto.path"

				printf "\nCreating new unit: ${unit}\n"

				makePathUnit "${unit}" "${subdir}" "${retroarch}/${savetype}s/${subdir##*/}" "retroarch-${savetype}"
			done

			# Reset workaround for filenames with spaces
			IFS="$OIFS"
		fi
	done
done
