# syntax=docker/dockerfile:1

# Upstream OpenCode, republished with git, Python, Node and a build toolchain
# added. Everything else stays upstream: same base image, same root user, same
# ENTRYPOINT and the same paths under /root. The CMD only starts the server.
# CI passes the version; this default only keeps a plain docker build working.
ARG OPENCODE_VERSION=2.3.0
FROM ghcr.io/anomalyco/opencode:${OPENCODE_VERSION}

# One layer. --no-cache keeps the package index out of the image, so the layer
# holds only installed files.
# Every name below is in the Alpine 3.24 main or community index.
# Names stay explicit even when another package also pulls them in.
RUN apk add --no-cache \
      autoconf \
      automake \
      bash \
      build-base \
      ca-certificates \
      cmake \
      coreutils \
      curl \
      diffutils \
      file \
      findutils \
      gawk \
      git \
      git-lfs \
      github-cli \
      grep \
      gzip \
      jq \
      libffi-dev \
      libtool \
      linux-headers \
      nodejs \
      nodejs-dev \
      npm \
      openssh-client \
      openssl \
      openssl-dev \
      pkgconf \
      py3-pip \
      python3 \
      python3-dev \
      sed \
      sqlite \
      tar \
      tzdata \
      unzip \
      uv \
      xz \
      zip \
      zlib-dev \
      zstd

# Runtime self-sufficient: no compose-supplied environment needed.
# Anything safe as an image default lives here; secrets stay in the deployment.
ENV PATH=/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    SHELL=/bin/bash \
    HISTFILE=/root/.local/state/bash_history \
    NPM_CONFIG_PREFIX=/root/.local \
    NPM_CONFIG_USERCONFIG=/root/.config/npmrc \
    NPM_CONFIG_CACHE=/tmp/npm \
    XDG_CACHE_HOME=/tmp/cache \
    UV_LINK_MODE=copy \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    GIT_CONFIG_GLOBAL=/root/.config/gitconfig \
    GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" \
    OPENCODE_DISABLE_AUTOUPDATE=1

# nodejs-dev ships the headers node-gyp needs. Alpine builds Node with
# use_prefix_to_find_headers and prefix /usr, so node-gyp finds them on its
# own; native addons build offline with a read-only root and no extra env.

# Tools that read $XDG_CONFIG_HOME-style paths expect the files to exist; a
# missing gitconfig also makes git die with a fatal error, not just warnings.
# Named volumes hide image-created files when they're empty, so a small
# entrypoint seeds missing ones at container start.
RUN mkdir -p /root/.config /root/.ssh && \
    touch /root/.config/gitconfig /root/.config/npmrc && \
    printf '#!/bin/sh\nfor f in /root/.config/gitconfig /root/.config/npmrc; do\n  [ -f "$f" ] || touch "$f" || true\ndone\nchmod 700 /root/.ssh 2>/dev/null || true\nexec opencode "$@"\n' > /usr/local/bin/oc-init && \
    chmod 0755 /usr/local/bin/oc-init

# Sensible default: a plain `docker run` serves. Deployments override CMD.
WORKDIR /workspace
CMD ["serve", "--hostname", "0.0.0.0", "--port", "4096"]

# ENTRYPOINT passes through the upstream opencode binary after seeding the
# bind-masked files. docker exec / docker logs keep their usual meaning.
ENTRYPOINT ["/usr/local/bin/oc-init"]

# No HEALTHCHECK: the check belongs to the deployment.
