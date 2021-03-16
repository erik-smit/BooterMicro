#!/bin/bash 
set -x
set -e

rm -rf tmp
mkdir tmp

# Add menu header to start of BooterMicro's actual ipxe menu file.
echo '#!ipxe' > tmp/BooterMicro-MENUS.ipxe
echo ':start' >> tmp/BooterMicro-MENUS.ipxe
echo 'menu Bootermicro Firmware Updater/Installer - **UEFI Mode**' >> tmp/BooterMicro-MENUS.ipxe

# Dig through the ./Firmware directory to figure out what Boards/Revisions/BIOS/etc. exist and add entries for 'em
find ./Firmware -type f -name *.zip | sort | while IFS=/ read FOO Firmware BOARD BIOS VER FILE; do 
  if echo $BOARD | grep -q ^X10; then
    GROUPLENGTH=4
  elif echo $BOARD | grep -q ^X; then
    GROUPLENGTH=3
  else
    GROUPLENGTH=2
  fi

  GROUP="`echo $BOARD | cut -c1-$GROUPLENGTH`"

  # If a groups .ipxe files don't already exist, make the header info for the menu's, add 'em to the bootermicro menu, etc. upon first discovery.
  if [ ! -e tmp/${GROUP}-MENU.ipxe ]; then 
    echo "#!ipxe" >> tmp/${GROUP}-MENU.ipxe
    echo ":start" >> tmp/${GROUP}-MENU.ipxe
    echo "menu Bootermicro Content for ${GROUP}" >> tmp/${GROUP}-MENU.ipxe

    LABELNAME=${i/tmp\//}
    echo "item ${GROUP}         ${GROUP} Category Firmware Updates" >> tmp/BooterMicro-MENUS.ipxe
    echo ":${GROUP}" >> tmp/BooterMicro.ipxe
    echo "chain ${GROUP}.ipxe --replace --autofree || goto start" >> tmp/BooterMicro.ipxe 
    echo "" >> tmp/BooterMicro.ipxe
  fi

  ## Define individual firmwares per .zip file.  A few .zip's are mangled, ignoring since they appear to be mostly old.
  DIRECTORY="Firmware/${BOARD}/${BIOS}/${VER}/${FILE/.zip//*}"
  echo ":${FILE/.zip/}" >> tmp/${GROUP}.ipxe
  echo "item ${FILE/.zip/}		${BOARD}/${BIOS}/${VER}" >> tmp/${GROUP}-MENU.ipxe
  for f in $DIRECTORY
  do
    FILENAME=${f// /%20}
    echo "imgfetch /BooterMicro/${FILENAME/ipxe/} || goto failed" >> tmp/${GROUP}.ipxe
  done
  echo "imgfetch /BooterMicro/startup.nsh || goto failed" >> tmp/${GROUP}.ipxe
  echo "chain /BooterMicro/ramdisk-shell.efi || goto failed" >> tmp/${GROUP}.ipxe
  echo "goto start" >> tmp/${GROUP}.ipxe
  echo "" >> tmp/${GROUP}.ipxe
done


# Add the menu footer data to the menu portions of the file.
for i in tmp/*-MENU.ipxe; do
  echo "item" >> ${i}
  echo "item back --key 0x08	Return to previous menu..." >> ${i}
  echo "choose selected && goto \${selected} || goto start" >> ${i}
  echo ":back" >> ${i}
  echo "exit" >> ${i}
#  echo "chain BooterMicro.ipxe --replace --autofree || goto start" >> ${i}
done

# Drop final footer into Bootermicro.ipxe file (done separately, to make sure its done after all other entries inserted)
echo "item" >> tmp/BooterMicro-MENUS.ipxe
echo "item back --key 0x08	Return to previous menu..." >> tmp/BooterMicro-MENUS.ipxe
echo "choose selected && goto \${selected} || goto start" >> tmp/BooterMicro-MENUS.ipxe
echo ":back" >> tmp/BooterMicro-MENUS.ipxe
echo "exit" >> tmp/BooterMicro-MENUS.ipxe
echo "" >> tmp/BooterMicro-MENUS.ipxe
mv tmp/BooterMicro-MENUS.ipxe tmp/BooterMicro-MENU.ipxe 

# Merge the MENU and plain [label] files back together, so the menu block is at the top, and the labels are below.
for x in tmp/*-MENU.ipxe; do
 cat ${x/-MENU/} >> ${x}
 mv ${x} ${x/-MENU/}
done

# worded as ../BooterMicro/ipxe to prevent potential accidental nuking of ipxe during dev.
rm -rf ../BooterMicro/ipxe
mkdir ../BooterMicro/ipxe
mv tmp/* ipxe

