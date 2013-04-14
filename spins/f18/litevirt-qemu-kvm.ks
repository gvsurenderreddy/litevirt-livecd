repo --name="qemu-kvm" --baseurl=file:///root/litevirt-repo/RPMS

%packages --excludedocs --nobase
libvirt
libiscsi
qemu-kvm
%end
