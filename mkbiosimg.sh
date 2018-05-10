#!/bin/bash
#
# PROG: Build a bootable disk image for PXE booting
#

set -e

cd "$( dirname "${BASH_SOURCE[0]}" )" 

if [ -z "$1" ]; then
  echo "Usage: $0 pathtozip"
  exit
fi

ZIPNAME="$1"
IMGNAME="`dirname \"$ZIPNAME\"`/`basename \"$ZIPNAME\" .zip`.img"

FDOSNAME=mkbiosimg/fdboot.img

#echo "==> MKFS.VFAT Create blank image"
if [ ! -x /sbin/mkfs.vfat ]; then
  echo " [!] ERROR: Cannot execute mkfs.vfat, exiting !"
  exit 1
else
  /sbin/mkfs.vfat -C "$IMGNAME" 65536 
fi

#echo "==> SYS-FREEDOS: Copy FreeDOS boot sector info"
mkbiosimg/sys-freedos.pl --disk="$IMGNAME"

#echo "==>  7Z: Expand fdBoot images accordingly. FDOSNAME=${FDOSNAME} ZIPNAME=${ZIPNAME}"
#echo "==> PWD: `pwd`"
rm -rf tmp
mkdir -p tmp/Update
7z x -otmp "$FDOSNAME"
7z x -otmp/Update "$ZIPNAME"

#echo "==> MCOPY: Copy contents to a single directory IMGNAME ${IMGNAME} to tmp/\*"
#echo "==>  PWD: `pwd`"
# -v = verbose, -s = recursive, -o = overwrite, -i = image
mcopy -s -o -i"$IMGNAME" tmp/*  ::

#echo "==> PIGZ: Compress the image accordingly as a final product IMGNAME=${IMGNAME}"
#echo "==>  PWD: `pwd`"
pigz "$IMGNAME"
ls -la "$IMGNAME.gz"

