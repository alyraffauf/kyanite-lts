#!/usr/bin/env bash

set -euo pipefail

echo "::group:: Validate package manifest"

jq empty /ctx/packages.json

echo "::endgroup::"
echo "::group:: Build package lists"

INCLUDED_PACKAGES=()
EXCLUDED_PACKAGES=()
PACKAGE_GROUPS=()
IFS='-' read -ra FLAVOR_PARTS <<<"${IMAGE_FLAVOR}"
VARIANTS=(main)
for variant in "${FLAVOR_PARTS[@]}"; do
    [[ ${variant} == "main" ]] || VARIANTS+=("${variant}")
done

for variant in "${VARIANTS[@]}"; do
    if ! jq -e ".variants.${variant}" /ctx/packages.json >/dev/null 2>&1; then
        continue
    fi

    echo "Processing packages for variant: ${variant}"
    readarray -t VARIANT_PACKAGES < <(jq -r ".variants.${variant}.include // [] | sort | unique[]" /ctx/packages.json)
    readarray -t VARIANT_EXCLUDED < <(jq -r ".variants.${variant}.exclude // [] | sort | unique[]" /ctx/packages.json)
    readarray -t VARIANT_GROUPS < <(jq -r ".variants.${variant}.groups // [] | sort | unique[]" /ctx/packages.json)
    INCLUDED_PACKAGES+=("${VARIANT_PACKAGES[@]}")
    EXCLUDED_PACKAGES+=("${VARIANT_EXCLUDED[@]}")
    PACKAGE_GROUPS+=("${VARIANT_GROUPS[@]}")
done

echo "::endgroup::"
dnf -y remove setroubleshoot || true
echo "::group:: Install CentOS workstation groups"

if [[ ${#PACKAGE_GROUPS[@]} -gt 0 ]]; then
    dnf -y group install --nobest \
        --exclude='kernel-debug*' \
        --exclude='cockpit*' \
        "${PACKAGE_GROUPS[@]}"
fi

echo "::endgroup::"
echo "::group:: Install Kyanite LTS packages"

if [[ ${#INCLUDED_PACKAGES[@]} -gt 0 ]]; then
    dnf -y install \
        --enablerepo=epel-multimedia \
        --exclude='kernel-debug*' \
        "${INCLUDED_PACKAGES[@]}"
fi

echo "::endgroup::"
echo "::group:: Remove excluded packages"

INSTALLED_EXCLUDED=()
for package in "${EXCLUDED_PACKAGES[@]}"; do
    if rpm -q "${package}" >/dev/null 2>&1; then
        INSTALLED_EXCLUDED+=("${package}")
    fi
done

if [[ ${#INSTALLED_EXCLUDED[@]} -gt 0 ]]; then
    dnf -y remove "${INSTALLED_EXCLUDED[@]}"
fi

echo "::endgroup::"
echo "::group:: Configure Flatpak and package repositories"

mkdir -p /etc/flatpak/remotes.d
curl --retry 3 --fail --location \
    https://dl.flathub.org/repo/flathub.flatpakrepo \
    --output /etc/flatpak/remotes.d/flathub.flatpakrepo

dnf config-manager --set-disabled epel-multimedia baseos-compose appstream-compose

echo "::endgroup::"
echo "CentOS package installation complete!"
