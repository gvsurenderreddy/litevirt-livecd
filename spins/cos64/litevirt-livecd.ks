%include litevirt-networking.ks

firewall --disabled

repo --name=cos64 --baseurl=http://mirrors.163.com/centos/6.4/os/x86_64/
repo --name=cos64-update --baseurl=http://mirrors.163.com/centos/6.4/updates/x86_64/

device virtio_blk
device virtio_pci
device mptspi
device scsi_wait_scan
device dm-multipath
device dm-round-robin
device dm-emc
device dm-rdac
device dm-hp-sw
device scsi_dh_rdac
device 3w-9xxx
device 3w-sas
device 3w-xxxx
device a100u2w
device aacraid
device aic79xx
device aic94xx
device arcmsr
device atp870u
device be2iscsi
device bfa
device BusLogic
device cciss
device cxgb3i
device dc395x
device fnic
device gdth
device hpsa
device hptiop
device imm
device initio
device ips
device libosd
device libsas
device libsrp
device lpfc
device megaraid
device megaraid_mbox
device megaraid_mm
device megaraid_sas
device mpt2sas
device mvsas
device osd
device osst
device pm8001
device pmcraid
device qla1280
device qla2xxx
device qla4xxx
device qlogicfas408
device stex
device tmscsim
device ums-sddr09
device ums-realtek
device ums-sddr55
device ums-isd200
device ums-alauda
device ums-freecom
device ums-cypress
device ums-jumpshot
device ums-onetouch
device ums-karma
device ums-usbat
device ums-datafab
device ums-eneub6250
# System authorization information
auth --useshadow --enablemd5
# System keyboard
keyboard us
# System language
lang en_US.UTF-8
# SELinux configuration
selinux --disabled
# Installation logging level
logging --level=info

# System services
services --enabled="rsyslog,multipathd,sshd"

# System timezone
timezone --isUtc UTC
# System bootloader configuration
bootloader --append="rootflags=ro elevator=deadline rd_NO_LVM max_loop=256" --location=mbr --timeout=30
# Disk partitioning information
part / --fstype="ext2" --size=1024

%post
echo "Starting Kickstart Post"
PATH=/sbin:/usr/sbin:/bin:/usr/bin
export PATH

echo "Refine crond service"
rm -f /etc/cron.daily/logrotate

echo "Strip out all unncesssary locales"
localedef --list-archive | grep -v -i -E 'en_US.utf8' |xargs localedef --delete-from-archive
mv /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl
/usr/sbin/build-locale-archive


echo "Creating shadow files"
# because we aren't installing authconfig, we aren't setting up shadow
# and gshadow properly.  Do it by hand here
pwconv
grpconv


echo "Initalizeing password for root account"
passwd -d root


echo "Disable selinux"
[ -f /etc/selinux/config ] && sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

# remove the /etc/krb5.conf file; it will be fetched on bootup
rm -f /etc/krb5.conf

# root's bash profile
cat >> /root/.bashrc << \EOF_bashrc
# aliases used for the temporary
function mod_vi() {
  /bin/vi $@
  restorecon -v $@ >/dev/null 2>&1
}
alias ping='ping -c 3'
alias yum="mod_yum"
export MALLOC_CHECK_=1
export LVM_SUPPRESS_FD_WARNINGS=0
EOF_bashrc

# fix iSCSI/LVM startup issue
sed -i 's/node\.session\.initial_login_retry_max.*/node.session.initial_login_retry_max = 60/' /etc/iscsi/iscsid.conf

echo "Configure sshd service"
mkdir -p /root/.ssh
chmod 700 /root/.ssh

%end

%post --nochroot
PRODUCT='Litevirt Hypervisor'
PRODUCT_SHORT='Litevirt Hypervisor'
VERSION=1.0.0
RELEASE=10000

