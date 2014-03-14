#!/bin/bash

#set -x

ROOT_UID=0 # Only users with $UID 0 have root privileges.
E_NOTROOT=87 # Non-root exit error.
E_RETRY=1 # Retry exit error

#INSTALLER_DIR=/media/gcca_storage
LIBVIRT_CONFIG_FILE=/etc/libvirt/libvirt.conf
LIBVIRTD_CONFIG_FILE=/etc/libvirt/libvirtd.conf
QEMU_CONFIG_FILE=/etc/libvirt/qemu.conf
NET_CONFIG_FILE=/etc/network/interfaces
RC_LOCAL_FILE=/etc/rc.local
BRIDGE_NAME=br0
INSTALL_USER=gcca
nic1=eth0

# disable GUI tool: network manager
disable_net_mgr() {
  stop network-manager
  echo "manual" | sudo tee /etc/init/network-manager.override
}

# config network
config_network() {
  local ok='n'
  while [ "$ok" != 'y' ] && [ "$ok" != 'Y' ]; do
    echo "Enter NIC1 info (for management and VM):"
    echo -n "name(e.g. eth1): "
    read nic1
    echo -n "IPv4 address(e.g. 172.16.99.40): "
    read ip1
    echo -n "netmask(e.g. 255.255.255.0): "
    read netmask1
    echo -n "gateway(e.g. 172.16.99.254): "
    read gateway1
    echo -n "DNS IPv4 address(e.g. 172.16.88.111): "
    read dns1

    echo ""
    echo "Enter NIC2 info (for connecting NAS):"
    echo -n "name(e.g. eth0): "
    read nic2
    echo -n "IPv4 address(e.g. 172.16.10.166): "
    read ip2
    echo -n "netmask(e.g. 255.255.255.0): "
    read netmask2

    echo -n "All you entered are CORRECT(y/n)? "
    read ok
  done

  echo "" >> $NET_CONFIG_FILE
  echo "auto $nic2" >> $NET_CONFIG_FILE
  echo "iface $nic2 inet static" >> $NET_CONFIG_FILE
  echo "address $ip2" >> $NET_CONFIG_FILE
  echo "netmask $netmask2" >> $NET_CONFIG_FILE

  echo "" >> $NET_CONFIG_FILE
  echo "auto $nic1" >> $NET_CONFIG_FILE
  echo "iface $nic1 inet static" >> $NET_CONFIG_FILE
  echo "address $ip1" >> $NET_CONFIG_FILE
  echo "netmask $netmask1" >> $NET_CONFIG_FILE
  echo "gateway $gateway1" >> $NET_CONFIG_FILE
  echo "dns-nameservers $dns1" >> $NET_CONFIG_FILE

  /etc/init.d/networking restart
}

# Install synaptic package manager and Confirm all packages are installed in Synaptic package manager
install_synaptic() {
  apt-get install synaptic
  synaptic
  local ok='n'
  while [ "$ok" != 'y' ] && [ "$ok" != 'Y' ]; do
    echo -n "Did you install all packages in Synaptic package manager(y/n)? "
    read ok
  done
}

# config openssh-server
config_ssh() {            
  echo "UseDNS no" >> /etc/ssh/sshd_config
  /etc/init.d/ssh restart
}

