#!/usr/bin/env bash

set -euo pipefail

echo "::group:: Apply Kyanite LTS branding"

# shellcheck source=/dev/null
source /usr/lib/os-release

IMAGE_PRETTY_NAME="Kyanite LTS"
IMAGE_VENDOR="${IMAGE_VENDOR:-alyraffauf}"
IMAGE_NAME="${IMAGE_NAME:-kyanite-lts}"
IMAGE_FLAVOR="${IMAGE_FLAVOR:-main}"
IMAGE_TAG="${UBLUE_IMAGE_TAG:-stable}"
BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-centos-bootc}"
CENTOS_VERSION="${VERSION_ID%%.*}"
VERSION="${VERSION_ID}"
HOME_URL="https://github.com/${IMAGE_VENDOR}/kyanite-lts"
DOCUMENTATION_URL="${HOME_URL}/blob/main/README.md"
SUPPORT_URL="${HOME_URL}/issues/"
CODE_NAME="Silicate"

mkdir -p /usr/share/ublue-os
IMAGE_INFO="/usr/share/ublue-os/image-info.json"
IMAGE_REF="ostree-image-signed:docker://ghcr.io/${IMAGE_VENDOR}/${IMAGE_NAME}"

cat >"${IMAGE_INFO}" <<EOF
{
  "image-name": "${IMAGE_NAME}",
  "image-flavor": "${IMAGE_FLAVOR}",
  "image-vendor": "${IMAGE_VENDOR}",
  "image-ref": "${IMAGE_REF}",
  "image-tag": "${IMAGE_TAG}",
  "base-image-name": "${BASE_IMAGE_NAME}",
  "centos-version": "${CENTOS_VERSION}"
}
EOF

sed -i -f - /usr/lib/os-release <<EOF
s|^NAME=.*|NAME="${IMAGE_PRETTY_NAME}"|
s|^VARIANT_ID=.*|VARIANT_ID=${IMAGE_NAME}|
s|^PRETTY_NAME=.*|PRETTY_NAME="${IMAGE_PRETTY_NAME} (CentOS Stream ${VERSION})"|
s|^HOME_URL=.*|HOME_URL="${HOME_URL}"|
s|^BUG_REPORT_URL=.*|BUG_REPORT_URL="${SUPPORT_URL}"|
s|^CPE_NAME="cpe:/o:centos:centos|CPE_NAME="cpe:/o:alyraffauf:kyanite-lts|
/^DOCUMENTATION_URL=/d
/^SUPPORT_URL=/d
/^DEFAULT_HOSTNAME=/d
/^BUILD_ID=/d
/^IMAGE_ID=/d
/^IMAGE_VERSION=/d
/^VERSION_CODENAME=/d
EOF

cat >>/usr/lib/os-release <<EOF
DOCUMENTATION_URL="${DOCUMENTATION_URL}"
SUPPORT_URL="${SUPPORT_URL}"
DEFAULT_HOSTNAME="kyanite-lts"
VERSION_CODENAME="${CODE_NAME}"
BUILD_ID="${SHA_HEAD_SHORT:-unknown}"
IMAGE_ID="${IMAGE_NAME}"
IMAGE_VERSION="${VERSION}"
EOF

KDE_ABOUT_RC="/usr/share/kde-settings/kde-profile/default/xdg/kcm-about-distrorc"
if [[ -f ${KDE_ABOUT_RC} ]]; then
    if [[ ${IMAGE_FLAVOR} == "main" ]]; then
        echo "Variant=LTS" >>"${KDE_ABOUT_RC}"
    else
        IFS='-' read -ra FLAVOR_PARTS <<<"${IMAGE_FLAVOR}"
        mapfile -t SORTED_FLAVORS < <(printf '%s\n' "${FLAVOR_PARTS[@]}" | sort)
        VARIANT_STRING=$(printf '%s\n' "${SORTED_FLAVORS[@]}" | tr '[:lower:]' '[:upper:]' | paste -sd '+')
        echo "Variant=LTS+${VARIANT_STRING}" >>"${KDE_ABOUT_RC}"
    fi
fi

echo "::endgroup::"
