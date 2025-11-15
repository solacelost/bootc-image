# hadolint global ignore=DL3040,DL3041,DL4006
ARG FEDORA_VERSION=43
ARG IMAGE_REF=quay.io/solacelost/bootc-image:latest

# https://github.com/Vladimir-csp/xdg-terminal-exec
ARG XDG_TERMINAL_EXEC_COMMIT=363db91851b5a83d67603556b2da690125ac05f4
# https://github.com/feschber/lan-mouse
ARG LAN_MOUSE_COMMIT=640fa995a4ae3c5a0aaaafe04857930979edc220
# https://github.com/dlundqvist/xone
ARG XONE_COMMIT=90d965254e534151202e79f768bf7a68ea9f9d4f
# https://github.com/v4l2loopback/v4l2loopback
ARG V4L2LOOPBACK_VERSION=0.15.2
# https://github.com/derailed/k9s
ARG K9S_VERSION=0.50.16
# https://github.com/getsops/sops
ARG SOPS_VERSION=3.11.0
# https://github.com/AUNaseef/protonup
ARG PROTONUP_COMMIT=4ff9d5474eeb868d375f53a144177ba44f3b77cc
# https://pypi.org/project/nautilus-open-any-terminal/
ARG NAUTILUS_OPEN_ANY_TERMINAL_VERSION=0.7.0
# https://github.com/ryanoasis/nerd-fonts
ARG NERD_FONTS_VERSION=3.4.0
# https://www.synaptics.com/products/displaylink-graphics/downloads/ubuntu
# have to download the latest and look at the download url for the publish dir after accepting agreement
ARG DISPLAYLINK_PUBLISH_DIR=2025-09
ARG DISPLAYLINK_VERSION=6.2
ARG EVDI_VERSION=1.14.11
# https://github.com/sentriz/cliphist
ARG CLIPHIST_COMMIT=efb61cb5b5a28d896c05a24ac83b9c39c96575f2
# https://github.com/YaLTeR/niri/pull/2312
# https://github.com/scottmckendry/niri/tree/primary-render-fallback
ARG NIRI_FORK_REPO=https://github.com/scottmckendry/niri
ARG NIRI_FORK_COMMIT=7fb734d62f809f169bd06647260b0eceb9bdb078
# https://github.com/vinceliuice/Orchis-theme
ARG ORCHIS_COMMIT=d00dd33dde5a57eebfbc9b7e8488a535596bf125

FROM quay.io/fedora/fedora-bootc:${FEDORA_VERSION} as base

# Use only explicitly defined repositories
RUN rm -rf /etc/yum.repos.d
COPY overlays/repos/ /

# Swap to kernel-blu
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install --allowerasing --from-repo=kernel-blu kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra

ARG EARLY_PACKAGES_HASH
ENV EARLY_PACKAGES_HASH=${EARLY_PACKAGES_HASH}

# Install defined packages for the lower targets
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,src=./packages,dst=/packages \
    dnf -y install python3-click && \
    python3 /packages/install.py --min-level=0 --max-level=50

FROM base as xdg-terminal-exec-build

ARG XDG_TERMINAL_EXEC_COMMIT
ENV COMMIT=${XDG_TERMINAL_EXEC_COMMIT}

WORKDIR /build

RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install scdoc

RUN curl --retry 10 --retry-all-errors -Lo /tmp/xdg-terminal-exec.tar.gz "https://github.com/Vladimir-csp/xdg-terminal-exec/archive/${COMMIT}.tar.gz" && \
    tar xvzf /tmp/xdg-terminal-exec.tar.gz && \
    cd xdg-terminal-exec-${COMMIT} && \
    make install prefix=/built/usr/local

RUN find /built -exec touch -d 1970-01-01T00:00:00Z {} \;

FROM base as lan-mouse-build

ARG LAN_MOUSE_COMMIT
ENV COMMIT=${LAN_MOUSE_COMMIT}
ENV HOME=/var/roothome

WORKDIR /build

RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install libXtst-devel

RUN curl --retry 10 --retry-all-errors -Lo /tmp/lan-mouse.tar.gz "https://github.com/feschber/lan-mouse/archive/${COMMIT}.tar.gz" && \
    tar xvzf /tmp/lan-mouse.tar.gz

