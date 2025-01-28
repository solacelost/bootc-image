# hadolint global ignore=DL3040,DL3041,DL4006
FROM registry.fedoraproject.org/fedora:41 as builder

ARG FEDORA_VERSION=41

RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install rpm-ostree selinux-policy-targeted

COPY compose /src
WORKDIR /src

# Ensure our repos and keys are available for composing
COPY overlays/repos/ /

RUN --mount=type=cache,id=ostree-cache,target=/cache \
    --mount=type=bind,rw=true,src=./tmp/,dst=/buildcontext,bind-propagation=shared \
    cp /etc/yum.repos.d/*.repo ./ && \
    ls -halF /buildcontext && \
    rm -f /buildcontext/out.ociarchive && \
    echo "releasever: ${FEDORA_VERSION}" >> fedora-bootc.yaml && \
    sleep 1 && \
    rpm-ostree compose image --image-config fedora-bootc-config.json \
    --cachedir=/cache --format=ociarchive --initialize fedora-bootc.yaml \
    /buildcontext/out.ociarchive

FROM oci-archive:./tmp/out.ociarchive as composed

# Ensure libostree configuration and other important base files are present
COPY overlays/composed/ /

FROM composed as module-build

RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install kernel-devel cabextract

WORKDIR /build

FROM module-build as xone-build

ENV COMMIT=29ec3577e52a50f876440c81267f609575c5161e

COPY overlays/xone/ /

# Download and unpack the firmware
RUN curl -sLo /tmp/xow_dongle.cab \
    http://download.windowsupdate.com/c/msdownload/update/driver/drvs/2017/07/1cd6a87c-623f-4407-a52d-c31be49e925c_e19f60808bdcbfbd3c3df6be3e71ffc52e43261e.cab && \
    cabextract /tmp/xow_dongle.cab -F FW_ACC_00U.bin && \
    mkdir -p /built/usr/lib/firmware && \
    mv FW_ACC_00U.bin /built/usr/lib/firmware/xow_dongle.bin && \
    rm -f /tmp/xow_dongle.cab

# Download and build xone
# hadolint ignore=DL3003
RUN SHORT_COMMIT="$(echo "${COMMIT}" | cut -c1-7)" && \
    curl -sLo /tmp/xone.tar.gz "https://github.com/medusalix/xone/archive/${COMMIT}/xone-${SHORT_COMMIT}.tar.gz" && \
    tar xvzf /tmp/xone.tar.gz && \
    cd "xone-${COMMIT}" && \
    curl -sLo kernel-6.12.patch https://patch-diff.githubusercontent.com/raw/medusalix/xone/pull/53.patch && \
    git apply kernel-6.12.patch && \
    moddir="$(find /usr/lib/modules -mindepth 1 -maxdepth 1 | sort -V | tail -1)" && \
    make -C "$moddir/build" "M=$PWD" && \
    mkdir -p "/built$moddir/extra/xone" && \
    cp -r xone-*.ko "/built$moddir/extra/xone/"

FROM module-build as v4l2loopback-build

ENV VERSION=0.13.2

RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install help2man elfutils-libelf-devel

COPY overlays/v4l2loopback/ /

# hadolint ignore=DL3003
RUN curl -sLo /tmp/v4l2loopback.tar.gz "https://github.com/umlaeute/v4l2loopback/archive/v${VERSION}/v4l2loopback-${VERSION}.tar.gz" && \
    moddir="$(find /usr/lib/modules -mindepth 1 -maxdepth 1 | sort -V | tail -1)" && \
    tar xvzf /tmp/v4l2loopback.tar.gz && \
    cd "v4l2loopback-${VERSION}" && \
    make V=1 install-utils DESTDIR=/built PREFIX=/usr && \
    make V=1 install-man DESTDIR=/built PREFIX=/usr && \
    make V=1 -C "$moddir/build" "M=${PWD}" && \
    mkdir -p "/built$moddir/extra/v4l2loopback" && \
    cp -r v4l2loopback.ko "/built$moddir/extra/v4l2loopback/"

# TODO: Shikane: https://gitlab.com/w0lff/shikane

FROM composed as final

# Install packages we couldn't compose in.
# NOTE: Need to reference builder here to force ordering.
RUN --mount=type=bind,from=builder,src=.,target=/var/tmp/host \
    --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install \
    https://github.com/derailed/k9s/releases/download/v0.32.7/k9s_linux_amd64.rpm \
    https://github.com/getsops/sops/releases/download/v3.9.1/sops-3.9.1-1.x86_64.rpm && \
    python3 -m pip install git+https://github.com/AUNaseef/protonup.git@4ff9d5474eeb868d375f53a144177ba44f3b77cc

# GUI-specific font configuration
RUN mkdir -p /usr/share/fonts/inconsolata && \
    curl -Lo- https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Inconsolata.tar.xz | tar xvJ -C /usr/share/fonts/inconsolata && \
    chown -R root:root /usr/share/fonts/inconsolata && \
    fc-cache -f -v

# Copy our built modules
COPY --from=xone-build /built/ /
COPY --from=v4l2loopback-build /built/ /

# Ensure module dependencies are calculated
RUN kver="$(basename "$(find /usr/lib/modules -mindepth 1 -maxdepth 1 | sort -V | tail -1)")" && \
    depmod -a -b /usr "$kver"

# Ensure we have the latest oc available
RUN curl -sLo- "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz" | tar xvz -C /usr/local/bin && \
    chmod +x /usr/local/bin/{kubectl,oc}

# Make sure fprintd is called
RUN authselect enable-feature with-fingerprint

# Ensure our basic user configuration is present
COPY overlays/users/ /

# Ensure our generic system configuration is represented
COPY overlays/base/ /

# Ensure Red Hat configuration (keys, git configs, VPN, etc) are staged
COPY overlays/redhat/ /

# Ensure our Sway image is configured correctly (configs, flatpaks, .bash_profile, etc.)
COPY overlays/gui-sway/ /

# Ensure our certificates have been compiled into a trusted bundle
RUN update-ca-trust

# Make sure we're gucci
RUN bootc container lint
