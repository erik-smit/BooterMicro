#!/usr/bin/perl -w
use English; 		# things like MATCH
use Getopt::Long;
use File::Basename;	# basename, dirname
use Fcntl;		# O_RDWR

# A Perl script to SYS the boot sector of a disk image or
# a device for FreeDOS. Do not forget to copy kernel.sys
# and command.com to the root directory of the target!
# For the latter, you can use mtools, or just mount the
# target. If needed, use loopback mounting. Sample line
# for ~/.mtoolsrc: drive m: file="/tmp/test.img"

# Perl by Eric Auer, 16aug2004. The boot sectors are by
# the FreeDOS project and licensed under the GNU GPL.
# This Perl script itself is free Public Domain software.

# Added 6/2007: hidden sectors / heads / sec_per_track
# override possible with command line options.

# TODO: allow some user-specified seek to skip over any
# headers / partition table, e.g for DOSEMU disk images.

my ($disk, $lba, $help);	# options: target, lba flag, help flag
my ($heads, $sects, $posn);	# options: heads geo, sect geo, posn geo
my ($drive);			# option: BIOS drive number
my ($fsboot, $bootcode);	# strings used as arrays
my ($nasmopt, $bootsource);	# strings
my ($i, $fat);			# numbers

my $bootdir = " " . dirname($0) . "/bootsecs/";	# boot sector source dir

my $result = GetOptions("disk=s"=>\$disk, "lba!"=>\$lba, "help!"=>\$help,
  "heads=i"=>\$heads, "sectors=i"=>\$sects, "offset=i"=>\$posn,
  "drive=i"=>\$drive);
# "o"=>\$oflag, "verbose"=>\$verbosebool, "string=s"=>\$stringmandatory
# "string:s"=>stringoptional ... similar for i integer and f float.
# @ARGV contains the unprocessed rest if $ARGV[0] after this.

if (($help) || (!defined $disk)) {
    print "FreeDOS boot sector SYS for Linux v1.1, public domain by Eric Auer 2004-2008.\n";
    print "  Puts a FreeDOS boot sector on a FAT (12/16/32) filesystem.\n";
    print "  Note: FreeDOS boot sectors, kernel.sys and command.com license is GPL.\n";
    print "  You still have to copy the kernel.sys and command.com files yourself!\n";
    print "\nUsage:\n";
    print basename($0) . " --disk=file [--lba] [--heads=n] [--sectors=n] [--offset=n] [--drive=n]\n";
    print "\nOptions:\n";
    print "  --disk=file_or_device  target filesystem, for example /dev/sdx1\n";
    print "  --lba                  selects boot sectors with LBA BIOS support\n";
    print "  --heads=head_count     overrides CHS setting 'heads' (cyls need no setting)\n";
    print "  --sectors=sector_count overrides CHS setting 'sectors per...'\n";
    print "  --offset=sector_count  overrides partition location on disk setting\n";
    print "  --drive=drive_number   overrides BIOS drive (255=auto, 0=A:, 128=harddisk)\n";
    print "\nHints:\n";
    print "If you formatted the drive with DOS or Windows, you need no overrides.\n";
    print "  If CHS *x?x? shows 0 for one of the ?, override it. Use offset 0 for\n";
    print "  diskettes, non-0 for partitions. Use overrides after using mkdosfs.\n";
    print "Check the output of fdisk -l -u /dev/??? to select overrides. Example:\n";
    print "  fdisk -l -u /dev/hdb shows '... 255 HEADS, 63 SECTORS/track ...'\n";
    print "  Use OFFSET 63 for hdb1: '/dev/hdb1 * 63 1028159 514048+ 6 FAT16'\n";
    exit(1);
}

sysopen(IMAGE, $disk, O_RDWR)
    || die "cannot open filesystem $disk for read/write access";
binmode(IMAGE);		# not normally needed
if (sysread(IMAGE, $fsboot, 512) != 512) {
    die "cannot read boot sector from filesystem $disk";
}
sysseek(IMAGE, 0, 0) || die "cannot rewind to filesystem start";

# substr syntax: substr(input, offset, length)
if (substr($fsboot, 510, 2) ne "\x55\xaa") {
    die "boot sector magic value missing in filesystem";
}

if (substr($fsboot, 0x0b, 2) ne "\x00\x02") {
    die "not 512 bytes per sector\n";
}

