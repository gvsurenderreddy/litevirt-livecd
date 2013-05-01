%packages --excludedocs --nobase
ethtool
%end

%post
echo "Enable network service."
/sbin/chkconfig network on

echo "Initializing eth0."
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
ONBOOT=yes
DEVICE=eth0
BOOTPROTO=dhcp
EOF

%end