# overwrite user visible banners with the image versioning info
echo "Fix release info"
cat > $INSTALL_ROOT/etc/litevirt-hypervisor-release <<EOF
$PRODUCT release $VERSION ($RELEASE)
EOF
rm -rf $INSTALL_ROOT/etc/fedora-release
ln -snf litevirt-hypervisor-release $INSTALL_ROOT/etc/redhat-release
ln -snf litevirt-hypervisor-release $INSTALL_ROOT/etc/system-release
cp $INSTALL_ROOT/etc/litevirt-hypervisor-release $INSTALL_ROOT/etc/issue
echo "Kernel \r on an \m (\l)" >> $INSTALL_ROOT/etc/issue
cp $INSTALL_ROOT/etc/issue $INSTALL_ROOT/etc/issue.net

# store image version info in the ISO and rootfs
cat > $LIVE_ROOT/isolinux/version <<EOF
PRODUCT='$PRODUCT'
PRODUCT_SHORT='${PRODUCT_SHORT}'
VERSION=$VERSION
RELEASE=$RELEASE
EOF
cp $LIVE_ROOT/isolinux/version $INSTALL_ROOT/etc/default/

echo "Fix boot menu"
# remove quiet from Node bootparams, added by livecd-creator
sed -i -e 's/ quiet//' $LIVE_ROOT/isolinux/isolinux.cfg

# Rename Boot option to Install or Upgrade
sed -i 's/^  menu label Boot$/  menu label Litevirt Hypervisor/' $LIVE_ROOT/isolinux/isolinux.cfg

# Remove Verify and Boot option
sed -i -e '/label check0/{N;N;N;d;}' $LIVE_ROOT/isolinux/isolinux.cfg

# add serial console boot entry
menu=$(mktemp)
awk '
/^label linux0/ { linux0=1 }
linux0==1 && $1=="append" {
  append0=$0
}
linux0==1 && $1=="label" && $2!="linux0" {
  linux0=2
  print "label serial-console"
  print "  menu label Litevirt Hypervisor with serial console"
  print "  kernel vmlinuz0"
  print append0" console=ttyS0,115200n8 "
}
{ print }
' $LIVE_ROOT/isolinux/isolinux.cfg > $menu
# change the title
sed -i -e '/^menu title/d' $menu
echo "say This is the $PRODUCT $VERSION ($RELEASE)" > $LIVE_ROOT/isolinux/isolinux.cfg
echo "menu title ${PRODUCT_SHORT} $VERSION ($RELEASE)" >> $LIVE_ROOT/isolinux/isolinux.cfg
cat $menu >> $LIVE_ROOT/isolinux/isolinux.cfg
rm $menu

%end

%post --interpreter=image-minimizer --nochroot
droprpm system-config-*
keeprpm system-config-keyboard-base
droprpm libsemanage-python


droprpm mkinitrd
droprpm isomd5sum
droprpm checkpolicy
droprpm make
droprpm setools-libs-python
droprpm setools-libs
droprpm gamin
droprpm pm-utils
droprpm usermode
droprpm vbetool
droprpm ConsoleKit
droprpm hdparm
droprpm linux-atm-libs
droprpm mtools
droprpm wireless-tools
droprpm radeontool
droprpm libicu
droprpm gnupg2
droprpm fedora-release-notes
droprpm fedora-logos

# rhbz#641494 - drop unnecessary rpms pulled in from libguestfs-winsupport
droprpm fakechroot
droprpm fakechroot-libs
droprpm fakeroot
droprpm fakeroot-libs
droprpm febootstrap

# cronie pulls in exim (sendmail) which pulls in all kinds of perl deps
droprpm exim
droprpm perl*
# keep libperl for snmpd
keeprpm perl-libs
droprpm postfix
droprpm mysql*

droprpm sysklogd

# pam complains when this is missing
keeprpm ConsoleKit-libs

# kernel modules minimization

