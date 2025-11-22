ifndef __mk_ready
MAKEFLAGS += --check-symlink-times
MAKEFLAGS += --no-print-directory
.DEFAULT_GOAL := all

%:
	@$(MAKE) __mk_ready=1 $@

else

# Vars for building the bootc image
FEDORA_VERSION ?= 43
RUNTIME ?= podman
USERNAME ?= james
PASSWORD ?= password
PRIVATE_KEY ?= $$HOME/.ssh/id_ed25519
KUBECONFIG ?= $$HOME/.kube/config
BASE ?= quay.io/fedora/fedora-bootc:$(FEDORA_VERSION)
REGISTRY ?= quay.io
REPOSITORY ?= solacelost/bootc-image
REG_REPO := $(REGISTRY)/$(REPOSITORY)
SOURCE_REPO ?= https://github.com/$(REPOSITORY)
SOURCE_REPO_COMMIT ?= $(shell git describe --tags --first-parent --abbrev=40 --long --dirty --always)
TAG ?= latest
IMAGE = $(REG_REPO):$(TAG)
# Help find out if our base image has updated
ARCH := amd64
LATEST_DIGEST := $(shell hack/latest_base.sh $(BASE) $(ARCH))

# Vars only for building the kickstart-based installer
DEFAULT_INSTALL_DISK ?= vda
BOOT_VERSION ?= $(FEDORA_VERSION)
ISO_SUFFIX ?=
# ISO_DEST is the device to burn the iso to (such as a USB flash drive for live booting the installer on metal)
ISO_DEST ?= /dev/sda
# NETWORK defines the kickstart arguments for configuring the network, defaulting to DHCP on wired links
NETWORK := --bootproto=dhcp --device=link --activate
TZ := America/New_York
LUKS_PASSWORD ?=
# Templating the kickstart variables is tricky
KICKSTART_VARS = IMAGE=$(IMAGE) \
	DEFAULT_DISK=$(DEFAULT_INSTALL_DISK) \
	ISO_SUFFIX=$(ISO_SUFFIX) \
	USERNAME=$(USERNAME) \
	PASSWORD="$(PASSWORD)" \
	NETWORK="$(NETWORK)" \
	LUKS_PASSWORD="$(LUKS_PASSWORD)" \
	TZ=$(TZ)

BUILD_DATE := $(shell date '+%Y%m%d')
BUILD_ID := $(shell hack/calculate_build_id.sh $(IMAGE) $(BUILD_DATE))
VERSION := $(shell printf "%s.%s.%s" $(FEDORA_VERSION) $(BUILD_DATE) $(BUILD_ID))

.PHONY: all
all: push

tmp/Containerfile: Containerfile.tpl $(wildcard Containerfile.d/*)
	@hack/template-containerfile.awk $< > $@

tmp/auth.json:
	@echo Please put a valid auth.json for $(REGISTRY) to push $(IMAGE) in $@ >&2
	@exit 1

tmp/$(LATEST_DIGEST):
	@touch $@

.build-$(TAG)-unchunked: tmp/Containerfile tmp/$(LATEST_DIGEST) $(shell find overlays -type f -o -type l)
	sudo $(RUNTIME) build \
		--arch $(ARCH) \
		--pull=newer \
		--security-opt=label=disable \
		--cap-add=all \
		--device=/dev/fuse \
		--build-arg=FEDORA_VERSION=$(FEDORA_VERSION) \
		--build-arg=IMAGE_REF=$(IMAGE) \
		--label=dev.jharmison.commit=$(SOURCE_REPO_COMMIT) \
		--label=dev.jharmison.git-repository=$(SOURCE_REPO) \
		--label=org.opencontainers.image.version=$(VERSION) \
		--from $(BASE) \
		-f $< \
		. \
		-t $(IMAGE)-unchunked
	@touch $@

.build-$(TAG): .build-$(TAG)-unchunked
	sudo podman image rm $(IMAGE) ||:
	sudo $(RUNTIME) run \
		--rm \
		--arch $(ARCH) \
		--privileged \
		--pull=never \
		--security-opt=label=disable \
		-v /var/lib/containers:/var/lib/containers \
		--entrypoint=/usr/libexec/bootc-base-imagectl \
		$(IMAGE)-unchunked \
		rechunk $(IMAGE)-unchunked $(IMAGE)
	@touch $@

.PHONY: build-unchunked
build-unchunked: .build-$(TAG)-unchunked

.PHONY: build
build: .build-$(TAG)

.push-$(TAG): tmp/auth.json .build-$(TAG)
	sudo $(RUNTIME) push --authfile $< $(IMAGE)
	@touch $@

.PHONY: push
push: .push-$(TAG)

.PHONY: debug
debug:
	sudo $(RUNTIME) run --rm -it --arch $(ARCH) --pull=never --entrypoint /bin/bash $(IMAGE) -li

boot-image/fedora-live.x86_64.iso:
	curl --retry 10 --retry-all-errors -Lo $@ https://download.fedoraproject.org/pub/fedora/linux/releases/${BOOT_VERSION}/Everything/x86_64/iso/$(shell curl -s --retry 10 --retry-all-errors -L https://download.fedoraproject.org/pub/fedora/linux/releases/${BOOT_VERSION}/Everything/x86_64/iso/ | grep 'href="' | grep '\.iso</a>' | grep -o '>Fedora-Everything-netinst.*\.iso<' | head -c-2 | tail -c+2)

boot-image/bootc$(ISO_SUFFIX).ks: boot-image/bootc.ks.tpl
	$(KICKSTART_VARS) envsubst '$$IMAGE,$$USERNAME,$$DEFAULT_DISK,$$ISO_SUFFIX,$$PASSWORD,$$NETWORK,$$LUKS_PASSWORD,$$TZ' < $< >$@

boot-image/container$(ISO_SUFFIX)/index.json: .build-$(TAG)
	sudo rm -rf boot-image/container$(ISO_SUFFIX)
	sudo skopeo copy containers-storage:$(IMAGE) oci:boot-image/container$(ISO_SUFFIX)

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

.PHONY: print-version
print-version:
	@echo $(VERSION)

.PHONY: clean
clean:
	sudo rm -rf .build* .push* boot-image/*.iso boot-image/*.ks boot-image/container*
	sudo podman image rm $(IMAGE) ||:
	sudo podman image rm $(IMAGE)-unchunked ||:
	sudo buildah rm --all
	sudo podman image prune

endif # __mk_ready
