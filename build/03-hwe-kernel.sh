#!/usr/bin/env bash

set -euo pipefail

if [[ "${IMAGE_FLAVOR}" != *"hwe"* ]]; then
    echo "Non-HWE flavor (${IMAGE_FLAVOR}); skipping HWE kernel swap."
    exit 0
fi

# HWE kernel images provide a Fedora CoreOS kernel that is already signed for
# Secure Boot, plus matching akmods built by Universal Blue.
HWE_AKMODS_FLAVOR="${HWE_AKMODS_FLAVOR:-coreos-stable}"
HWE_FEDORA_VERSION="${HWE_FEDORA_VERSION:-43}"
HWE_AKMODS_IMAGE="${HWE_AKMODS_IMAGE:-ghcr.io/ublue-os/akmods}"
HWE_CERT_URL="${HWE_CERT_URL:-https://github.com/ublue-os/akmods/raw/main/certs/public_key.der}"

echo "::group:: Remove CentOS kernel packages"
# Record existing kernel module dirs so leftovers can be removed after the
# swap. rpm --erase only removes files owned by the kernel packages; files
# generated later (depmod, kernel-install hooks) keep the old directory
# around, and 09-cleanup.sh expects exactly one kernel in /usr/lib/modules.
mapfile -t OLD_KERNEL_DIRS < <(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
PKGS=(
    kernel
    kernel-core
    kernel-modules
    kernel-modules-core
    kernel-modules-extra
    kernel-uki-virt
)
for pkg in "${PKGS[@]}"; do
    rpm --erase "${pkg}" --nodeps || true
done
echo "::endgroup::"

echo "::group:: Install HWE kernel from mounted akmods cache"
find /tmp/kernel-rpms

CACHED_VERSION=$(find /tmp/kernel-rpms -maxdepth 1 -name 'kernel-[0-9]*.rpm' -printf '%f\n' | head -1 | sed -E 's/^kernel-//;s/\.rpm$//')
if [[ -z "${CACHED_VERSION}" ]]; then
    echo "ERROR: Could not detect kernel version from /tmp/kernel-rpms"
    ls -la /tmp/kernel-rpms/
    exit 1
fi

echo "Detected HWE kernel version: ${CACHED_VERSION}"

INSTALL_PKGS=(
    kernel
    kernel-core
    kernel-modules
    kernel-modules-core
    kernel-modules-extra
    kernel-uki-virt
    kernel-devel
    kernel-devel-matched
)

RPM_NAMES=()
for pkg in "${INSTALL_PKGS[@]}"; do
    RPM_NAMES+=("/tmp/kernel-rpms/${pkg}-${CACHED_VERSION}.rpm")
done

dnf -y install "${RPM_NAMES[@]}"

# Remove stale CentOS kernel module dirs left behind by rpm --erase so that
# exactly one kernel (the HWE kernel) remains in /usr/lib/modules.
for dir in "${OLD_KERNEL_DIRS[@]}"; do
    if [[ -d "/usr/lib/modules/${dir}" ]]; then
        echo "Removing stale CentOS kernel module dir: ${dir}"
        rm -rf "/usr/lib/modules/${dir}"
    fi
done
echo "::endgroup::"

echo "::group:: Install common akmods for HWE kernel"
KERNEL_VERSION=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')
echo "Detected installed kernel version: ${KERNEL_VERSION}"

COMMON_AKMODS_DIR="/run/common-akmods"
mkdir -p "${COMMON_AKMODS_DIR}"

echo "Downloading common akmods for kernel ${KERNEL_VERSION}..."
skopeo copy --retry-times 3 \
    "docker://${HWE_AKMODS_IMAGE}:${HWE_AKMODS_FLAVOR}-${HWE_FEDORA_VERSION}-${KERNEL_VERSION}" \
    "dir:${COMMON_AKMODS_DIR}/akmods-container"

AKMODS_TARGZ=$(jq -r '.layers[].digest' <"${COMMON_AKMODS_DIR}/akmods-container/manifest.json" | cut -d : -f 2)
tar -xzf "${COMMON_AKMODS_DIR}/akmods-container/${AKMODS_TARGZ}" -C "${COMMON_AKMODS_DIR}"

if [[ -d "${COMMON_AKMODS_DIR}/rpms" ]]; then
    echo "Available common akmods packages:"
    ls -lh "${COMMON_AKMODS_DIR}/rpms/" || true
    ls -lh "${COMMON_AKMODS_DIR}/rpms/kmods/" || true

    echo "Installing common akmods with dependencies..."
    dnf -y install \
        "${COMMON_AKMODS_DIR}/rpms/"*xone*.rpm \
        "${COMMON_AKMODS_DIR}/rpms/"*openrazer*.rpm \
        "${COMMON_AKMODS_DIR}/rpms/"*framework-laptop*.rpm \
        "${COMMON_AKMODS_DIR}/rpms/"*v4l2loopback*.rpm \
        "${COMMON_AKMODS_DIR}/rpms/kmods/"*xone*.rpm \
        "${COMMON_AKMODS_DIR}/rpms/kmods/"*openrazer*.rpm \
        "${COMMON_AKMODS_DIR}/rpms/kmods/"*framework-laptop*.rpm \
        "${COMMON_AKMODS_DIR}/rpms/kmods/"*v4l2loopback*.rpm \
        || echo "Warning: Some common akmods failed to install (non-critical)"
fi

rpm -qa | grep -E 'xone|openrazer|framework|v4l2loopback' || true
rm -rf "${COMMON_AKMODS_DIR}"
echo "::endgroup::"

echo "::group:: Add akmods Secure Boot key"
mkdir -p /etc/pki/akmods/certs
curl --retry 15 -Lo /etc/pki/akmods/certs/akmods-ublue.der "${HWE_CERT_URL}"
echo "::endgroup::"

echo "::group:: Version-lock HWE kernel packages"
dnf versionlock add \
    kernel \
    kernel-core \
    kernel-modules \
    kernel-modules-core \
    kernel-modules-extra \
    kernel-uki-virt \
    kernel-devel \
    kernel-devel-matched
echo "::endgroup::"

echo "HWE kernel installation complete!"
