FROM oci-archive:./tmp/out.ociarchive as composed

# Ensure our repos and keys are available for use later maybe
COPY overlays/repos/ /

FROM composed as xdg-terminal-exec-build

ENV COMMIT=0def84a3ffa70831c3c63d93cf79eb1090346004

WORKDIR /build

RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install scdoc

RUN curl -sLo /tmp/xdg-terminal-exec.tar.gz "https://github.com/Vladimir-csp/xdg-terminal-exec/archive/${COMMIT}.tar.gz" && \
    tar xvzf /tmp/xdg-terminal-exec.tar.gz && \
    cd xdg-terminal-exec-${COMMIT} && \
    make install prefix=/built/usr/local

FROM composed as lan-mouse-build

ENV COMMIT=3e1c3e95b73a26554154b0bf7387912e258ac74a
ENV HOME=/var/roothome

WORKDIR /build

RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install libXtst-devel

RUN curl -sLo /tmp/lan-mouse.tar.gz "https://github.com/feschber/lan-mouse/archive/${COMMIT}.tar.gz" && \
    tar xvzf /tmp/lan-mouse.tar.gz

RUN cd lan-mouse-${COMMIT} && \
    cargo build --release --no-default-features --features layer_shell_capture,wlroots_emulation

RUN mkdir -p /built/usr/local/bin /built/etc/systemd/user /built/etc/firewalld/services && \
    cp lan-mouse-${COMMIT}/target/release/lan-mouse /built/usr/local/bin/ && \
    sed 's/\/usr\/bin\/lan-mouse/\/usr\/local\/bin\/lan-mouse/' lan-mouse-${COMMIT}/service/lan-mouse.service > /built/etc/systemd/user/lan-mouse.service && \
    cp lan-mouse-${COMMIT}/firewall/lan-mouse.xml /built/etc/firewalld/services/

FROM composed as module-build

RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    kver=$(dnf list --installed | awk '/kernel\.x86_64/{print $2}') && \
    dnf -y install kernel-devel-matched-$kver cabextract && \
    find /usr/lib/modules -mindepth 1 -maxdepth 1 | sort -V | tail -1 > /moddir

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
RUN curl -sLo /tmp/xone.tar.gz "https://github.com/medusalix/xone/archive/${COMMIT}.tar.gz" && \
    tar xvzf /tmp/xone.tar.gz && \
    cd "xone-${COMMIT}" && \
    curl -sLo kernel-6.12.patch https://patch-diff.githubusercontent.com/raw/medusalix/xone/pull/53.patch && \
    git apply kernel-6.12.patch && \
    moddir="$(cat /moddir)" && \
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
    moddir="$(cat /moddir)" && \
    tar xvzf /tmp/v4l2loopback.tar.gz && \
    cd "v4l2loopback-${VERSION}" && \
    make V=1 install-utils DESTDIR=/built PREFIX=/usr && \
    make V=1 install-man DESTDIR=/built PREFIX=/usr && \
    make V=1 -C "$moddir/build" "M=${PWD}" && \
    mkdir -p "/built$moddir/extra/v4l2loopback" && \
    cp -r v4l2loopback.ko "/built$moddir/extra/v4l2loopback/"

# TODO: Shikane: https://gitlab.com/w0lff/shikane

FROM composed as final

# Some uncomposable changes
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install \
    https://github.com/derailed/k9s/releases/download/v0.32.7/k9s_linux_amd64.rpm \
    https://github.com/getsops/sops/releases/download/v3.9.4/sops-3.9.4-1.x86_64.rpm && \
    python3 -m pip --no-cache-dir install \
    git+https://github.com/AUNaseef/protonup.git@4ff9d5474eeb868d375f53a144177ba44f3b77cc \
    nautilus-open-any-terminal && \
    glib-compile-schemas /usr/local/share/glib-2.0/schemas && \
    mkdir -p /usr/share/fonts/inconsolata && \
    curl -Lo- https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/Inconsolata.tar.xz | tar xvJ -C /usr/share/fonts/inconsolata && \
    chown -R root:root /usr/share/fonts/inconsolata && \
    fc-cache -f -v && \
    curl -sLo- "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz" | tar xvz -C /usr/local/bin && \
    chmod +x /usr/local/bin/{kubectl,oc} && \
    authselect enable-feature with-fingerprint

# Copy xdg-terminal-exec
COPY --from=xdg-terminal-exec-build /built/ /
# Copy lan-mouse
COPY --from=lan-mouse-build /built/ /
# Copy our built modules
COPY --from=xone-build /built/ /
COPY --from=v4l2loopback-build /built/ /

# Ensure module dependencies are calculated
RUN kver="$(basename "$(find /usr/lib/modules -mindepth 1 -maxdepth 1 | sort -V | tail -1)")" && \
    depmod -a -b /usr "$kver"

# Ensure our basic user configuration is present
COPY overlays/users/ /

# Ensure our generic system configuration is represented
COPY overlays/base/ /

# Ensure Red Hat configuration (keys, git configs, VPN, etc) are staged
COPY overlays/redhat/ /

# Ensure our Sway image is configured correctly (configs, flatpaks, etc.)
COPY overlays/gui-sway/ /

# Ensure our certificates have been compiled into a trusted bundle, our desktop shortcuts are available, etc.
RUN update-ca-trust && \
    update-desktop-database

# Make sure we're gucci
RUN bootc container lint
