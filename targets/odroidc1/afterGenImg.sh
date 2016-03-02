#!/bin/bash
#
# embedtool - executed after an image is generated & formatted
#
# based on http://odroid.com/dokuwiki/doku.php?id=en:c1_ubuntu_minimal
# bootfs mountpoint: "$BUILDIMAGE_MOUNTPOINT"/"$BOOTFS_MOUNTPOINT"/
# rootfs mountpoint: "$BUILDIMAGE_MOUNTPOINT"/
#
local POSTGEN_DIR="$(dirname ${BASH_SOURCE[0]})"
# write mbr & U-boot
local BL1="${POSTGEN_DIR}/boot/bl1.bin.hardkernel"
local UBOOT="${POSTGEN_DIR}/boot/u-boot.bin"

tune2fs $ROOTFS -U e139ce78-9841-40fe-8823-96a304a09859 1>/dev/null || {
	log_failure_msg "error: tune2fs set uuid in $ROOTFS"
	return 1
}

dd if=$BL1 of=$LOOPDEV bs=1 count=442 conv=notrunc status=none || {
	log_failure_msg "error: write bl1 in $LOOPDEV"
	return 1
}
dd if=$BL1 of=$LOOPDEV bs=512 skip=1 seek=1 conv=notrunc status=none || {
	log_failure_msg "error: dd write bl1 in $LOOPDEV"
	return 1
}
dd if=$UBOOT of=$LOOPDEV bs=512 seek=64 conv=notrunc status=none || { 
	log_failure_msg "error: dd write uboot in $LOOPDEV"
	return 1
}

sync
return 0