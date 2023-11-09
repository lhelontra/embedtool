#!/bin/bash
#
# embedtool - executed after an image is generated & formatted after copying script example
#
# bootfs mountpoint: "$BUILDIMAGE_MOUNTPOINT"/"$BOOTFS_MOUNTPOINT"/
# rootfs mountpoint: "$BUILDIMAGE_MOUNTPOINT"/
#

sed -i '8d' "$BUILDIMAGE_MOUNTPOINT"/usr/local/bin/expand-rootfs.sh

return 0