RUN cd lan-mouse-${COMMIT} && \
    cargo build --release --no-default-features --features layer_shell_capture,wlroots_emulation

RUN mkdir -p /built/usr/local/bin /built/etc/systemd/user /built/etc/firewalld/services && \
    cp lan-mouse-${COMMIT}/target/release/lan-mouse /built/usr/local/bin/ && \
    sed 's/\/usr\/bin\/lan-mouse/\/usr\/local\/bin\/lan-mouse/' lan-mouse-${COMMIT}/service/lan-mouse.service > /built/etc/systemd/user/lan-mouse.service && \
    cp lan-mouse-${COMMIT}/firewall/lan-mouse.xml /built/etc/firewalld/services/

RUN find /built -exec touch -d 1970-01-01T00:00:00Z {} \;

FROM base as niri-build

ARG NIRI_FORK_REPO
ARG NIRI_FORK_COMMIT

RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install \
        rust-glib-sys-devel \
        rust-pangocairo-devel \
        libdisplay-info{,-devel} \
        rust-pipewire-devel \
        rust-xkbcommon-devel \
        rust-input-devel \
        mesa-libgbm{,-devel} \
        libseat{,-devel} \
        rust-libudev-devel

WORKDIR /app

RUN git clone "${NIRI_FORK_REPO}"

WORKDIR /app/niri
ENV HOME=/var/roothome

RUN git checkout ${NIRI_FORK_COMMIT} && \
    cargo build -r

WORKDIR /built

RUN install -Dm755 -t /built/usr/bin /app/niri/target/release/niri && \
    install -Dm755 -t /built/usr/bin /app/niri/resources/niri-session && \
    install -Dm644 -t /built/usr/share/wayland-sessions /app/niri/resources/niri.desktop && \
    install -Dm644 -t /built/usr/share/xdg-desktop-portal /app/niri/resources/niri-portals.conf && \
    install -Dm644 -t /built/usr/lib/systemd/user /app/niri/resources/niri.service && \
    install -Dm644 -t /built/usr/lib/systemd/user /app/niri/resources/niri-shutdown.target && \
    install -Dm644 -t /built/usr/share/licenses/niri /app/niri/LICENSE

FROM base as module-build

RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    kver=$(dnf list --installed | awk '/kernel\.x86_64/{print $2}') && \
    dnf -y install kernel-devel-matched-$kver cabextract && \
    find /usr/lib/modules -mindepth 1 -maxdepth 1 | sort -V | tail -1 > /moddir

WORKDIR /build

FROM module-build as xone-build

ARG XONE_COMMIT
ENV COMMIT=${XONE_COMMIT}

COPY overlays/xone/ /

# Download and unpack the firmware
RUN curl --retry 10 --retry-all-errors -Lo /tmp/xow_dongle.cab \
    https://catalog.s.download.windowsupdate.com/c/msdownload/update/driver/drvs/2017/07/1cd6a87c-623f-4407-a52d-c31be49e925c_e19f60808bdcbfbd3c3df6be3e71ffc52e43261e.cab && \
    cabextract /tmp/xow_dongle.cab -F FW_ACC_00U.bin && \
    echo "48084d9fa53b9bb04358f3bb127b7495dc8f7bb0b3ca1437bd24ef2b6eabdf66 FW_ACC_00U.bin" | sha256sum -c && \
    mkdir -p /built/usr/lib/firmware && \
    mv FW_ACC_00U.bin /built/usr/lib/firmware/xow_dongle.bin && \
    rm -f /tmp/xow_dongle.cab && \
    curl --retry 10 --retry-all-errors -Lo /tmp/xow_dongle.cab \
    https://catalog.s.download.windowsupdate.com/d/msdownload/update/driver/drvs/2015/12/20810869_8ce2975a7fbaa06bcfb0d8762a6275a1cf7c1dd3.cab && \
    cabextract /tmp/xow_dongle.cab -F FW_ACC_00U.bin && \
    echo "080ce4091e53a4ef3e5fe29939f51fd91f46d6a88be6d67eb6e99a5723b3a223 FW_ACC_00U.bin" | sha256sum -c && \
    mv FW_ACC_00U.bin /built/usr/lib/firmware/xow_dongle_045e_02e6.bin && \
    rm -f /tmp/xow_dongle.cab

