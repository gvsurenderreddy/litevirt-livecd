lang en_US.UTF-8
keyboard us
timezone US/Eastern
auth --useshadow --enablemd5
selinux --disabled
firewall --disabled
part / --size 1280 --fstype ext2
services --enabled="network,sshd"

repo --name=cos64 --baseurl=http://mirrors.163.com/centos/6.4/os/x86_64/
repo --name=cos64-update --baseurl=http://mirrors.163.com/centos/6.4/updates/x86_64/

bootloader --timeout=30 --location=mbr --append="rootflags=ro elevator=deadline rd_NO_LVM max_loop=256" 

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

%post --nochroot
echo "Add install helper script to livecd"
cp helpers/bos-install.py $INSTALL_ROOT/usr/sbin/bos-install
chmod +x $INSTALL_ROOT/usr/sbin/bos-install
%end

%post
echo "Strip out all unncesssary locales"
localedef --list-archive | grep -v -i -E 'en_US.utf8' |xargs localedef --delete-from-archive
mv /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl
/usr/sbin/build-locale-archive
%end

%packages
aic94xx-firmware
bfa-firmware
db4
device-mapper-multipath
dhclient
dmraid
e2fsprogs
iscsi-initiator-utils
file
hwdata
irqbalance
kernel
acpid
perf
lsof
lsscsi
numactl
openssh-server
openssh-clients
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
ethtool
syslinux
syslinux-extlinux
net-tools
rsyslog
parted
yum
eject

-audit-libs-python
-authconfig
-libselinux-python
-libuser
-mtools
-newt
-prelink
-setserial
-usermode
-ustr
-dracut
-wireless-tools

%end
