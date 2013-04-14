#!/usr/bin/python

import argparse
import os
import sys
from LitevirtConfig.litevirtfunctions import *

def fatal(errmsg, errcode=-1):
        print errormsg
        sys.exit(errcode)

class LitevirtInstaller(object):
    def __init__(self, args):
        self.drive = args.drive
        self.quiet = args.quiet
        self.rootdev_idx = 1
        self.rootdev = "%s%d" % (self.drive, self.rootdev_idx)
        self.mntdir = "/tmp/install_stage"
        if not os.path.exists(self.mntdir):
            os.makedirs(self.mntdir)
        self.release_file = "/etc/litevirt-hypervisor-release"
        self.bootdir = "%s/boot" % self.mntdir

    def validate_drive(self):
        basename = os.path.basename(self.drive)
        if not os.path.exists("/sys/block/%s" % basename):
            fatal("%s is not a valid disk, which must be a local disk." % self.drive)
        return

    def validate_litevirt_hypervisor(self):
        if not os.path.exists(self.release_file):
            fatal("This is not a litevirt hypervisor system. Exiting.")
        return

    def confirm_install(self):
        answner = raw_input("WARNING: ALL data on %s will be erased. Continue? (y/N): " % self.drive)
        if answner.lower() != 'y':
            sys.exit(0)
        return

    def clear_partitions(self):
        with open('/proc/partitions') as part_lines:
            for line in part_lines:
                line.replace('\n', '')
                drv = os.path.basename(self.drive)

                import re
                m = re.match(r"\s+\d+\s+\d+\s+\d+\s+%s(\d+)" % drv, line)
                if not m:
                    continue
                index = m.groups()[0]
                cmd = "parted -s %s rm %s" % (self.drive, index)                
                if system_closefds(cmd) != 0:
                    fatal("Failed to wipe off existing partitions on %s" % self.drive)
        self.reread_partitions()
        return

    def reread_partitions(self):
        system_closefds('sync')
        system_closefds('partprobe %s' % self.drive)

    def prepare_partitions(self):
        system_closefds('parted -s %s mklabel msdos' % self.drive)
        system_closefds('parted -s %s mkpart primary ext2 1M 1280M' % self.drive)
        system_closefds('parted -s %s set %d boot' % (self.drive, self.rootdev_idx))
        self.reread_partitions()

    def copy_root_image(self):
        losetup_cmd = "losetup -a |grep ext3fs.img"
        losetup_lookup = subprocess_closefds(losetup_cmd, shell=True, stdout=PIPE, stderr=STDOUT)
        loopdev = losetup_lookup.stdout.read().strip().split(":")[0]
        print "Copying litevirt hypervisor root image to %s" % self.rootdev
        ret = system_closefds('cat %s > %s' % (loopdev, self.rootdev))
        if ret != 0:
            sys.exit(-1)

    def install_bootloader(self):
        reqs = ("/usr/sbin/extlinux",
                "/usr/share/syslinux/mbr.bin")

        for req in reqs:
            if not os.path.exists(req):
                faltal("%s is missing. Abort!")

        system_closefds('cat /usr/share/syslinux/mbr.bin > %s' % self.drive)
        blkid_cmd = "blkid -o value -s UUID %s" % self.rootdev
        uuid_lookup = subprocess_closefds(blkid_cmd, shell=True, stdout=PIPE, stderr=STDOUT)
        uuid = uuid_lookup.stdout.read().strip()
        extlinux_conf = "%s/extlinux.conf" % self.bootdir

        system_closefds('mount %s %s' % (self.rootdev, self.mntdir))
        system_closefds('extlinux -i %s' % self.bootdir)
        # this is required for supporting hardware raid
        system_closefds('extlinux --clear-once %s' % self.bootdir)
        system_closefds('cp -rf /run/initramfs/live/isolinux/* %s' % self.bootdir)
        system_closefds('mv %s/isolinux.cfg %s' % (self.bootdir, extlinux_conf))

        sed_cmds = ("sed -i 's/live:CDLABEL=Litevirt-LiveCD/UUID=%s/' %s" % (uuid, extlinux_conf),
                    "sed -i 's/ rootflags=ro / /' %s" % extlinux_conf,
                    "sed -i 's/ ro / /' %s" % extlinux_conf,
                    "sed -i 's/ liveimg / /' %s" % extlinux_conf,
                    )
        for cmd in sed_cmds:
            system_closefds(cmd)
        system_closefds('umount %s' % self.rootdev)

    def go(self):
        self.validate_litevirt_hypervisor()
        self.validate_drive()
        if not self.quiet:
            self.confirm_install()
        self.clear_partitions()
        self.prepare_partitions()
        self.copy_root_image()
        self.install_bootloader()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
                description='Litevirt Hypervisor Install Helper')
    parser.add_argument(
            '--drive',
            dest='drive',
            action='store',
            required=True,
            help='target drive to install litevirt(must be a local disk)')

    parser.add_argument(
            '--quiet',
            dest='quiet',
            action='store_true',
            help='Quiet mode')
    args = parser.parse_args()

    installer = LitevirtInstaller(args)
    installer.go()
    print "Litevirt Hypervisor installed successfully! Please reboot your host immediately."
    sys.exit(0)

