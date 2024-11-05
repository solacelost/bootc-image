# Basic setup
text
network --bootproto=dhcp --device=link --activate
# Basic partitioning
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
part / --grow --fstype xfs

ostreecontainer --url ${IMAGE}

services --enabled=sshd

# Inject an SSH key for root
rootpw --iscrypted locked
sshkey --username root "${SSH_KEY}"

# Configure our user
user --name=${USERNAME} --groups=wheel --password="${PASSWORD}" --plaintext

%post

# Ensure users and their homes are created
for passwd in /usr/lib/passwd /etc/passwd; do
    while IFS=: read -r user x uid gid gecos home shell; do
        if (( uid >= 1000 )) && [[ $user != nfsnobody ]]; then
            mkdir -p "$home"
            chown -R "$uid":"$gid" "$home"
        fi
    done <$passwd
done

# Ensure users own any staged SSH keys
for key in /usr/local/ssh/*.keys; do
  user=$(basename --suffix=.keys $key)
  if id -u $user && id -g $user; then
      chown $(id -u $user):$(id -g $user) $key
  fi
done

%end

reboot