# filesystems
drop /lib/modules/*/kernel/fs
keep /lib/modules/*/kernel/fs/ext*
keep /lib/modules/*/kernel/fs/mbcache*
keep /lib/modules/*/kernel/fs/squashfs
keep /lib/modules/*/kernel/fs/jbd*
keep /lib/modules/*/kernel/fs/cifs*
keep /lib/modules/*/kernel/fs/fat
keep /lib/modules/*/kernel/fs/nfs
keep /lib/modules/*/kernel/fs/nfs_common
keep /lib/modules/*/kernel/fs/fscache
keep /lib/modules/*/kernel/fs/lockd
keep /lib/modules/*/kernel/fs/nls/nls_utf8.ko
keep /lib/modules/*/kernel/fs/configfs/configfs.ko
# autofs4     configfs  exportfs *fat     *jbd    mbcache.ko  nls       xfs
#*btrfs       cramfs   *ext2     *fscache *jbd2  *nfs         squashfs
# cachefiles  dlm      *ext3      fuse     jffs2 *nfs_common  ubifs
# cifs        ecryptfs *ext4      gfs2    *lockd  nfsd        udf

# network
drop /lib/modules/*/kernel/net
keep /lib/modules/*/kernel/net/802*
keep /lib/modules/*/kernel/net/bridge
keep /lib/modules/*/kernel/net/core
keep /lib/modules/*/kernel/net/ipv*
keep /lib/modules/*/kernel/net/key
keep /lib/modules/*/kernel/net/llc
keep /lib/modules/*/kernel/net/netfilter
keep /lib/modules/*/kernel/net/rds
keep /lib/modules/*/kernel/net/sctp
keep /lib/modules/*/kernel/net/sunrpc
#*802    atm        can   ieee802154 *key      *netfilter  rfkill *sunrpc  xfrm
#*8021q  bluetooth *core *ipv4       *llc       phonet     sched   wimax
# 9p    *bridge     dccp *ipv6        mac80211 *rds       *sctp    wireless

drop /lib/modules/*/kernel/sound

# drivers
drop /lib/modules/*/kernel/drivers
keep /lib/modules/*/kernel/drivers/ata
keep /lib/modules/*/kernel/drivers/block
keep /lib/modules/*/kernel/drivers/cdrom
keep /lib/modules/*/kernel/drivers/char
keep /lib/modules/*/kernel/drivers/cpufreq
keep /lib/modules/*/kernel/drivers/dca
keep /lib/modules/*/kernel/drivers/ptp
keep /lib/modules/*/kernel/drivers/dma
keep /lib/modules/*/kernel/drivers/edac
keep /lib/modules/*/kernel/drivers/firmware
keep /lib/modules/*/kernel/drivers/idle
keep /lib/modules/*/kernel/drivers/infiniband
keep /lib/modules/*/kernel/drivers/input/misc/uinput.ko
keep /lib/modules/*/kernel/drivers/md
keep /lib/modules/*/kernel/drivers/message
keep /lib/modules/*/kernel/drivers/net
keep /lib/modules/*/kernel/net/openvswitch
drop /lib/modules/*/kernel/drivers/net/pcmcia
drop /lib/modules/*/kernel/drivers/net/wireless
drop /lib/modules/*/kernel/drivers/net/ppp*
keep /lib/modules/*/kernel/drivers/pci
keep /lib/modules/*/kernel/drivers/scsi
keep /lib/modules/*/kernel/drivers/staging/ramzswap
keep /lib/modules/*/kernel/drivers/uio
keep /lib/modules/*/kernel/drivers/usb
drop /lib/modules/*/kernel/drivers/usb/atm
drop /lib/modules/*/kernel/drivers/usb/class
drop /lib/modules/*/kernel/drivers/usb/image
drop /lib/modules/*/kernel/drivers/usb/misc
drop /lib/modules/*/kernel/drivers/usb/serial
keep /lib/modules/*/kernel/drivers/usb/storage
keep /lib/modules/*/kernel/drivers/vhost
keep /lib/modules/*/kernel/drivers/virtio
keep /lib/modules/*/kernel/drivers/watchdog
keep /lib/modules/*/kernel/drivers/pps
drop /lib/modules/*/kernel/drivers/xen

