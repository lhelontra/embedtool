#!/bin/bash
#
# embedtool - executed after an image is generated & formatted
# 
# bootfs mountpoint: "$BUILDIMAGE_MOUNTPOINT"/"$BOOTFS_MOUNTPOINT"/
# rootfs mountpoint: "$BUILDIMAGE_MOUNTPOINT"/
#

local POSTGEN_DIR="$(dirname ${BASH_SOURCE[0]})"
local BL1="${POSTGEN_DIR}/boot/bl1.bin.hardkernel"
local UBOOT="${POSTGEN_DIR}/boot/u-boot.bin"

log_app_msg "Installing $BL1"
dd if=$BL1 of=$LOOPDEV conv=fsync bs=1 count=442 status=none || {
	log_failure_msg "error on installing $BL1"
	return 1
}

dd if=$BL1 of=$LOOPDEV conv=fsync bs=512 skip=1 seek=1 status=none || {
	log_failure_msg "error on installing $BL1"
	return 1
}

log_app_msg "Installing $UBOOT"
dd if=$UBOOT of=$LOOPDEV conv=fsync bs=512 seek=97 status=none || {
	log_failure_msg "error on installing $UBOOT"
	return 1
}

return 0
