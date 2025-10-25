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

if [ "${LUKS_PASSWORD}" ]; then
    luks_options=(--encrypted --passphrase="${LUKS_PASSWORD}")
fi

cat << EOF > /tmp/part-include
# Clear installation disk
clearpart --initlabel --all --disklabel gpt --drives ${install_disk}

# Configure /boot and /boot/efi
part /boot --size 1024 --fstype xfs --ondisk ${install_disk} --label boot
part /boot/efi --size 256 --fstype efi --ondisk ${install_disk}

# Fixed 40Gi partition for installation root
part / --size 40960 --fstype xfs --ondisk ${install_disk} --label root

# Configure LVM for /var to fill remaining space
part pv.01 --size 1 --grow --ondisk ${install_disk}
volgroup fedora pv.01
logvol /var --percent 100 --grow --fstype xfs --vgname fedora --name var ${luks_options[@]}

# Bootloader configuration
bootloader --driveorder ${install_disk}
EOF

cat /tmp/part-include

touch /tmp/fstab-include
# Map other partitions to fstab entries for %post
for disk in ${otherdisks[@]}; do
    for part in ${otherdiskparts[$disk]}; do
        fstype=$(lsblk /dev/$part -oFSTYPE -nr 2>/dev/null ||:)
        if [ -n "$fstype" ] && ! (echo "$fstype" | grep -qF LVM); then
            echo "/dev/$part /mnt/$part $fstype defaults,noatime,nofail 0 0" >> /tmp/fstab-include
        fi
    done
done

cat /tmp/fstab-include

%end

# Basic setup
text
network ${NETWORK}

%include /tmp/part-include

lang en_US.UTF-8
keyboard us
timezone ${TZ}

# Install from our injected image
ostreecontainer --url=/run/install/repo/container${ISO_SUFFIX} --transport=oci --no-signature-verification

services --enabled=sshd

# Inject an SSH key for root
rootpw --lock
sshkey --username root "${SSH_KEY}"

# Configure our user
user --name=${USERNAME} --homedir /var/home/${USERNAME} --groups=wheel --password="${PASSWORD}" --plaintext

%post --log=/var/roothome/ks-post.log
#!/bin/bash

set -x

# Ensure we're following our actual bootc remote
bootc switch --mutate-in-place --transport registry ${IMAGE}

# Save the pre logs
cat << 'EOF' >> /var/roothome/ks-pre.log
%include /tmp/ks-pre.log
EOF

# Read fstab adjustments
cat << 'EOF' >> /etc/fstab
%include /tmp/fstab-include
EOF

# Ensure users and their homes are created
{ set +x ; } 2>/dev/null
function noisy {
    set -x
    "${@}"
    { set +x; } 2>/dev/null
}

for passwd in /usr/lib/passwd /etc/passwd; do
    while IFS=: read -r user x uid gid gecos home shell; do
        if (( uid >= 1000 )) && [[ $user != nfsnobody ]]; then
            noisy mkdir -p "$home"
            noisy chown -R "$uid":"$gid" "$home"
        fi
    done <$passwd
done

# Ensure groups are set for our GUI user properly
for group in dialout:x:18 video:x:39 audio:x:63 realtime:x:71 input:x:104 render:x:105 gamemode:x:971 libvirt:x:977; do
    if grep -qF "$group" /etc/group; then
        existing_users=($(grep -F "$group" /etc/group | cut -d: -f4 | tr ',' ' '))
        new_users=("${existing_users[@]}")
        if [[ ! " ${existing_users[*]} " =~ [[:space:]]${USERNAME}[[:space:]] ]]; then
            new_users+=("${USERNAME}")
        fi
        users="$(printf '%s,' "${new_users[@]}" | head -c-1)"
        noisy sed -i "s/^$group.*\$/$group:$users/" /etc/group
    else
        noisy echo "$group:${USERNAME}" >> /etc/group
    fi
done
cat /etc/group

%end

reboot
