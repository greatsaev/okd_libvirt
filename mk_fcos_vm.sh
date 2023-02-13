#!/bin/bash

VM_NAME=$1
IP=$2

WEB_SERVER='IP' # server with ign and pxe files

NET_KRLN="ip=${IP}::10.100.168.1:255.255.252.0:${VM_NAME}:ens3:none:10.100.2.33" # For deployment without DHCP

FCOS_VER="35.20220327.3.0"
IMAGE="/var/lib/libvirt/images/fedora-coreos-${FCOS_VER}-live.x86_64.iso"
ROOTFS="http://${WEB_SERVER}:8080/fedora-coreos-${FCOS_VER}-live-rootfs.x86_64.img"
IGN="http://${WEB_SERVER}:8080/${VM_NAME}.ign"

VCPUS="4"
RAM_MB="16384"
DISK_GB="100" 
VG="vgSSD1"  

BRIDGE="168"

lvcreate --yes -n "${VM_NAME}" -L"${DISK_GB}"G "${VG}"

virt-install --connect="qemu:///system" --name="${VM_NAME}" --vcpus="${VCPUS}" --memory="${RAM_MB}" \
        --os-variant="fedora6" \
        --import \
        --graphics vnc,listen=127.0.0.1,keymap=en-us \    
        --disk "path=/dev/${VG}/${VM_NAME},format=raw,bus=virtio,cache=none" \
        --location "${IMAGE}",initrd=images/pxeboot/initrd.img,kernel=images/pxeboot/vmlinuz \
        --network "network=ovs-network,virtualport_type=openvswitch,portgroup=LAN${BRIDGE},model=virtio" \
        --description "${VM_NAME} - TEST - Gritsaev - Task: 75853" \
        --extra-args="coreos.live.rootfs_url=${ROOTFS} coreos.inst.install_dev=/dev/vda coreos.inst.platform_id=qemu coreos.inst.ignition_url=${IGN} ${NET_KRLN}"