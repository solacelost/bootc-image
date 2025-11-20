# hadolint global ignore=DL3040,DL3041,DL4006
ARG FEDORA_VERSION=43
ARG IMAGE_REF=quay.io/solacelost/bootc-image:latest

# https://github.com/Vladimir-csp/xdg-terminal-exec
ARG XDG_TERMINAL_EXEC_COMMIT=363db91851b5a83d67603556b2da690125ac05f4
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
ARG NIRI_FORK_COMMIT=04e89b5dc01983e9eebaa8911e846744d0d0f4d7
# https://github.com/vinceliuice/Orchis-theme
ARG ORCHIS_COMMIT=d00dd33dde5a57eebfbc9b7e8488a535596bf125
# https://github.com/Supreeeme/xwayland-satellite
ARG XWAYLAND_SATELLITE_COMMIT=6338574bc5c036487486acde264f38f39ea15fad

FROM quay.io/fedora/fedora-bootc:${FEDORA_VERSION} as base

# Use only explicitly defined repositories
RUN rm -rf /etc/yum.repos.d
COPY overlays/repos/ /

# Swap to kernel-blu
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install --allowerasing --from-repo=kernel-blu \
    kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra

# Put install.py in $PATH
ENV PATH=/usr/libexec/jharmison-packages:$PATH

# Install prereq for install.py
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install python3-click

# Install defined packages for the lower targets
COPY overlays/early-packages/ /
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    install.py

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

FROM base as niri-build

ARG NIRI_FORK_REPO
ARG NIRI_FORK_COMMIT

COPY overlays/niri-build/ /
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    install.py -p niri-build

WORKDIR /build

RUN git clone --depth 1 --revision ${NIRI_FORK_COMMIT} ${NIRI_FORK_REPO}

WORKDIR /build/niri
ENV HOME=/var/roothome

RUN cargo build -r

WORKDIR /built

RUN install -Dm755 -t /built/usr/bin /build/niri/target/release/niri && \
    install -Dm755 -t /built/usr/bin /build/niri/resources/niri-session && \
    install -Dm644 -t /built/usr/share/wayland-sessions /build/niri/resources/niri.desktop && \
    install -Dm644 -t /built/usr/share/xdg-desktop-portal /build/niri/resources/niri-portals.conf && \
    install -Dm644 -t /built/usr/lib/systemd/user /build/niri/resources/niri.service && \
    install -Dm644 -t /built/usr/lib/systemd/user /build/niri/resources/niri-shutdown.target && \
    install -Dm644 -t /built/usr/share/licenses/niri /build/niri/LICENSE

FROM base as xwayland-satellite-build

ARG XWAYLAND_SATELLITE_COMMIT

COPY overlays/xwayland-satellite-build/ /
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    install.py -p xwayland-satellite-build

WORKDIR /build

RUN git clone --depth 1 --revision ${XWAYLAND_SATELLITE_COMMIT} https://github.com/Supreeeme/xwayland-satellite

WORKDIR /build/xwayland-satellite
ENV HOME=/var/roothome

RUN cargo build -r -F systemd

WORKDIR /built

RUN install -Dpm0755 -t /built/usr/bin /build/xwayland-satellite/target/release/xwayland-satellite

FROM base as rpm-build

COPY overlays/rpmbuild/ /
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    install.py -p rpmbuild --setopt=fedora.exclude= --setopt=updates.exclude=


ENV RPMBUILD_BASE_DIR=/build \
    SRC_DIR=/src \
    GPG_TTY=/dev/console \
    HOME=/build

RUN mkdir -p $HOME

WORKDIR /src

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

COPY overlays/v4l2loopback/ /
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    install.py -p v4l2loopback-build

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

COPY overlays/displaylink/ /
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    install.py -p displaylink-build

RUN curl --retry-all-errors -Lo /tmp/displaylink.zip "https://www.synaptics.com/sites/default/files/exe_files/${DISPLAYLINK_PUBLISH_DIR}/DisplayLink%20USB%20Graphics%20Software%20for%20Ubuntu${DISPLAYLINK_VERSION}-EXE.zip" && \
    unzip /tmp/displaylink.zip && \
    rm -f /tmp/displaylink.zip

RUN curl --retry-all-errors -Lo- https://github.com/DisplayLink/evdi/archive/v${EVDI_VERSION}.tar.gz | tar xvz

RUN moddir="$(cat /moddir)" && \
    chmod +x displaylink-driver-*.run && \
    ./displaylink-driver-*.run --noexec --keep --target displaylink-driver-${DISPLAYLINK_VERSION} && \
    mkdir -p /built/usr/libexec/displaylink && \
    mv displaylink-driver-${DISPLAYLINK_VERSION}/x64-ubuntu-1604/DisplayLinkManager /built/usr/libexec/displaylink/ && \
    mv displaylink-driver-${DISPLAYLINK_VERSION}/{ella-dock,firefly-monitor,navarro-dock,ridge-dock}-release.spkg /built/usr/libexec/displaylink/ && \
    cd evdi-${EVDI_VERSION}/library && \
    make && \
    mv libevdi.so.${EVDI_VERSION} /built/usr/libexec/displaylink/ && \
    ln -s /usr/libexec/displaylink/libevdi.so.${EVDI_VERSION} /built/usr/libexec/displaylink/libevdi.so && \
    ln -s /usr/libexec/displaylink/libevdi.so.${EVDI_VERSION} /built/usr/libexec/displaylink/libevdi.so.1 && \
    cd ../module && \
    make V=1 -C "$moddir/build" "M=${PWD}" && \
    mkdir -p "/built$moddir/extra/evdi" && \
    mv evdi.ko "/built$moddir/extra/evdi"

RUN find /built -exec touch -d 1970-01-01T00:00:00Z {} \;

FROM base as orchis-build

ARG ORCHIS_COMMIT

COPY overlays/orchis/ /
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    install.py -p orchis-build

WORKDIR /build

RUN git clone --depth 1 --revision ${ORCHIS_COMMIT} https://github.com/vinceliuice/Orchis-theme

WORKDIR /build/Orchis-theme

RUN mkdir -p /built/usr/share/themes /built/usr/local/home/.config/gtk-4.0 && \
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

# Install defined packages for the higher targets (GUI etc.)
COPY overlays/late-packages/ /
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    install.py -d /usr/share/doc/jharmison-packages/gui

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
# Copy our built modules
COPY --from=xone-build /built/ /
COPY --from=v4l2loopback-build /built/ /
COPY --from=displaylink-build /built/ /
# Copy the compiled theme
COPY --from=orchis-build /built/ /
# Install custom niri fork
COPY --from=niri-build /built/ /
# Install mainline xwayland-satelilte
COPY --from=xwayland-satellite-build /built/ /

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
