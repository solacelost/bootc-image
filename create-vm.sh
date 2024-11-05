#!/bin/bash

cd "$(dirname "$(realpath "$0")")"

name="bootc-desktop"
iso_suffix="${1}"
disk_size="${2:-120}"
vcpus="${3:-4}"
memory_size="${4:-32768}"

pin_mac=",mac=52:54:00:d3:5b:81"

set -ex

sudo cp -uf boot-image/bootc-install"${iso_suffix}".iso /var/lib/libvirt/images/

virt-install --connect qemu:///system \
	--name "${name}" --memory "${memory_size}" \
	--vcpus "${vcpus}" --disk size="${disk_size}" --osinfo fedora40 \
	--cdrom /var/lib/libvirt/images/bootc-install"${iso_suffix}".iso \
	--network "bridge=br0${pin_mac}"

virsh destroy "$name" || :
sync
virsh undefine "$name" || :
sync
virsh vol-delete "$name.qcow2" --pool default || :
sync
