# vim: set ft=make :

alias upgrade := update

# Update system, flatpaks, and containers all at once
update:
    #!/usr/bin/bash
    echo "Updating system (bootc)..."
    sudo bootc upgrade
    echo "Updating flatpaks..."
    flatpak update -y
    echo "Updating distrobox containers..."
    distrobox upgrade --all 2>/dev/null || true
    echo "Update complete."

alias changelog := changelogs

# Show the changelog
changelogs:
    #!/usr/bin/bash
    echo "Distrobox container changelogs:"
    distrobox upgrade --all --dry-run 2>/dev/null || echo "   (no containers found or distrobox unavailable)"
    echo ""
    echo "For image release notes see: https://github.com/alyraffauf/kyanite-lts/releases"

# Update device firmware
[no-exit-message]
update-firmware:
    fwupdmgr refresh --force
    fwupdmgr get-updates
    fwupdmgr update

alias auto-update := toggle-updates

# Turn automatic updates on or off
toggle-updates:
    #!/usr/bin/bash
    if systemctl -q is-enabled bootc-fetch-apply-updates.timer 2>/dev/null; then
        CURRENT_STATE="Enabled"
    else
        CURRENT_STATE="Disabled"
    fi
    echo "Automatic updates are currently: ${CURRENT_STATE}"
    echo "Enable or Disable automatic updates?"
    OPTION=$(gum choose Enable Disable)
    if [ "${OPTION}" == "Enable" ]; then
        sudo systemctl enable --now bootc-fetch-apply-updates.timer
        echo "Automatic updates enabled."
    elif [ "${OPTION}" == "Disable" ]; then
        sudo systemctl disable --now bootc-fetch-apply-updates.timer
        echo "Automatic updates disabled."
    fi