# acpi       *cpufreq   hid         leds      mtd      ?regulator  uwb
#*ata         crypto   ?hwmon      *md       *net*      rtc       *vhost
# atm        *dca      ?i2c         media    ?parport  *scsi*      video
# auxdisplay *dma      *idle        memstick *pci      ?serial    *virtio
#*block      *edac      ieee802154 *message   pcmcia   ?ssb        watchdog
# bluetooth   firewire *infiniband ?mfd       platform *staging    xen
#*cdrom      *firmware  input       misc     ?power    ?uio
#*char*      ?gpu       isdn        mmc      ?pps      *usb

drop /usr/share/zoneinfo
keep /usr/share/zoneinfo/UTC

drop /etc/alsa
drop /usr/share/alsa
drop /usr/share/awk
drop /usr/share/vim
drop /usr/share/anaconda
drop /usr/share/backgrounds
drop /usr/share/wallpapers
drop /usr/share/kde-settings
drop /usr/share/gnome-background-properties
drop /usr/share/dracut
drop /usr/share/setuptool
drop /usr/share/hwdata/MonitorsDB
drop /usr/share/hwdata/oui.txt
drop /usr/share/hwdata/videoaliases
drop /usr/share/hwdata/videodrivers
drop /usr/share/firstboot
drop /usr/share/lua
drop /usr/share/kde4
drop /usr/share/pixmaps
drop /usr/share/icons
drop /usr/share/fedora-release
drop /usr/share/tabset
drop /usr/share/augeas/lenses/tests
drop /usr/share/augeas/lenses/dist/*
# generic includes
keep /usr/share/augeas/lenses/dist/build.aug
keep /usr/share/augeas/lenses/dist/hosts.aug
keep /usr/share/augeas/lenses/dist/inifile.aug
keep /usr/share/augeas/lenses/dist/modprobe.aug
keep /usr/share/augeas/lenses/dist/rx.aug
keep /usr/share/augeas/lenses/dist/sep.aug
keep /usr/share/augeas/lenses/dist/shellvars.aug
keep /usr/share/augeas/lenses/dist/spacevars.aug
keep /usr/share/augeas/lenses/dist/sysctl.aug
keep /usr/share/augeas/lenses/dist/util.aug
# whitelist only relevant lenses
keep /usr/share/augeas/lenses/dist/buildd.aug
keep /usr/share/augeas/lenses/dist/cgconfig.aug
keep /usr/share/augeas/lenses/dist/cgrules.aug
keep /usr/share/augeas/lenses/dist/cron.aug
keep /usr/share/augeas/lenses/dist/dhclient.aug
keep /usr/share/augeas/lenses/dist/dnsmasq.aug
keep /usr/share/augeas/lenses/dist/ethers.aug
keep /usr/share/augeas/lenses/dist/exports.aug
keep /usr/share/augeas/lenses/dist/fstab.aug
keep /usr/share/augeas/lenses/dist/group.aug
keep /usr/share/augeas/lenses/dist/grub.aug
keep /usr/share/augeas/lenses/dist/inittab.aug
keep /usr/share/augeas/lenses/dist/iptables.aug
keep /usr/share/augeas/lenses/dist/json.aug
keep /usr/share/augeas/lenses/dist/krb5.aug
keep /usr/share/augeas/lenses/dist/limits.aug
keep /usr/share/augeas/lenses/dist/logrotate.aug
keep /usr/share/augeas/lenses/dist/lokkit.aug
keep /usr/share/augeas/lenses/dist/modules_conf.aug
keep /usr/share/augeas/lenses/dist/multipath.aug
keep /usr/share/augeas/lenses/dist/ntp.aug
keep /usr/share/augeas/lenses/dist/pam.aug
keep /usr/share/augeas/lenses/dist/passwd.aug
keep /usr/share/augeas/lenses/dist/resolv.aug
keep /usr/share/augeas/lenses/dist/securetty.aug
keep /usr/share/augeas/lenses/dist/services.aug
keep /usr/share/augeas/lenses/dist/shellvars_list.aug
keep /usr/share/augeas/lenses/dist/sshd.aug
keep /usr/share/augeas/lenses/dist/sudoers.aug
keep /usr/share/augeas/lenses/dist/utill.aug
keep /usr/share/augeas/lenses/dist/yum.aug
drop /usr/share/tc
drop /usr/share/emacs
drop /usr/share/info
drop /usr/src
drop /usr/etc
drop /usr/games
drop /usr/include
keep /usr/include/python2.*
drop /usr/local
drop /usr/sbin/dell*
keep /usr/sbin/build-locale-archive
drop /usr/sbin/glibc_post_upgrade.*
drop /usr/lib*/tc
drop /usr/lib*/tls
drop /usr/lib*/sse2
drop /usr/lib*/pkgconfig
drop /usr/lib*/nss
drop /usr/lib*/games
drop /usr/lib*/alsa-lib
drop /usr/lib*/krb5
drop /usr/lib*/hal
drop /usr/lib*/gio
# glibc-common locales
drop /usr/lib/locale
keep /usr/lib/locale/locale-archive
keep /usr/lib/locale/usr/share/locale/en_US
# pango
drop /usr/lib*/pango
drop /usr/lib*/libpango*
drop /usr/lib*/libthai*
drop /usr/share/libthai
drop /etc/pango
drop /usr/bin/pango*
# hal
drop /usr/bin/hal-disable-polling
drop /usr/bin/hal-is-caller-locked-out
drop /usr/bin/hal-is-caller-privileged
drop /usr/bin/hal-lock
drop /usr/bin/hal-set-property
drop /usr/bin/hal-setup-keymap
# openssh
drop /usr/bin/sftp
drop /usr/bin/slogin
drop /usr/bin/ssh-add
drop /usr/bin/ssh-agent
drop /usr/bin/ssh-keyscan
# docs
drop /usr/share/omf
drop /usr/share/gnome
drop /usr/share/doc
keep /usr/share/doc/*-firmware-*
drop /usr/share/locale/
keep /usr/share/locale/en_US
drop /usr/share/man
drop /usr/share/X11
drop /usr/share/i18n
drop /boot/*
keep /boot/efi
drop /var/lib/builder
drop /usr/sbin/rhn_register
drop /usr/sbin/*-channel

drop /usr/share/selinux

drop /usr/lib*/libboost*
keep /usr/lib*/libboost_program_options.so*
keep /usr/lib*/libboost_filesystem.so*
keep /usr/lib*/libboost_thread-mt.so*
keep /usr/lib*/libboost_system.so*
drop /usr/kerberos
keep /usr/kerberos/bin/kinit
keep /usr/kerberos/bin/klist
drop /lib/firmware
keep /lib/firmware/3com
keep /lib/firmware/acenic
keep /lib/firmware/adaptec
keep /lib/firmware/advansys
keep /lib/firmware/bnx2
keep /lib/firmware/bnx2x
keep /lib/firmware/bnx2x*
keep /lib/firmware/cxgb3
keep /lib/firmware/cxgb4
keep /lib/firmware/e100
keep /lib/firmware/myricom
keep /lib/firmware/ql*
keep /lib/firmware/sun
keep /lib/firmware/tehuti
keep /lib/firmware/tigon
keep /lib/firmware/cbfw_fc.bin
keep /lib/firmware/ctfw_cna.bin
keep /lib/firmware/ctfw_fc.bin
keep /lib/firmware/aic94xx-seq.fw

