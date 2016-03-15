#!/bin/bash
#
# embedtool - executed after an image is generated & formatted after copying script example
#
# bootfs mountpoint: "$BUILDIMAGE_MOUNTPOINT"/"$BOOTFS_MOUNTPOINT"/
# rootfs mountpoint: "$BUILDIMAGE_MOUNTPOINT"/
#

# habilita o resize
touch "$BUILDIMAGE_MOUNTPOINT"/root/.need_resize &>/dev/null
# remove o arquivo do serial
rm "$BUILDIMAGE_MOUNTPOINT"/root/.serial.txt &>/dev/null

return 0
