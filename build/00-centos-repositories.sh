#!/usr/bin/env bash

set -euo pipefail

echo "::group:: Configure CentOS Stream repositories"

# shellcheck source=/dev/null
source /usr/lib/os-release
MAJOR_VERSION="${VERSION_ID%%.*}"
COMPOSE_REPO="/etc/yum.repos.d/centos-bootc-compose.repo"

# Keep the compose used by the bootc base available for strict NVR dependencies.
curl --retry 3 --fail --location \
    "https://gitlab.com/redhat/centos-stream/containers/bootc/-/raw/c${MAJOR_VERSION}s/cs.repo" \
    --output "${COMPOSE_REPO}"
sed -i \
    -e 's/^\[baseos\]/[baseos-compose]/' \
    -e 's/^\[appstream\]/[appstream-compose]/' \
    -e 's/^name=CentOS Stream - BaseOS/name=CentOS Stream - BaseOS - Compose/' \
    -e 's/^name=CentOS Stream - AppStream/name=CentOS Stream - AppStream - Compose/' \
    "${COMPOSE_REPO}"

dnf -y remove --setopt=tsflags=noscripts subscription-manager || true
dnf -y install dnf-plugins-core
dnf config-manager --set-enabled crb
dnf -y install \
    "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${MAJOR_VERSION}.noarch.rpm"

dnf config-manager --add-repo "https://negativo17.org/repos/epel-multimedia.repo"
dnf config-manager --set-disabled epel-multimedia

echo "::endgroup::"
