#!/bin/bash
# arklone retroarch systemd unit generator
# by ridgek
########
# CONFIG
########
source "/opt/arklone/config.sh"

#####
# RUN
#####
for retroarch_dir in ${RETROARCHS[@]}; do
	retroarch=${retroarch_dir##*/}
	savetypes=("savefile" "savestate")

	for savetype in ${savetypes[@]}; do
		# Get settings from ${retroarch}/retroarch.cfg
		savetypes_in_content_dir=$(awk -v savetypes_in_content_dir="${savetype}s_in_content_dir" '$0~savetypes_in_content_dir { gsub("\"","",$3); print $3}' "${retroarch_dir}/retroarch.cfg")
		savetype_directory=$(awk -v savetype_directory="${savetype}_directory" '$0~savetype_directory { gsub("\"","",$3); print $3}' "${retroarch_dir}/retroarch.cfg")

		# Path to systemd unit
		unit="${ARKLONE_DIR}/systemd/arkloned-${retroarch}-${savetype}s.auto.path"
		# local_directory@remote_directory
		instanceName=$(systemd-escape "${savetype_directory}@${retroarch}/${savetype}s")
		# Check if unit is already registered with systemd
		linked=$(systemctl list-unit-files | awk -v unit="${unit##*/}" '$0~unit {print $1}')

		# Generate unit if ${savetype}s_in_content_dir = "false" in retroarch.cfg
		if [ "${savetypes_in_content_dir}" = "true" ]; then
			printf "${savetype}s_in_content_dir in ${retroarch_dir}/retroarch.cfg is set to "true". Skipping...\n\n"
		else
			# Remove old units
			if [ -f "${unit}" ]; then
				echo "Removing old ${unit}..."
				if [ ! -z $linked ]; then
					sudo systemctl disable ${unit##*/}
				fi

				sudo rm -v "${unit}"
			fi

			# Generate new unit
			printf "Generating new ${unit}...\n\n"
			sudo cat <<EOF > "${unit}"
[Path]
PathChanged=${savetype_directory}
Unit=arkloned@${instanceName}.service

[Install]
WantedBy=multi-user.target
Wants=network-online.target
After=network-online.target
EOF
		fi
	done
done
