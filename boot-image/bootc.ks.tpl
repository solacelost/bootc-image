# Disk configurations
%pre --log=/tmp/ks_pre.log
set -x
cat << 'EOF' > /tmp/part-include
# Basic partitioning
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
part / --grow --fstype xfs
EOF

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

%post --log=/var/roothome/ks_post.log
set -x
cat << 'EOF' >> /var/roothome/ks_pre.log
%include /tmp/ks_pre.log
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
