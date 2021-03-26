#!/bin/bash 
set -x
set -e

rm -rf tmp
mkdir tmp

# Add menu header to start of BooterMicro's actual ipxe menu file.
echo '#!ipxe' > tmp/BooterMicro-LEGACY-MENUS.ipxe
echo ':start' >> tmp/BooterMicro-LEGACY-MENUS.ipxe
echo 'menu Bootermicro Firmware Updater/Installer - **LEGACY Mode**' >> tmp/BooterMicro-LEGACY-MENUS.ipxe

# Dig through the ./Firmware directory to figure out what Boards/Revisions/BIOS/etc. exist and add entries for 'em
find ./Firmware -type f -name *.gz | sort | while IFS=/ read FOO Firmware BOARD BIOS VER FILE; do 
  if echo $BOARD | grep -q ^X1; then
    GROUPLENGTH=4
  elif echo $BOARD | grep -q ^H1; then
    GROUPLENGTH=4
  elif echo $BOARD | grep -q ^X; then
    GROUPLENGTH=3
  elif echo $BOARD | grep -q ^H; then
    GROUPLENGTH=3
  else
    GROUPLENGTH=2
  fi

  GROUP="`echo $BOARD | cut -c1-$GROUPLENGTH`"

  # If a groups .ipxe files don't already exist, make the header info for the menu's, add 'em to the bootermicro menu, etc. upon first discovery.
  if [ ! -e tmp/${GROUP}-LEGACY-MENU.ipxe ]; then 
    echo "#!ipxe" >> tmp/${GROUP}-LEGACY-MENU.ipxe
    echo ":start" >> tmp/${GROUP}-LEGACY-MENU.ipxe
    echo "menu Bootermicro Content for ${GROUP}" >> tmp/${GROUP}-LEGACY-MENU.ipxe

    LABELNAME=${i/tmp\//}
    echo "item ${GROUP}-LEGACY         ${GROUP} Category Firmware Updates" >> tmp/BooterMicro-LEGACY-MENUS.ipxe
    echo ":${GROUP}-LEGACY" >> tmp/BooterMicro-LEGACY.ipxe
    echo "chain ${GROUP}-LEGACY.ipxe --replace --autofree || goto start" >> tmp/BooterMicro-LEGACY.ipxe 
    echo "" >> tmp/BooterMicro-LEGACY.ipxe
  fi

  ## Define individual firmwares per .zip file.  A few .zip's are mangled, ignoring since they appear to be mostly old.
  DIRECTORY="Firmware/${BOARD}/${BIOS}/${VER}/${FILE/.gz//*}"
  echo ":${FILE/.img.gz/}" >> tmp/${GROUP}-LEGACY.ipxe
  echo "item ${FILE/.img.gz/}		${BOARD}/${BIOS}/${VER}" >> tmp/${GROUP}-LEGACY-MENU.ipxe

  #for f in $DIRECTORY
  #do
  #  FILENAME=${f// /%20}
  #  echo "imgfetch /BooterMicro/${FILENAME/ipxe/} || goto failed" >> tmp/${GROUP}-LEGACY.ipxe
  #done
  echo "initrd /BooterMicro/Firmware/${BOARD}/${BIOS}/${VER}/${FILE}" >> tmp/${GROUP}-LEGACY.ipxe
  echo "chain /BooterMicro/memdisk raw || goto failed" >> tmp/${GROUP}-LEGACY.ipxe

  echo "goto start" >> tmp/${GROUP}-LEGACY.ipxe
  echo "" >> tmp/${GROUP}-LEGACY.ipxe
done


# Add the menu footer data to the menu portions of the file.
for i in tmp/*-LEGACY-MENU.ipxe; do
  echo "item" >> ${i}
  echo "item back --key 0x08	Return to previous menu..." >> ${i}
  echo "choose selected && goto \${selected} || goto start" >> ${i}
  echo ":back" >> ${i}
  echo "exit" >> ${i}
#  echo "chain BooterMicro-LEGACY.ipxe --replace --autofree || goto start" >> ${i}
done

# Drop final footer into Bootermicro-LEGACY.ipxe file (done separately, to make sure its done after all other entries inserted)
echo "item" >> tmp/BooterMicro-LEGACY-MENUS.ipxe
echo "item back --key 0x08	Return to previous menu..." >> tmp/BooterMicro-LEGACY-MENUS.ipxe
echo "choose selected && goto \${selected} || goto start" >> tmp/BooterMicro-LEGACY-MENUS.ipxe
echo ":back" >> tmp/BooterMicro-LEGACY-MENUS.ipxe
echo "exit" >> tmp/BooterMicro-LEGACY-MENUS.ipxe
echo "" >> tmp/BooterMicro-LEGACY-MENUS.ipxe
mv tmp/BooterMicro-LEGACY-MENUS.ipxe tmp/BooterMicro-LEGACY-MENU.ipxe 

# Merge the MENU and plain [label] files back together, so the menu block is at the top, and the labels are below.
for x in tmp/*-LEGACY-MENU.ipxe; do
 cat ${x/-MENU/} >> ${x}
 mv ${x} ${x/-MENU/}
done
echo "FINAL CLEANUP"

# worded as ../BooterMicro/ipxe to prevent potential accidental nuking of ipxe during dev.
#rm -rf ../BooterMicro/ipxe
#mkdir ../BooterMicro/ipxe
## Skipped on legacy script, it runs second, cant have it wiping out the files UEFI just put in there.

mv tmp/* ipxe

