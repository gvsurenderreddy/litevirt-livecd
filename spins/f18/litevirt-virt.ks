%post
echo "Enable libvirt service."
ln -s '/usr/lib/systemd/system/libvirtd.service' '/etc/systemd/system/multi-user.target.wants/libvirtd.service'
%end

%packages --excludedocs --nobase
libiscsi
qemu-kvm
libvirt-daemon-driver-secret
libvirt-client
libvirt-daemon-driver-qemu
libvirt-python
libvirt-daemon-driver-nwfilter
libvirt-daemon
libvirt-daemon-driver-interface
libvirt-daemon-driver-network
libvirt-daemon-driver-nodedev
libvirt-daemon-driver-storage

%end
