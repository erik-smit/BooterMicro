#!/bin/bash 

set -x
set -e

rm -rf tmp
mkdir tmp
pushd tmp
find ../Firmware -type f -name *.img.gz | sort | while IFS=/ read FOO Firmware BOARD bios VER FILE; do 
  if echo $BOARD | grep -q ^X10; then
    GROUPLENGTH=4
  elif echo $BOARD | grep -q ^X; then
    GROUPLENGTH=3
  else
    GROUPLENGTH=2
  fi

  GROUP=`echo $BOARD | cut -c1-$GROUPLENGTH`
  SMNAME=${FILE/.img.gz/}

  if [ ! -e ${GROUP}.cfg ]; then
    echo "MENU BEGIN $GROUP" > ${GROUP}.cfg
  fi

  echo "LABEL $SMNAME" >> ${GROUP}.cfg
  echo "MENU LABEL Supermicro $BOARD ($VER) ($SMNAME)" >> ${GROUP}.cfg
  echo "LINUX memdisk" >> ${GROUP}.cfg
  echo "INITRD BooterMicro/Firmware/$BOARD/$bios/$VER/$FILE" >> ${GROUP}.cfg
  echo "" >> ${GROUP}.cfg
done

echo 'MENU BEGIN Supermicro Motherboard BIOS/UEFI updates' > ../BooterMicro.cfg
for i in *.cfg; do
  echo "MENU END" >> $i
  echo "INCLUDE pxelinux.cfg/BooterMicro/$i" >> ../BooterMicro.cfg
done
echo 'MENU END' >> ../BooterMicro.cfg

popd

rm -rf ../pxelinux.cfg/BooterMicro
mv tmp ../pxelinux.cfg/BooterMicro
mv BooterMicro.cfg ../pxelinux.cfg/BooterMicro.cfg
