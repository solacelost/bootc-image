ifndef __mk_ready
MAKEFLAGS += --check-symlink-times
MAKEFLAGS += --no-print-directory
.DEFAULT_GOAL := all

%:
	@$(MAKE) __mk_ready=1 $@

else

# Vars for building the bootc image
FEDORA_VERSION ?= 41
RUNTIME ?= podman
USERNAME ?= james
PASSWORD ?= password
PRIVATE_KEY ?= $$HOME/.ssh/id_ed25519
BASE ?= registry.fedoraproject.org/fedora:rawhide
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
BOOT_VERSION ?= $(FEDORA_VERSION)
BOOT_IMAGE_VERSION ?= 1.4
ISO_SUFFIX ?=
# ISO_DEST is the device to burn the iso to (such as a USB flash drive for live booting the installer on metal)
ISO_DEST ?= /dev/sda
# NETWORK defines the kickstart arguments for configuring the network, defaulting to DHCP on wired links
NETWORK := --bootproto=dhcp --device=link --activate
TZ := America/New_York
# Templating the kickstart variables is tricky
KICKSTART_VARS = IMAGE=$(IMAGE) \
	DEFAULT_DISK=$(DEFAULT_INSTALL_DISK) \
	ISO_SUFFIX=$(ISO_SUFFIX) \
	USERNAME=$(USERNAME) \
	SSH_KEY="$(shell cat overlays/users/usr/local/ssh/$(USERNAME).keys 2>/dev/null)" \
	PASSWORD="$(PASSWORD)" \
	NETWORK="$(NETWORK)" \
	TZ=$(TZ)

.PHONY: all
all: push

overlays/users/usr/local/ssh/$(USERNAME).keys:
	@echo Please put the authorized_keys file you would like for the $(USERNAME) user in $@ >&2
	@exit 1

tmp/$(LATEST_DIGEST):
	@touch $@

tmp/out.ociarchive: Containerfile.compose $(shell find compose -type f -o -type l) tmp/$(LATEST_DIGEST)
	rm -f tmp/out.ociarchive
	$(RUNTIME) build --security-opt=label=disable --arch $(ARCH) --pull=newer --cap-add=all --device=/dev/fuse --build-arg=FEDORA_VERSION=$(FEDORA_VERSION) --from $(BASE) -f $< . -t $(IMAGE)-composed
	$(RUNTIME) create --replace --name $(TAG)-composed $(IMAGE)-composed
	$(RUNTIME) cp $(TAG)-composed:/buildcontext/out.ociarchive ./tmp/
	$(RUNTIME) rm $(TAG)-composed

.build-$(TAG): Containerfile tmp/out.ociarchive overlays/users/usr/local/ssh/$(USERNAME).keys $(shell find overlays -type f -o -type l)
	$(RUNTIME) build . -t $(IMAGE)
	@touch $@

.PHONY: build
build: .build-$(TAG)

.push-$(TAG): .build-$(TAG)
	$(RUNTIME) push $(IMAGE)
	@touch $@

.PHONY: push
push: .push-$(TAG)

.PHONY: debug
debug:
	$(RUNTIME) run --rm -it --arch $(ARCH) --pull=never --entrypoint /bin/bash -v /var/tmp/buildah-cache-$$UID/8a2a6a29aeebc33c:/var/cache/libdnf5:z $(IMAGE) -li

boot-image/fedora-live.x86_64.iso:
	curl -Lo $@ https://download.fedoraproject.org/pub/fedora/linux/releases/${BOOT_VERSION}/Everything/x86_64/iso/Fedora-Everything-netinst-x86_64-${BOOT_VERSION}-${BOOT_IMAGE_VERSION}.iso

boot-image/bootc$(ISO_SUFFIX).ks: boot-image/bootc.ks.tpl
	$(KICKSTART_VARS) envsubst '$$IMAGE,$$USERNAME,$$SSH_KEY,$$DEFAULT_DISK,$$ISO_SUFFIX,$$PASSWORD,$$NETWORK,$$TZ' < $< >$@

boot-image/container$(ISO_SUFFIX)/index.json: .build-$(TAG)
	rm -rf boot-image/container$(ISO_SUFFIX)
	skopeo copy containers-storage:$(IMAGE) oci:boot-image/container$(ISO_SUFFIX)

boot-image/bootc-install$(ISO_SUFFIX).iso: boot-image/bootc$(ISO_SUFFIX).ks boot-image/fedora-live.x86_64.iso boot-image/container$(ISO_SUFFIX)/index.json
	@if [ -e $@ ]; then rm -f $@; fi
	sudo mkksiso --add boot-image/container$(ISO_SUFFIX) --ks $< boot-image/fedora-live.x86_64.iso $@

.PHONY: iso
iso: boot-image/bootc-install$(ISO_SUFFIX).iso

.PHONY: vm
vm: boot-image/bootc-install$(ISO_SUFFIX).iso
	@hack/create_vm.sh $(ISO_SUFFIX)

.PHONY: burn
burn: boot-image/bootc-install$(ISO_SUFFIX).iso
	sudo dd if=./$< of=$(ISO_DEST) bs=1M conv=fsync status=progress

.PHONY: clean
clean:
	rm -rf .build* .push* boot-image/*.iso boot-image/*.ks boot-image/container* tmp/*
	buildah rm --all
	podman image prune --all --force

endif # __mk_ready