# Download and build xone
# hadolint ignore=DL3003
RUN curl --retry 10 --retry-all-errors -Lo /tmp/xone.tar.gz "https://github.com/dlundqvist/xone/archive/${COMMIT}.tar.gz" && \
    tar xvzf /tmp/xone.tar.gz && \
    cd "xone-${COMMIT}" && \
    moddir="$(cat /moddir)" && \
    make -C "$moddir/build" "M=$PWD" && \
    mkdir -p "/built$moddir/extra/xone" && \
    cp -r xone_*.ko "/built$moddir/extra/xone/"

RUN find /built -exec touch -d 1970-01-01T00:00:00Z {} \;

FROM module-build as v4l2loopback-build

ARG V4L2LOOPBACK_VERSION
ENV VERSION=${V4L2LOOPBACK_VERSION}

RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install help2man elfutils-libelf-devel

COPY overlays/v4l2loopback/ /

# hadolint ignore=DL3003
RUN curl --retry 10 --retry-all-errors -Lo /tmp/v4l2loopback.tar.gz "https://github.com/v4l2loopback/v4l2loopback/archive/v${VERSION}/v4l2loopback-${VERSION}.tar.gz" && \
    moddir="$(cat /moddir)" && \
    tar xvzf /tmp/v4l2loopback.tar.gz && \
    cd "v4l2loopback-${VERSION}" && \
    make V=1 install-utils DESTDIR=/built PREFIX=/usr && \
    make V=1 install-man DESTDIR=/built PREFIX=/usr && \
    make V=1 -C "$moddir/build" "M=${PWD}" && \
    mkdir -p "/built$moddir/extra/v4l2loopback" && \
    cp -r v4l2loopback.ko "/built$moddir/extra/v4l2loopback/"

RUN find /built -exec touch -d 1970-01-01T00:00:00Z {} \;

FROM module-build as displaylink-build

ARG DISPLAYLINK_PUBLISH_DIR
ARG DISPLAYLINK_VERSION
ARG EVDI_VERSION

WORKDIR /build

RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install libdrm-devel

RUN curl --retry-all-errors -Lo displaylink.zip "https://www.synaptics.com/sites/default/files/exe_files/${DISPLAYLINK_PUBLISH_DIR}/DisplayLink%20USB%20Graphics%20Software%20for%20Ubuntu${DISPLAYLINK_VERSION}-EXE.zip" && \
    curl --retry-all-errors -Lo evdi.tar.gz https://github.com/DisplayLink/evdi/archive/v${EVDI_VERSION}.tar.gz

RUN moddir="$(cat /moddir)" && \
    unzip displaylink.zip && \
    chmod +x displaylink-driver-*.run && \
    ./displaylink-driver-*.run --noexec --keep --target displaylink-driver-${DISPLAYLINK_VERSION} && \
    mkdir -p /built/usr/libexec/displaylink && \
    mv displaylink-driver-${DISPLAYLINK_VERSION}/x64-ubuntu-1604/DisplayLinkManager /built/usr/libexec/displaylink/ && \
    mv displaylink-driver-${DISPLAYLINK_VERSION}/{ella-dock,firefly-monitor,navarro-dock,ridge-dock}-release.spkg /built/usr/libexec/displaylink/ && \
    tar xvzf evdi.tar.gz && \
    cd evdi-${EVDI_VERSION}/library && \
    make && \
    mv libevdi.so.${EVDI_VERSION} /built/usr/libexec/displaylink/ && \
    ln -s /usr/libexec/displaylink/libevdi.so.${EVDI_VERSION} /built/usr/libexec/displaylink/libevdi.so && \
    ln -s /usr/libexec/displaylink/libevdi.so.${EVDI_VERSION} /built/usr/libexec/displaylink/libevdi.so.1 && \
    cd ../module && \
    make V=1 -C "$moddir/build" "M=${PWD}" && \
    mkdir -p "/built$moddir/extra/evdi" && \
    mv evdi.ko "/built$moddir/extra/evdi"

COPY overlays/displaylink/ /

RUN find /built -exec touch -d 1970-01-01T00:00:00Z {} \;

FROM base as orchis-build

ARG ORCHIS_COMMIT

