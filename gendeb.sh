#!/bin/bash

TEMPDIR=".tmp"
mkdir -p ${TEMPDIR}/DEBIAN/
mkdir -p ${TEMPDIR}/usr/local/sbin/
mkdir -p ${TEMPDIR}/usr/local/share/embedtool/

cp embedtool.sh ${TEMPDIR}/usr/local/sbin/embedtool
chmod +x ${TEMPDIR}/usr/local/sbin/embedtool
cp -R targets/ ${TEMPDIR}/usr/local/share/embedtool/

sizeof=$(du -b ${TEMPDIR}/usr/ | tail -n1 | awk '{ print $1 }')
version="0.1.4"
arch="all"

cat <<-EOF > ${TEMPDIR}/DEBIAN/control
Package: embedtool
Priority: extra
Section: utils
Installed-Size: $sizeof
Maintainer: lhe.lontra@gmail.com
Architecture: $arch
Version: $version
Depends: mount (>= 2.25.2-6), util-linux (>=2.25.2-6), rsync (>=3.1.1-3), kpartx (>= 0.6.4-5), qemu-user-static (>= 1:2.1), e2fsprogs (>= 1.45.5)
Description: Script to help customization firmwares, uses the image of the environment / directory to crosscompiler. The premise is to use an image or directory with the system to make the crosscompiler / customization operations, and finally generate the desired image.
EOF

dpkg -b ${TEMPDIR} embedtool_${version}_${arch}.deb
rm -rf ${TEMPDIR}
