# syntax=docker/dockerfile:1

# Upstream OpenCode, republished with git, Python, Node and a build toolchain
# added. Everything else stays upstream: same base image, same root user, same
# ENTRYPOINT, same paths under /root, no CMD, no WORKDIR.
# Stale by design: CI passes the version; this default only keeps a plain
# docker build working.
ARG OPENCODE_VERSION=2.2.7
FROM ghcr.io/anomalyco/opencode:${OPENCODE_VERSION}

# One layer. --no-cache keeps the package index out of the image, so the layer
# holds only installed files.
# Every name below is in the Alpine 3.24 main or community index.
# Names stay explicit even when another package also pulls them in: apk
# removes duplicates, so an upstream dependency change cannot silently drop a
# tool.
RUN apk add --no-cache \
      bash \
      build-base \
      ca-certificates \
      cmake \
      coreutils \
      curl \
      git \
      github-cli \
      jq \
      nodejs \
      npm \
      openssh-client \
      openssl \
      pkgconf \
      py3-pip \
      python3 \
      python3-dev \
      unzip \
      uv

# No HEALTHCHECK: upstream has none, and the check belongs to the deployment.
