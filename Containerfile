# hadolint global ignore=DL3040,DL3041,DL4006
ARG FEDORA_VERSION=42
ARG IMAGE_REF=registry.jharmison.com/library/fedora-bootc:desktop

# https://github.com/Vladimir-csp/xdg-terminal-exec
ARG XDG_TERMINAL_EXEC_COMMIT=b0dcbf7ef663d5079d8b75e74393307d153dc3d6
# https://github.com/feschber/lan-mouse
ARG LAN_MOUSE_COMMIT=e46fe60b3e24be83de38701faa99a4fbd9186f08
# https://github.com/wineasio/wineasio
ARG WINE_ASIO_VERSION=1.3.0
# https://github.com/dlundqvist/xone
ARG XONE_COMMIT=f9ae36467874ee1b7efb0bc7521a3e769aaf1ce6
# https://github.com/v4l2loopback/v4l2loopback
ARG V4L2LOOPBACK_VERSION=0.15.1
# https://github.com/derailed/k9s
ARG K9S_VERSION=0.50.9
# https://github.com/getsops/sops
ARG SOPS_VERSION=3.10.2
# https://github.com/AUNaseef/protonup
ARG PROTONUP_COMMIT=4ff9d5474eeb868d375f53a144177ba44f3b77cc
# https://pypi.org/project/nautilus-open-any-terminal/
ARG NAUTILUS_OPEN_ANY_TERMINAL_VERSION=0.6.3
# https://github.com/ryanoasis/nerd-fonts
ARG NERD_FONTS_VERSION=3.4.0

FROM quay.io/fedora/fedora-bootc:${FEDORA_VERSION} as base

COPY overlays/repos/ /

# Swap to kernel-blu
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install --allowerasing --from-repo=kernel-blu kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra

# Install defined packages
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    --mount=type=bind,src=./packages,dst=/packages \
    python3 /packages/install.py

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

FROM base as wineasio-build

WORKDIR /build

ARG WINE_ASIO_VERSION
ENV VERSION=${WINE_ASIO_VERSION}

RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install wine wine-devel.* pipewire-jack*.* glibc-devel.*

RUN curl --retry 10 --retry-all-errors -Lo /tmp/wineasio.tar.gz \
    https://github.com/wineasio/wineasio/releases/download/v${VERSION}/wineasio-${VERSION}.tar.gz && \
    tar xvzf /tmp/wineasio.tar.gz

WORKDIR /build/wineasio-${VERSION}

RUN make build ARCH=i386 M=32 LIBRARIES="-L/usr/lib/pipewire-0.3/jack -ljack" && \
    make build ARCH=x86_64 M=64 LIBRARIES="-L/usr/lib/pipewire-0.3/jack -L/usr/lib64/pipewire-0.3/jack -ljack" && \
    mkdir -p /built/usr/lib/wine/{i386-windows,i386-unix} /built/usr/lib64/wine/{x86_64-windows,x86_64-unix} /built/usr/local/bin && \
    cp build32/wineasio32.dll /built/usr/lib/wine/i386-windows/ && \
    cp build32/wineasio32.dll.so /built/usr/lib/wine/i386-unix/ && \
    cp build64/wineasio64.dll /built/usr/lib64/wine/x86_64-windows/ && \
    cp build64/wineasio64.dll.so /built/usr/lib64/wine/x86_64-unix/

COPY overlays/wineasio/ /

RUN find /built -exec touch -d 1970-01-01T00:00:00Z {} \;

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

# TODO: Shikane: https://gitlab.com/w0lff/shikane

FROM base as final

ARG K9S_VERSION
ARG SOPS_VERSION
ARG PROTONUP_COMMIT
ARG NAUTILUS_OPEN_ANY_TERMINAL_VERSION
ARG NERD_FONTS_VERSION
ARG IMAGE_REF

# Some uncomposable changes
RUN --mount=type=tmpfs,target=/var/cache \
    --mount=type=cache,id=dnf-cache,target=/var/cache/libdnf5 \
    dnf -y install \
    https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_linux_amd64.rpm \
    https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-${SOPS_VERSION}-1.x86_64.rpm && \
    uv pip install --no-cache --system \
    git+https://github.com/AUNaseef/protonup.git@${PROTONUP_COMMIT} \
    nautilus-open-any-terminal==${NAUTILUS_OPEN_ANY_TERMINAL_VERSION} && \
    glib-compile-schemas /usr/local/share/glib-2.0/schemas && \
    mkdir -p /usr/share/fonts/inconsolata && \
    curl --retry 10 --retry-all-errors -Lo- https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/Inconsolata.tar.xz | tar xvJ -C /usr/share/fonts/inconsolata && \
    chown -R root:root /usr/share/fonts/inconsolata && \
    fc-cache -f -v && \
    curl --retry 10 --retry-all-errors -Lo- "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz" | tar xvz -C /usr/local/bin && \
    chmod +x /usr/local/bin/{kubectl,oc} && \
    authselect enable-feature with-fingerprint && \
    echo "image = \"${IMAGE_REF}\"" >> /etc/containers/toolbox.conf

# Copy xdg-terminal-exec
COPY --from=xdg-terminal-exec-build /built/ /
# Copy lan-mouse
COPY --from=lan-mouse-build /built/ /
# Copy wineasio
COPY --from=wineasio-build /built/ /
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
    update-desktop-database && \
    rm -rf /var/roothome /var/log /boot/*

# Make sure we're gucci
RUN bootc container lint
