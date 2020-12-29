#!/bin/bash
# Example whiptail dialog for ArkOS using RetroPie joy2key.py loader
# by ridgek
###########
# PREFLIGHT
###########
RETROPIE_HELPERS="/opt/joy2key/RetroPie-Setup/scriptmodules/helpers.sh"

if [ -f "${RETROPIE_HELPERS}" ]; then
	source "${RETROPIE_HELPERS}"

	# Required by joy2keyStart
	scriptdir="/opt/joy2key/RetroPie-Setup"
	# Arguments to pass to joy2keyStart (left, right, up, down, return, space, esc)
	keyconfig=(kcub1 kcuf1 kcuu1 kcud1 0x0a 0x20 0x1b)

	joy2keyStart ${keyconfig[@]}
else
	echo "joy2key.py not found"
	exit 1
fi

##############
# YOUR PROGRAM
##############

# !!! IMPORTANT !!!
# Do not run code directly here!
# If you do, and this script exits unexpectedly,
# joy2key will not be torn down
# and will continue to send keypresses from the joypad.
# This could cause unexpected behavior,
# especially if the analog sticks are "drifting"
bash "/run/my/script.sh"

##########
# TEARDOWN
##########
joy2keyStop
