#!/bin/bash
USER_CONFIG_DIR="/home/ark/.config"

RETROARCH_CONFIGS=(\
	"/home/ark/.config/retroarch/retroarch.cfg" \
	"/home/ark/.config/retroarch32/retroarch.cfg"\
)

ARKLONE_DIR="/opt/arklone"

REMOTES=$(rclone listremotes | awk -F : '{print $1}')
REMOTE_CONF="/home/ark/.config/arklone/remote.conf"
REMOTE_CURRENT=$(awk '{print $1}' "${REMOTE_CONF}")

AUTOSYNC=($(systemctl list-unit-files | awk '/arkloned/ && /enabled/ {print $1}'))
