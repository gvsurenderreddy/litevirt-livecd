%packages --excludedocs --nobase
audit
PyPAM
libvirt-python
python-gudev
python-gudev
hdparm
syslinux
syslinux-extlinux
acpid
net-snmp
openssh-server
%end

%post
echo "Enable snmp service"
ln -s '/usr/lib/systemd/system/snmpd.service' '/etc/systemd/system/multi-user.target.wants/snmpd.service'

echo "Configure snmp service"
cat > /etc/snmp/snmpd.conf << \EOF_snmpd
master agentx
dontLogTCPWrappersConnects yes
rwuser root auth .1
EOF_snmpd

echo "Enable sshd service"
ln -s '/usr/lib/systemd/system/sshd.service' '/etc/systemd/system/multi-user.target.wants/sshd.service'

echo "Configure sshd service"
mkdir -p /root/.ssh
chmod 700 /root/.ssh
%end
