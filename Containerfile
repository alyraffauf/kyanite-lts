###############################################################################
# BUILD ARGUMENTS
###############################################################################
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-centos-bootc}"
# Static value enables Renovate to detect and update the base image
ARG BASE_IMAGE="quay.io/centos-bootc/centos-bootc:c10s"
ARG BREW_IMAGE="ghcr.io/ublue-os/brew:latest"
ARG COMMON_IMAGE="ghcr.io/alyraffauf/kyanite-common:stable"
ARG COMMON_IMAGE_SHA="sha256:a1fa1ab4801f089c4d07481268bb283fa24bcbb902266caf55706001050d1a0f"
# SHA pinning enables Renovate to automatically update dependencies
# See: https://docs.renovatebot.com/docker/#digest-pinning

# Base Image @ centos-bootc/centos-bootc (CentOS Stream 10)
ARG BASE_IMAGE_SHA="sha256:2b7e3b1abf8db094d1efb083721dc0f72e6feeef2355fc16ea010d0266b2bb95"

# Brew Image
ARG BREW_IMAGE_SHA="sha256:de0391c67209703bdf1249079c8d478d44eff864d62e7ec6f12aaa382bdf21df"

# HWE kernel source (Universal Blue akmods cache with Fedora CoreOS kernel)
ARG HWE_KERNEL_IMAGE="ghcr.io/ublue-os/akmods-zfs:coreos-stable-43"
ARG HWE_KERNEL_IMAGE_SHA="sha256:545789f9e07317f3f5e7b695a902262283b53e259a83bade0743539969f8d559"

###############################################################################
# IMPORT STAGES
###############################################################################
FROM ${BREW_IMAGE}@${BREW_IMAGE_SHA} AS brew
FROM ${COMMON_IMAGE}@${COMMON_IMAGE_SHA} AS common
FROM ${HWE_KERNEL_IMAGE}@${HWE_KERNEL_IMAGE_SHA} AS hwe_kernel

FROM scratch AS ctx
COPY /build /build
COPY /files /files
COPY /brew /brew
COPY /flatpaks /flatpaks
COPY /ujust /ujust
COPY /packages.json /packages.json
COPY /services.json /services.json
COPY --from=common / /common

# Import Homebrew files
COPY --from=brew /system_files /oci/brew

###############################################################################
# MAIN IMAGE
###############################################################################
FROM ${BASE_IMAGE}@${BASE_IMAGE_SHA} AS base

# Build arguments for image metadata and variant selection
ARG IMAGE_NAME="${IMAGE_NAME:-kyanite-lts}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR:-alyraffauf}"
ARG IMAGE_FLAVOR="${IMAGE_FLAVOR:-main}"
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-centos-bootc}"
ARG SHA_HEAD_SHORT="${SHA_HEAD_SHORT:-}"
ARG UBLUE_IMAGE_TAG="${UBLUE_IMAGE_TAG:-stable}"

# Labels for image metadata
LABEL org.opencontainers.image.name="${IMAGE_NAME}"
LABEL org.opencontainers.image.vendor="${IMAGE_VENDOR}"
LABEL org.opencontainers.image.flavor="${IMAGE_FLAVOR}"

###############################################################################
# BUILD PROCESS
###############################################################################
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    IMAGE_FLAVOR="${IMAGE_FLAVOR}" \
    /ctx/build/01-stage-brewfiles.sh

RUN --mount=type=cache,dst=/var/cache/dnf \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/build/00-centos-repositories.sh

RUN --mount=type=cache,dst=/var/cache/dnf \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    IMAGE_FLAVOR="${IMAGE_FLAVOR}" \
    /ctx/build/02-centos-packages.sh

RUN --mount=type=cache,dst=/var/cache/dnf \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=hwe_kernel,source=/kernel-rpms,target=/tmp/kernel-rpms \
    IMAGE_FLAVOR="${IMAGE_FLAVOR}" \
    /ctx/build/03-hwe-kernel.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    IMAGE_FLAVOR="${IMAGE_FLAVOR}" \
    /ctx/build/05-copy-files.sh

# 06-systemd enables units that may be shipped by step 05; must follow it.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    IMAGE_FLAVOR="${IMAGE_FLAVOR}" \
    /ctx/build/06-systemd.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/build/07-homebrew.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    IMAGE_FLAVOR="${IMAGE_FLAVOR}" \
    IMAGE_NAME="${IMAGE_NAME}" \
    IMAGE_VENDOR="${IMAGE_VENDOR}" \
    BASE_IMAGE_NAME="${BASE_IMAGE_NAME}" \
    SHA_HEAD_SHORT="${SHA_HEAD_SHORT}" \
    UBLUE_IMAGE_TAG="${UBLUE_IMAGE_TAG}" \
    /ctx/build/08-branding.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/build/09-cleanup.sh

# 10-selinux-workarounds ships SELinux policy modules that won't be upstreamed
# immediately (e.g. tuned-ppd-logging for RHEL-130547).
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/build/10-selinux-workarounds.sh

###############################################################################
# FINALIZE
###############################################################################
RUN bootc container lint
