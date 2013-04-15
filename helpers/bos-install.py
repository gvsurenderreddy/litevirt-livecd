#!/usr/bin/python

import argparse
import os
import sys
import subprocess

def runcmd(cmd):
    proc = subprocess.Popen(cmd,
                     shell=True,
                     stdout=subprocess.PIPE,
                     stderr=subprocess.STDOUT)
    stdout = proc.stdout.read()
    retval = proc.wait()
    return (retval, stdout)


class BosInstaller(object):
    def __init__(self, args):
        self.drive = args.drive
        self.quiet = args.quiet
        self.rootidx = 1
        self.rootdev = "%s%d" % (self.drive, self.rootidx)
        self.mntdir = "/var/tmp/bos_install_staging"
        self.bootdir = "%s/boot" % self.mntdir
        if not os.path.exists(self.bootdir):
            os.makedirs(self.bootdir)

    def validate_drive(self):
        basename = os.path.basename(self.drive)
        if not os.path.exists("/sys/block/%s" % basename):
            print("%s is not a valid disk." % self.drive)
            sys.exit(-1)

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
                (rc, out) = runcmd(cmd)             
                if rc != 0:
                    print("Failed to wipe off existing partitions on %s" % self.drive)
                    sys.exit(-1)

        self.reread_partitions()
        return

    def reread_partitions(self):
        runcmd('sync')
        runcmd('partprobe %s' % self.drive)

    def prepare_partitions(self):
        runcmd('parted -s %s mklabel msdos' % self.drive)
        runcmd('parted -s %s mkpart primary ext2 1M 8192M' % self.drive)
        runcmd('parted -s %s set %d boot' % (self.drive, self.rootidx))
        self.reread_partitions()

    def copy_root_image(self):
        losetup_cmd = "losetup -a |grep ext3fs.img"
        (rc, losetup_lookup) = runcmd(losetup_cmd)
        if rc != 0:
            print("Cannot find loop device ext3fs.img")
            sys.exit(-1)

        loopdev = losetup_lookup.strip().split(":")[0]

        print "Copying root image from %s to %s" % (loopdev, self.rootdev)
        (rc, out) = runcmd('cat %s > %s' % (loopdev, self.rootdev))
        if rc != 0:
            print("Failed to copy image to %s: %s" % (self.rootdev, out))
            sys.exit(-1)

    def install_bootloader(self):
        reqs = (
                "/usr/sbin/extlinux",
                "/usr/share/syslinux/mbr.bin"
               )

        for req in reqs:
            if not os.path.exists(req):
                print("%s is missing. Abort!")
                sys.exit(-1)

        extlinux_conf = "%s/extlinux.conf" % self.bootdir

        runcmd('cat /usr/share/syslinux/mbr.bin > %s' % self.drive)
        blkid_cmd = "blkid -o value -s UUID %s" % self.rootdev
        (rc, uuid_lookup) = runcmd(blkid_cmd)
        uuid = uuid_lookup.strip()
        print "Setting boot to %s, UUID=%s" % (self.rootdev, uuid)
        
        syscmds = (
                    "mount %s %s" % (self.rootdev, self.mntdir),
                    "extlinux -i %s" % self.bootdir,
                    "extlinux --clear-once %s" % self.bootdir,
                    "cp -rf /run/initramfs/live/isolinux/* %s" % self.bootdir,
                    "mv %s/isolinux.cfg %s" % (self.bootdir, extlinux_conf),
                    "sed -i 's/live:CDLABEL=bos/UUID=%s/' %s" % (uuid, extlinux_conf),
                    "sed -i 's/ ro / /' %s" % extlinux_conf,
                    "sed -i 's/ rd.live.image / /' %s" % extlinux_conf,
                    "umount %s" % self.rootdev
                  )

        for cmd in syscmds:
            runcmd(cmd)

    def go(self):
        self.validate_drive()
        if not self.quiet:
            self.confirm_install()
        self.clear_partitions()
        self.prepare_partitions()
        self.copy_root_image()
        self.install_bootloader()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
                description='BOS Install Helper')
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

    installer = BosInstaller(args)
    installer.go()
    print "Bos installed successfully! Please reboot your host immediately."
    sys.exit(0)

