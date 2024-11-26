#!/bin/bash

cd "$(dirname "$(realpath "$0")")/.."

name="bootc-desktop"
iso_suffix="${1}"
disk_size="${2:-120}"
vcpus="${3:-4}"
memory_size="${4:-32768}"

pin_mac=",mac=52:54:00:d3:5b:81"

set -ex

sudo cp -uf boot-image/bootc-install"${iso_suffix}".iso /var/lib/libvirt/images/

second_disk="$name-1.qcow2"
second_disk_source="$name-1.bak.qcow2"

# If our source exists, wipe out the old disk and reclone it
if virsh vol-list default | grep -qF "$second_disk_source"; then
	virsh vol-delete "$second_disk" --pool default || :
	virsh vol-clone "$second_disk_source" "$second_disk" --pool default
# If our source doesn't exist, and the volume destination doesn't exist, create it as empty
elif ! virsh vol-list default | grep -qF "$second_disk"; then
	virsh vol-create-as --pool default --name "$second_disk" --capacity 10G
fi

virt-install --connect qemu:///system \
	--virt-type=kvm --cpu=host-passthrough \
	--video model=virtio --channel spicevmc \
	--name "${name}" --memory "${memory_size}" \
	--vcpus "${vcpus}" --osinfo fedora40 --sound default \
	--disk "size=${disk_size},bus=scsi,cache=writethrough,io=threads" \
	--disk "bus=scsi,cache=writethrough,io=threads,vol=default/${second_disk}" \
	--controller type=scsi,model=virtio-scsi \
	--channel unix,target_type=virtio,name=org.qemu.guest_agent.0 \
	--cdrom /var/lib/libvirt/images/bootc-install"${iso_suffix}".iso \
	--network "bridge=br0${pin_mac},model=virtio" \
	--boot loader=/usr/share/OVMF/OVMF_CODE.fd,loader.readonly=yes,loader.type=pflash

virsh destroy "$name" || :
sync
virsh undefine --nvram "$name" || :
sync
virsh vol-delete "$name.qcow2" --pool default || :
sync
