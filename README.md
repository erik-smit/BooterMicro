# BooterMicro

## Description

BooterMicro is a tool I threw together to ease the pain of updating the BIOS/UEFI firmware of my Supermicro servers
.

It wil download all Supermicro BIOS/UEFI/IPMI firmwares, generate bootable FreeDOS images for each of them and create a spiffy syslinux menu.

It works as follows:

1. fetchbios.pl retrieves http://www.supermicro.nl/support/bios;
2. parses the latest BIOS/UEFI/IPMI firmware for all boards;
3. If a firmware does not yet exist locally, it will;
4. download the firmware into 'Firmware';
5. If the firmware is BIOS/UEFI, run mkbiosimg.sh on the downloaded zip,
   generating an image containing the contents of mkbiosimg/fdboot.img and said zip
6. Once done iterating, it will execute mkpxecfg.sh, which goes through Firmware and produce a syslinux menu at ../pxelinux.cfg/BooterMicro.cfg and ../pxelinux.cfg/BooterMicro

## Screenshots

![Screenshot 1](/img/bootermicro1.png)
![Screenshot 2](/img/bootermicro2.png)
![Screenshot 3](/img/bootermicro3.png)
![Screenshot 4](/img/bootermicro4.png)

## Requirements

### Perl Modules

- HTML::TableExtract
- WWW::Mechanize
- HTML::Strip
- Date::Format

### Utilities

- mtools
- 7-zip
- pigz

## Usage

```
cd /srv/tftp
git clone https://github.com/zylon-internet/BooterMicro.git
echo "INCLUDE BooterMicro.cfg" >> ./pxelinux.cfg/default
cd BooterMicro
./fetchbios.pl
```

## License

BooterMicro is licensed under the MIT License
mkbiosimg/fdboot.zip and mkbiosimg/bootsecs come from FreeDOS and are licensed under the GPL
mkbiosimg/sys-freedos.pl is licensed under the Public Domain
 
## Thanks

- @terrorobe for coming up with this spiffy name so quickly. :)
