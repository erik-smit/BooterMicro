#!/bin/bash
set -e

cd "$( dirname "${BASH_SOURCE[0]}" )" 

if [ -z "$1" ]; then
  echo "Usage: $0 pathtozip"
  exit
fi

ZIPNAME="$1"
IMGNAME="`dirname \"$ZIPNAME\"`/`basename \"$ZIPNAME\" .zip`.img"

FDOSNAME=mkbiosimg/fdboot.img

/sbin/mkfs.vfat -C "$IMGNAME" 65536 
mkbiosimg/sys-freedos.pl --disk="$IMGNAME"
rm -rf tmp
mkdir tmp
7z x -otmp "$FDOSNAME"
7z x -y -otmp "$ZIPNAME"
mcopy -i"$IMGNAME" tmp/* ::

pigz "$IMGNAME"
ls -la "$IMGNAME.gz"