# config kvm
config_kvm() {
  echo -n "Enter Admin user name(e.g. gcca): "
  read INSTALL_USER
  echo ""
  
  usermod -a -G kvm $INSTALL_USER

  echo "" >> $LIBVIRTD_CONFIG_FILE
  echo "###################################################################" >> $LIBVIRTD_CONFIG_FILE
  echo "listen_tls = 0" >> $LIBVIRTD_CONFIG_FILE
  echo "listen_tcp = 1" >> $LIBVIRTD_CONFIG_FILE
  echo tcp_port = \"16509\" >> $LIBVIRTD_CONFIG_FILE
  echo unix_sock_group = \"libvirtd\" >> $LIBVIRTD_CONFIG_FILE
  echo unix_sock_rw_perms = \"0770\" >> $LIBVIRTD_CONFIG_FILE
  echo auth_unix_ro = \"none\" >> $LIBVIRTD_CONFIG_FILE
  echo auth_unix_rw = \"none\" >> $LIBVIRTD_CONFIG_FILE
  echo auth_tcp= \"none\" >> $LIBVIRTD_CONFIG_FILE
  echo "log_level = 3" >> $LIBVIRTD_CONFIG_FILE
  echo log_outputs=\"3:syslog:libvirtd\" >> $LIBVIRTD_CONFIG_FILE
  echo "max_requests = 100" >> $LIBVIRTD_CONFIG_FILE
  echo "max_client_requests = 40" >> $LIBVIRTD_CONFIG_FILE
  echo "min_workers = 20" >> $LIBVIRTD_CONFIG_FILE
  echo "max_workers = 40" >> $LIBVIRTD_CONFIG_FILE
  echo "max_clients = 40" >> $LIBVIRTD_CONFIG_FILE

  echo "" >> $LIBVIRT_CONFIG_FILE
  echo "###################################################################" >> $LIBVIRT_CONFIG_FILE
  echo "listen_tls = 0" >> $LIBVIRT_CONFIG_FILE
  echo "listen_tcp = 1" >> $LIBVIRT_CONFIG_FILE
  echo tcp_port = \"16509\" >> $LIBVIRT_CONFIG_FILE
  echo unix_sock_group = \"libvirtd\" >> $LIBVIRT_CONFIG_FILE
  echo unix_sock_rw_perms = \"0770\" >> $LIBVIRT_CONFIG_FILE
  echo auth_unix_ro = \"none\" >> $LIBVIRT_CONFIG_FILE
  echo auth_unix_rw = \"none\" >> $LIBVIRT_CONFIG_FILE
  echo auth_tcp= \"none\" >> $LIBVIRT_CONFIG_FILE
  echo "log_level = 3" >> $LIBVIRT_CONFIG_FILE
  echo log_outputs=\"3:syslog:libvirtd\" >> $LIBVIRT_CONFIG_FILE
  echo "max_requests = 100" >> $LIBVIRT_CONFIG_FILE
  echo "max_client_requests = 40" >> $LIBVIRT_CONFIG_FILE
  echo "min_workers = 20" >> $LIBVIRT_CONFIG_FILE
  echo "max_workers = 40" >> $LIBVIRT_CONFIG_FILE
  echo "max_clients = 40" >> $LIBVIRT_CONFIG_FILE

  cp $PWD/qemu.conf $QEMU_CONFIG_FILE
  
  /etc/init.d/libvirt-bin stop
  libvirtd -d -l
}

# config processes which will auto starts when system boots
config_boot_proc() {
  cp $PWD/rc.local $RC_LOCAL_FILE
}

# config NAS
config_nas() {
  local mediaDir="/media/gcca_storage"
  mkdir $mediaDir

  echo -n "Enter VM image location in NAS(e.g. 172.16.10.235:/gDesCloud): "
  read nasDir
  echo "$nasDir $mediaDir nfs hard,intr,rsize=8192,wsize=8192,vers=3   0   0" >> /etc/fstab
  mount -a
}

# config bridge
config_bridge() {
  ifdown $nic1

  sed -i 's/'"$nic1"'/'"$BRIDGE_NAME"'/g' $NET_CONFIG_FILE
  sed -i '$a bridge_ports '"$nic1"'' $NET_CONFIG_FILE
  sed -i '$a bridge_stp off' $NET_CONFIG_FILE
  sed -i '$a bridge_maxwait 0' $NET_CONFIG_FILE
  /etc/init.d/networking restart
}

# TODO: config firewall
#config_firewall() {
#}

config_XTerm() {
  cp $PWD/.Xdefaults /home/$INSTALL_USER/.Xdefaults
}

confirm_reboot() {
  local ok='n'
  echo -n "Reboot now to complete installation (y/n)? "
  read ok
  if [ "$ok" == 'y' ] && [ "$ok" == 'Y' ]
  then
    reboot
  else
	echo "Please reboot later to complete installation."
  fi
}

main() {
  # Run as root, of course.
  if [ "$UID" -ne "$ROOT_UID" ]
  then
    echo "Must be root to run this script."
  exit $E_NOTROOT
  fi 

  disable_net_mgr
  config_network
  install_synaptic  
  config_ssh
  config_kvm
  config_boot_proc
  config_nas
  config_bridge
  config_XTerm
  confirm_reboot
}

main

# A zero return value from the script upon exit indicates success
#+ to the shell.
exit 0