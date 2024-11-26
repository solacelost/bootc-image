# Vars for building the bootc image
RUNTIME ?= podman
USERNAME ?= james
PASSWORD ?= password
PRIVATE_KEY ?= $$HOME/.ssh/id_ed25519
BASE ?= registry.fedoraproject.org/fedora:41
REGISTRY ?= registry.jharmison.com
REPOSITORY ?= library/fedora-bootc
REG_REPO := $(REGISTRY)/$(REPOSITORY)
TAG ?= desktop
IMAGE = $(REG_REPO):$(TAG)
# Help find out if our base image has updated
ARCH := amd64
LATEST_DIGEST := $(shell hack/latest_base.sh $(BASE) $(ARCH))

# Vars only for building the kickstart-based installer
DEFAULT_INSTALL_DISK ?= vda
BOOT_VERSION ?= 41
BOOT_IMAGE_VERSION ?= 1.4
ISO_SUFFIX ?=
# ISO_DEST is the device to burn the iso to (such as a USB flash drive for live booting the installer on metal)
ISO_DEST ?= /dev/sda
# Templating the kickstart variables is tricky
KICKSTART_VARS = IMAGE=$(IMAGE) \
	DEFAULT_DISK=$(DEFAULT_INSTALL_DISK) \
	USERNAME=$(USERNAME) \
	SSH_KEY="$(shell cat overlays/users/usr/local/ssh/$(USERNAME).keys 2>/dev/null)" \
	PASSWORD=$(PASSWORD)

.PHONY: all
all: push

overlays/users/usr/local/ssh/$(USERNAME).keys:
	@echo Please put the authorized_keys file you would like for the $(USERNAME) user in $@ >&2
	@exit 1

tmp/$(LATEST_DIGEST):
	@touch $@

.build: Containerfile overlays/users/usr/local/ssh/$(USERNAME).keys $(shell find overlays -type f) $(shell find compose -type f) tmp/$(LATEST_DIGEST)
	$(RUNTIME) build --security-opt=label=disable --arch $(ARCH) --pull=newer --cap-add=all --device=/dev/fuse --from $(BASE) . -t $(IMAGE)
	@touch $@

.PHONY: build
build: .build

.push: .build
	$(RUNTIME) push --compression-format=zstd:chunked $(IMAGE)
	@touch $@

.PHONY: push
push: .push

.PHONY: debug
debug:
	$(RUNTIME) run --rm -it --arch $(ARCH) --pull=never --entrypoint /bin/bash $(IMAGE) -li

boot-image/fedora-live.x86_64.iso:
	curl -Lo $@ https://download.fedoraproject.org/pub/fedora/linux/releases/${BOOT_VERSION}/Everything/x86_64/iso/Fedora-Everything-netinst-x86_64-${BOOT_VERSION}-${BOOT_IMAGE_VERSION}.iso

boot-image/bootc$(ISO_SUFFIX).ks: boot-image/bootc.ks.tpl
	$(KICKSTART_VARS) envsubst '$$IMAGE,$$USERNAME,$$SSH_KEY,$$DEFAULT_DISK,$$PASSWORD' < $< >$@

boot-image/bootc-install$(ISO_SUFFIX).iso: boot-image/bootc$(ISO_SUFFIX).ks boot-image/fedora-live.x86_64.iso
	@if [ -e $@ ]; then rm -f $@; fi
	sudo mkksiso --ks $< boot-image/fedora-live.x86_64.iso $@

.PHONY: iso
iso: boot-image/bootc-install$(ISO_SUFFIX).iso

.PHONY: vm
vm: boot-image/bootc-install$(ISO_SUFFIX).iso
	@hack/create_vm.sh

.PHONY: burn
burn: boot-image/bootc-install$(ISO_SUFFIX).iso
	sudo dd if=./$< of=$(ISO_DEST) bs=1M conv=fsync status=progress

.PHONY: clean
clean:
	rm -rf .build* .push* boot-image/*.iso boot-image/*.ks
	buildah prune -f
