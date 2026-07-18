#!/usr/bin/env bash

set -eoux pipefail

###############################################################################
# Final Cleanup and Configuration
###############################################################################
# This script performs final cleanup tasks and system tweaks.
###############################################################################

echo "::group:: Hide Desktop Files"

# Hide Desktop Files. Hidden removes mime associations
for file in htop nvtop; do
    if [[ -f "/usr/share/applications/${file}.desktop" ]]; then
        desktop-file-edit --set-key=Hidden --set-value=true /usr/share/applications/${file}.desktop
    fi
done

echo "::endgroup::"

echo "::group:: Configure Discover"

# Hide Discover entries by renaming them (allows for easy re-enabling)
discover_apps=(
    "org.kde.discover.desktop"
    "org.kde.discover.flatpak.desktop"
    "org.kde.discover.notifier.desktop"
    "org.kde.discover.urlhandler.desktop"
)

for app in "${discover_apps[@]}"; do
    if [ -f "/usr/share/applications/${app}" ]; then
        mv "/usr/share/applications/${app}" "/usr/share/applications/${app}.disabled"
    fi
done

# These notifications are useless and confusing
rm -f /etc/xdg/autostart/org.kde.discover.notifier.desktop

# Use Bazaar for Flatpak refs
echo "application/vnd.flatpak.ref=io.github.kolunmi.Bazaar.desktop" >>/usr/share/applications/mimeapps.list

echo "::endgroup::"

echo "::group:: Regenerate initramfs"

readarray -t KERNEL_VERSIONS < <(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
if [[ ${#KERNEL_VERSIONS[@]} -ne 1 ]]; then
    echo "Expected exactly one installed kernel, found ${#KERNEL_VERSIONS[@]}" >&2
    exit 1
fi

KERNEL_VERSION="${KERNEL_VERSIONS[0]}"
dracut \
    --no-hostonly \
    --kver "${KERNEL_VERSION}" \
    --reproducible \
    --tmpdir /boot \
    --zstd \
    --add ostree \
    --force "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"

echo "::endgroup::"

echo "::group:: Root filesystem directories"

mkdir -p /nix
chown root:root /nix
chmod 755 /nix

echo "::endgroup::"

echo "::group:: Make /usr/local persistent"

# bootc's CentOS base keeps /usr/local in the immutable root, while tools such
# as Determinate Nixd install there at runtime. Match Fedora Atomic's layout so
# /usr/local writes persist under /var.
if [[ ! -L /usr/local ]]; then
    local_dir=/usr/local
    mkdir -p /var/usrlocal
    cp -a "${local_dir}/." /var/usrlocal/
    rm -rf -- "${local_dir:?}"/* "${local_dir:?}"/.[!.]* "${local_dir:?}"/..?*
    rmdir "${local_dir}"
    ln -s ../var/usrlocal /usr/local
fi

echo "::endgroup::"

echo "::group:: Fix bootc lint issues"

# Fix /var/run symlink if it was broken by package installation (e.g., Steam)
if [[ -d /var/run ]] && [[ ! -L /var/run ]]; then
    echo "Fixing /var/run symlink..."
    rm -rf /var/run
    ln -sf /run /var/run
fi

# Clean up /var and /run content created during build
# These directories are declared in tmpfiles.d and will be recreated at boot
echo "Cleaning up temporary build artifacts..."
rm -rf /var/lib/dnf
rm -rf /var/lib/freeipmi
find /run -mindepth 1 -maxdepth 1 \
    ! -name secrets \
    ! -name .containerenv \
    -exec rm -rf {} +
rm -rf /tmp/*

echo "::endgroup::"

echo "Final cleanup and configuration complete!"
