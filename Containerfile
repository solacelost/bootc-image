FROM quay.io/fedora/fedora:41 as builder

ARG MANIFEST=fedora-bootc.yaml

RUN dnf -y install rpm-ostree selinux-policy-targeted

COPY compose /src
WORKDIR /src

# Ensure our repos and keys are available for composing
COPY overlays/repos/ /

RUN --mount=type=cache,target=/workdir \
  --mount=type=bind,rw=true,src=./tmp/,dst=/buildcontext,bind-propagation=shared \
  cp /etc/yum.repos.d/*.repo ./ && \
  rm -f /buildcontext/out.ociarchive && \
  rpm-ostree compose image --image-config fedora-bootc-config.json \
  --cachedir=/workdir --format=ociarchive --initialize ${MANIFEST} \
  /buildcontext/out.ociarchive

FROM oci-archive:./tmp/out.ociarchive as final

# Install packages we couldn't compose in.
# NOTE: Need to reference builder here to force ordering.
RUN --mount=type=bind,from=builder,src=.,target=/var/tmp \
  --mount=target=/var/cache,type=tmpfs --mount=target=/var/cache/dnf,type=cache,id=dnf-cache \
  dnf -y install \
  https://github.com/derailed/k9s/releases/download/v0.32.5/k9s_linux_amd64.rpm \
  https://github.com/getsops/sops/releases/download/v3.9.1/sops-3.9.1-1.x86_64.rpm

# Ensure our generic system configuration is represented
COPY overlays/base/ /

# Ensure our Sway image is configured correctly
COPY overlays/gui-sway/ /

# Some GUI-specific configuration (like fonts)
RUN mkdir -p /usr/share/fonts/inconsolata && \
  curl -Lo- https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Inconsolata.tar.xz | tar xvJ -C /usr/share/fonts/inconsolata && \
  chown -R root:root /usr/share/fonts/inconsolata && \
  fc-cache -f -v

# Ensure our basic user configuration is present
COPY overlays/users/ /

FROM final as xone-build

WORKDIR /build

COPY overlays/xone/ /

# Download and unpack the firmware
RUN --mount=target=/var/cache,type=tmpfs --mount=target=/var/cache/dnf,type=cache,id=dnf-cache \
  dnf -y install cabextract && \
  curl -sLo /tmp/xow_dongle.cab http://download.windowsupdate.com/c/msdownload/update/driver/drvs/2017/07/1cd6a87c-623f-4407-a52d-c31be49e925c_e19f60808bdcbfbd3c3df6be3e71ffc52e43261e.cab && \
  cabextract /tmp/xow_dongle.cab -F FW_ACC_00U.bin && \
  mkdir -p /built/usr/lib/firmware && \
  mv FW_ACC_00U.bin /built/usr/lib/firmware/xow_dongle.bin && \
  rm -f /tmp/xow_dongle.cab

# Download and build xone
RUN --mount=target=/var/cache,type=tmpfs --mount=target=/var/cache/dnf,type=cache,id=dnf-cache \
  dnf -y install kernel-devel && \
  curl -sLo /tmp/xone.tar.gz https://github.com/medusalix/xone/archive/29ec3577e52a50f876440c81267f609575c5161e/xone-29ec357.tar.gz && \
  tar xvzf /tmp/xone.tar.gz && \
  cd xone-29ec3577e52a50f876440c81267f609575c5161e && \
  curl -sLo kernel-6.11.patch https://patch-diff.githubusercontent.com/raw/medusalix/xone/pull/48.patch && \
  git apply kernel-6.11.patch && \
  kver=$(cd /usr/lib/modules && ls | sort -V | tail -1) && \
  make -C /usr/lib/modules/$kver/build M=$PWD && \
  mkdir -p /built/usr/lib/modules/$kver/updates/xone && \
  cp -r xone-*.ko /built/usr/lib/modules/$kver/updates/xone

FROM final
COPY --from=xone-build /built/ /
RUN kver=$(cd /usr/lib/modules && ls | sort -V | tail -1) && \
  depmod -a -b /usr $kver