drop /lib/kbd/consolefonts
drop /etc/pki/tls
keep /etc/pki/tls/openssl.cnf
drop /etc/pki/java
drop /etc/pki/nssdb

# minimize net-snmp
drop /etc/rc.d/init.d/snmptrapd
drop /etc/snmp/snmptrapd.conf
drop /etc/sysconfig/snmptrapd
drop /usr/sbin/snmptrapd
drop /usr/bin/net-snmp-create-v3-user
drop /usr/bin/snmpconf
drop /usr/share/snmp/snmpconf-data

#desktop files
drop /etc/xdg/autostart/restorecond.desktop

#ebtables depends on perl
drop /sbin/ebtables-save
drop /sbin/ebtables-restore

# remove bogus kdump script (rpmdiff complains)
drop /etc/kdump-adv-conf

#cim
droprpm tog-pegasus
droprpm tog-pegasus-libs
droprpm mailcap
droprpm openslp

#remove rpms added by dmraid
droprpm ConsoleKit
droprpm checkpolicy
droprpm dmraid-events
droprpm gnupg2
droprpm hdparm
droprpm isomd5sum
droprpm libicu
droprpm libsemanage-python
droprpm linux-atm-libs
droprpm make
droprpm mtools
droprpm mysql-libs
droprpm perl
droprpm perl-Module-Pluggable
droprpm perl-Net-Telnet
droprpm perl-PathTools
droprpm perl-Pod-Escapes
droprpm perl-Pod-Simple
droprpm perl-Scalar-List-Utils
droprpm perl-hivex
droprpm perl-macros
droprpm setools-libs
droprpm setools-libs-python
droprpm sgpio
droprpm glusterfs-client
droprpm system-config-firewall-base
droprpm usermode

