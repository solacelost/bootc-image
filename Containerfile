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

FROM oci-archive:./tmp/out.ociarchive

# Install packages we couldn't compose in.
# NOTE: Need to reference builder here to force ordering.
RUN --mount=type=bind,from=builder,src=.,target=/var/tmp \
  --mount=target=/var/cache,type=tmpfs --mount=target=/var/cache/dnf,type=cache,id=dnf-cache \
  dnf -y install \
  https://github.com/jgraph/drawio-desktop/releases/download/v24.7.17/drawio-x86_64-24.7.17.rpm \
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