if (substr($fsboot, 0x11, 2) eq "\x00\x00") {
	# other possible detection: 16 bit FAT1x size at 0x16 is zero
	$fat = 32;	# FAT32: zero FAT1x root directory entries
	if (($lba) && (substr($fsboot, 0x1c) eq "\x00\x00\x00\x00")) {
	    print STDERR "FAT32 LBA warning: Hidden sector count is zero!\n";
	}
} else {
	$fat = 16;
	# if 16 bit FAT1x size at 0x16 is at least 16, we have FAT16
	# actually it would be more correct to use the sector count
	# (possibly the 32 bit one), subtract reserved (boot) sector
	# count and fat count * fat size, and divide by sec per clust
	# and finally check if the result is at least 4096.

	# unpack: v is "unsigned, little endian, 16bit", V is same for 32bit
        my $fatsize = unpack('v', substr($fsboot, 0x16, 2));
	# print STDERR "FAT1x size: $fatsize\n";
	# letters: c/C signed/unsigned 8 bit, s/S 16, l/L 32...
	# network / big endian: n/N (16/32), VAX / little endian: v/V.
	if ($fatsize < 16) { $fat = 12; }	# FAT very small: FAT12
}

$bootsource = $bootdir . "boot.asm";	# source for FAT12 and FAT16
if ($fat == 12) { $nasmopt = "-dISFAT12"; }	# can do both CHS and LBA
if ($fat == 16) { $nasmopt = "-dISFAT16"; }	# can do both CHS and LBA
if ($fat == 32) {
    $nasmopt = "";				# no options for FAT32
    $bootsource = $bootdir . "boot32.asm";	# CHS version
    if ($lba) { $bootsource =~ s/32/32lb/; }	# LBA version
}

print STDERR "DOS boot sector for $disk will be created by:\n";
print STDERR "\tnasm -o /dev/stdout $nasmopt $bootsource\n";
open(BOOTSECT, "nasm -o /dev/stdout $nasmopt $bootsource |")
    || die "cannot fork";
binmode(BOOTSECT);	# not normally needed
if (sysread(BOOTSECT, $bootcode, 512) != 512) {
    die "boot sector compilation problem";
}
close(BOOTSECT) || die "boot sector $bootsource nasm error $?";

if (substr($bootcode, 510, 2) ne "\x55\xaa") {
    die "magic value missing in compiled boot sector";
}

substr($bootcode, 3, 8) = "LINUX4.1";		# place OEM ID, the
						# "4.1" is to please M$
if ($fat != 32) {
    $i = 0x3e-11;				# size of classic BPB
} else {
    $i = 0x5a-11;				# size of FAT32 xBPB
}
substr($bootcode, 3+8, $i) = substr($fsboot, 3+8, $i);	# copy BPB
# bpb: after jump and OEM ID ... initial jump target: typically $i+11

print STDERR "Using FAT$fat" . (($lba) ? " LBA." : ".")
    . " Partn offset " . unpack('V', substr($fsboot, 11+17, 4)) . ","
    . sprintf(" CHS *x%dx%d ", unpack('v', substr($fsboot, 11+15, 2)),
        unpack('v', substr($fsboot, 11+13, 2)))
    # unpack: c is signed byte char, C is unsigned
    . sprintf(" Drive %x,", unpack('C', substr($fsboot, 11+$i-26, 1)))
    . sprintf(" (0x%x, ", unpack('C', substr($fsboot, 11+$i-25, 1)))
    . sprintf("0x%x),\n", unpack('C', substr($fsboot, 11+$i-24, 1)))
    . sprintf("SerNo %X-%X, ",
	unpack('v', substr($fsboot, 11+$i-21, 2)),
	unpack('v', substr($fsboot, 11+$i-23, 2)))
    . "Strings '" . substr($fsboot, 11+$i-19, 11) . "', " # override in rootdir
    . " '" . substr($fsboot,11+$i-8,8) . "'.\n";

if (defined $drive && $drive>-1) { # at 11+$i-26 = 24/40 drive (255=auto)
    substr($bootcode, 11+$i-26, 1) = pack('C', $drive);
    print STDERR "Drive changed to $drive\n";
}

if (defined $posn && $posn>-1) { # at 11+17 = 1c partition offset
    substr($bootcode, 11+17, 4) = pack('V', $posn);
    print STDERR "Partition offset changed to $posn\n";
}
if (defined $sects && $sects>0) { # at 11+13 = 18 sectors per track/cylinder
    substr($bootcode, 11+13, 2) = pack('v', $sects); # should be 1..63
    print STDERR "CHS sector count changed to $sects\n";
}
if (defined $heads && $heads>0) { # at 11+15 = 1a heads
    substr($bootcode, 11+15, 2) = pack('v', $heads); # should be 1..255 (256?)
    print STDERR "CHS head count changed to $heads\n";
}

syswrite(IMAGE, $bootcode, 512) || die "could not write updated boot sector";
close(IMAGE);

print STDERR "Boot sector successfully updated.\n";
exit(0);
