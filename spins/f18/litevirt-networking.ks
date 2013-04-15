%packages --excludedocs --nobase
ethtool
openvswitch
%end

%post
echo "Enable openvswitch service."
ln -s '/usr/lib/systemd/system/openvswitch.service' '/etc/systemd/system/multi-user.target.wants/openvswitch.service'

echo "Enable network service."
/sbin/chkconfig network on

echo "Initializing eth0."
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
ONBOOT=yes
DEVICE=eth0
BOOTPROTO=dhcp
EOF
%end