#NFS 
drop /usr/bin/rpcgen
drop /usr/sbin/rpc.gssd
drop /usr/sbin/rpc.nfsd
drop /usr/sbin/rpc.svcgssd
drop /usr/sbin/rpcdebug

#runtime packages required by livecd-creator;
#they can be safely removed in the postscript
droprpm firewalld
droprpm appliance-tools-minimizer

# COS6 only
droprpm cvs
droprpm gettext
droprpm hesiod
droprpm procmail
droprpm sendmail
drop /etc/rc.d/init.d/libvirt-guests
%end

%post
echo "Removing python source files"
find /usr -name '*.py' -exec rm -f {} \;
find /usr -name '*.pyo' -exec rm -f {} \;
%end

%post --nochroot
# only works on x86, x86_64
if [ "$(uname -i)" = "i386" -o "$(uname -i)" = "x86_64" ]; then
    if [ ! -d $LIVE_ROOT/LiveOS ]; then mkdir -p $LIVE_ROOT/LiveOS ; fi
    cp /usr/bin/livecd-iso-to-disk $LIVE_ROOT/LiveOS
    cp /usr/bin/livecd-iso-to-pxeboot $LIVE_ROOT/LiveOS
fi
%end


%packages --excludedocs --nobase
aic94xx-firmware
bfa-firmware
db4
device-mapper-multipath
dhclient
dmraid
e2fsprogs
appliance-tools-minimizer
system-config-keyboard-base
iscsi-initiator-utils
file
hwdata
irqbalance
kernel
perf
lsof
lsscsi
numactl
openssh-clients
openssh-server
passwd
pciutils
psmisc
python
python-libs
ql2100-firmware
ql2200-firmware
ql23xx-firmware
ql2400-firmware
ql2500-firmware
rootfiles
strace
sudo
sysfsutils
sysstat
tcpdump
usbutils
vim-minimal
bash
# plymouth stuff
plymouth
plymouth-system-theme
plymouth-plugin-label
plymouth-graphics-libs
plymouth-scripts
plymouth-plugin-two-step

augeas
net-tools
rsyslog
yum

-audit-libs-python
-authconfig
-fedora-logos
-fedora-release
-fedora-release-notes
-libselinux-python
-libuser
-mtools
-newt
-prelink
-setserial
-tar
-cpio
-parted
-kpartx
-usermode
-ustr
-which
-dracut
-wireless-tools
%end
