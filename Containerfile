###############################################################################
# BUILD ARGUMENTS
###############################################################################
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-centos-bootc}"
# Static value enables Renovate to detect and update the base image
ARG BASE_IMAGE="quay.io/centos-bootc/centos-bootc:c10s"
ARG BREW_IMAGE="ghcr.io/ublue-os/brew:latest"
# SHA pinning enables Renovate to automatically update dependencies
# See: https://docs.renovatebot.com/docker/#digest-pinning

# Base Image @ centos-bootc/centos-bootc (CentOS Stream 10)
ARG BASE_IMAGE_SHA="sha256:95397e8d1f672245159fdd4986130ec3999a91f3c6a5a788ce1d5ca28567e012"

# Brew Image
ARG BREW_IMAGE_SHA="sha256:c6f6775db732b58bf02e27ca89b4390c3b72db27aedcea62d15c09960be7a0cb"

###############################################################################
# IMPORT STAGES
###############################################################################
FROM ${BREW_IMAGE}@${BREW_IMAGE_SHA} AS brew

FROM scratch AS ctx
COPY /build /build
COPY /files /files
COPY /brew /brew
COPY /flatpaks /flatpaks
COPY /ujust /ujust
COPY /packages.json /packages.json
COPY /services.json /services.json

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
