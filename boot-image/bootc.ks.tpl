# Disk configurations
%pre --log=/tmp/ks-pre.log
#!/bin/bash

set -x

# Read the disks available
readarray -t disks < <(realpath $(find /dev/disk/by-path -type l | grep -v 'usb' | grep -v 'part') | grep -v '/dev/sr' | cut -d/ -f3 | sort -u)
declare -a otherdisks
declare -A otherdiskparts

install_disk=""

if (( ${#disks[@]} == 1 )); then # we only have one disk available
    install_disk="${disks[0]}"
else
    for disk in "${disks[@]}"; do
        if [ "$disk" = "${DEFAULT_DISK}" ]; then # our default disk is in the list of disks
            install_disk="$disk"
        else
            otherdisks+=("$disk")
        fi
    done
fi
if [ -z "$install_disk" ]; then # we didn't find a suitable installation disk
    exit 1
fi

# identify partitions on other disks, if viable mounts
for disk in "${otherdisks[@]}"; do
    for dev in $(lsblk /dev/$disk -oNAME -nr); do
        if [ "$dev" = "$disk" ]; then
            continue
        fi
        otherdiskparts[$disk]+="${otherdiskparts[$disk]} $dev"
    done
done

cat << EOF > /tmp/part-include
# Clear installation disk
clearpart --initlabel --disklabel gpt --drives ${install_disk}

# Configure /boot and /boot/efi
part /boot --size 1024 --fstype xfs --ondisk ${install_disk} --label boot
part /boot/efi --size 256 --fstype efi --ondisk ${install_disk}

# Fixed 40Gi partition for installation root
part / --size 40960 --fstype xfs --ondisk ${install_disk} --label root

# Configure LVM for /var to fill remaining space
part pv.01 --size 1 --grow --ondisk ${install_disk}
volgroup fedora pv.01
logvol /var --percent 100 --grow --fstype xfs --vgname fedora --name var

# Bootloader configuration
bootloader --driveorder ${install_disk}

# disks without configuration: ${otherdisks[@]}
$(for disk in ${otherdisks[@]}; do
    for part in ${otherdiskparts[$disk]}; do
        echo "# $part"
    done
done)
EOF

cat /tmp/part-include

%end

# Basic setup
text
network --bootproto=dhcp --device=link --activate

%include /tmp/part-include

ostreecontainer --url ${IMAGE}

services --enabled=sshd

# Inject an SSH key for root
rootpw --iscrypted locked
sshkey --username root "${SSH_KEY}"

# Configure our user
user --name=${USERNAME} --groups=wheel --password="${PASSWORD}" --plaintext

%post --log=/var/roothome/ks-post.log
#!/bin/bash

set -x

# Save the pre logs
cat << 'EOF' >> /var/roothome/ks-pre.log
%include /tmp/ks-pre.log
EOF

# Ensure users and their homes are created
for passwd in /usr/lib/passwd /etc/passwd; do
    while IFS=: read -r user x uid gid gecos home shell; do
        if (( uid >= 1000 )) && [[ $user != nfsnobody ]]; then
            mkdir -p "$home"
            chown -R "$uid":"$gid" "$home"
        fi
    done <$passwd
done

%end

reboot