WORKDIR /build

RUN mkdir -p /built/usr/share/themes && \
    git clone https://github.com/vinceliuice/Orchis-theme && \
    cd Orchis-theme && \
    git checkout "${ORCHIS_COMMIT}" && \
    ./install.sh -d /built/usr/share/themes && \
    for themefile in assets gtk.css gtk-dark.css; do \
      ln -sf /usr/share/themes/Orchis-Dark-Compact/gtk-4.0/$themefile /built/usr/local/home/.config/gtk-4.0/$themefile ; \
    done

# TODO: Shikane: https://gitlab.com/w0lff/shikane

FROM base as final

ARG K9S_VERSION
ARG SOPS_VERSION
ARG PROTONUP_COMMIT
ARG NAUTILUS_OPEN_ANY_TERMINAL_VERSION
ARG NERD_FONTS_VERSION
ARG IMAGE_REF
ARG CLIPHIST_COMMIT

ARG LATE_PACKAGES_HASH
ENV LATE_PACKAGES_HASH=${LATE_PACKAGES_HASH}

# Install defined packages for the higher targets (GUI etc.)
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,src=./packages,dst=/packages \
    python3 /packages/install.py --min-level=51 --max-level=100

# Some uncomposable changes
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install \
    https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_linux_amd64.rpm \
    https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-${SOPS_VERSION}-1.x86_64.rpm
RUN uv pip install --no-cache --system \
    git+https://github.com/AUNaseef/protonup.git@${PROTONUP_COMMIT} \
    nautilus-open-any-terminal==${NAUTILUS_OPEN_ANY_TERMINAL_VERSION}
RUN glib-compile-schemas /usr/local/share/glib-2.0/schemas
RUN mkdir -p /usr/share/fonts/inconsolata && \
    curl --retry 10 --retry-all-errors -Lo- https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/Inconsolata.tar.xz | tar xvJ -C /usr/share/fonts/inconsolata && \
    chown -R root:root /usr/share/fonts/inconsolata && \
    fc-cache -f -v
RUN mkdir -p /tmp/go/{cache,bin} && \
    GOPATH=/tmp/go GOCACHE=/tmp/go/.cache go install go.senan.xyz/cliphist@${CLIPHIST_COMMIT} && \
    mv /tmp/go/bin/cliphist /usr/local/bin/ && \
    curl -Lo /usr/local/bin/cliphist-fuzzel-img https://raw.githubusercontent.com/sentriz/cliphist/${CLIPHIST_COMMIT}/contrib/cliphist-fuzzel-img && \
    chmod +x /usr/local/bin/cliphist-fuzzel-img
RUN plymouth-set-default-theme spinner
RUN authselect enable-feature with-fingerprint
RUN echo "image = \"${IMAGE_REF}\"" >> /etc/containers/toolbox.conf

# Copy xdg-terminal-exec
COPY --from=xdg-terminal-exec-build /built/ /
# Copy lan-mouse
COPY --from=lan-mouse-build /built/ /
# Copy our built modules
COPY --from=xone-build /built/ /
COPY --from=v4l2loopback-build /built/ /
COPY --from=displaylink-build /built/ /
# Copy the compiled theme
COPY --from=orchis-build /built/ /
# Install custom niri fork
COPY --from=niri-build /built/ /

# Ensure our generic system configuration is represented
COPY overlays/base/ /
# Ensure Red Hat configuration (keys, git configs, VPN, etc) are staged
COPY overlays/redhat/ /
# Ensure our GUI is configured correctly (configs, flatpaks, etc.)
COPY overlays/gui-apps/ /
COPY overlays/gui-games/ /
COPY overlays/gui-system/ /
COPY overlays/gui-tiling/ /
COPY overlays/gui-niri/ /

# Ensure module dependencies are calculated
RUN kver="$(basename "$(find /usr/lib/modules -mindepth 1 -maxdepth 1 | sort -V | tail -1)")" && \
    depmod -a -b /usr "$kver"

# Ensure our certificates have been compiled into a trusted bundle, our desktop shortcuts are available, etc.
RUN update-ca-trust && \
    update-desktop-database && \
    rm -rf /var/roothome /var/log /boot/* /.nvimlog

# Make sure we're gucci
RUN bootc container lint
