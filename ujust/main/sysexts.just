# vim: set ft=make :
#######################
### sysexts.just
#######################

# Install a CentOS 10 sysext and merge it into /usr.
[group('Extensions')]
install-sysext NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    BASE="https://github.com/alyraffauf/kyanite-sysexts/releases/download/sysext-lts-{{ NAME }}"
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT

    curl -fSL "$BASE/SHA256SUMS" -o "$TMP/SHA256SUMS"
    curl -fSL "$BASE/{{ NAME }}.transfer" -o "$TMP/{{ NAME }}.transfer"
    (cd "$TMP" && sha256sum -c --ignore-missing SHA256SUMS)

    sudo install -D -m 0644 "$TMP/{{ NAME }}.transfer" "/etc/sysupdate.d/{{ NAME }}.transfer"
    sudo systemd-tmpfiles --create kyanite-sysexts.conf
    sudo install -d -m 0755 "/var/lib/sysupdate/{{ NAME }}-lts"
    sudo systemctl enable --now systemd-sysupdate.timer
    sudo /usr/lib/systemd/systemd-sysupdate update
    sudo /usr/bin/systemd-sysext refresh
    sudo systemd-sysusers
    sudo udevadm control --reload && sudo udevadm trigger
    echo "{{ NAME }} LTS sysext installed and merged."

# Pull newer versions of all installed LTS sysexts.
[group('Extensions')]
update-sysexts:
    sudo /usr/lib/systemd/systemd-sysupdate update
    sudo /usr/bin/systemd-sysext refresh
    sudo udevadm control --reload && sudo udevadm trigger

# Remove an installed LTS sysext.
[group('Extensions')]
remove-sysext NAME:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo rm -f "/var/lib/extensions/{{ NAME }}.raw" \
              "/etc/sysupdate.d/{{ NAME }}.transfer"
    sudo rm -rf "/var/lib/sysupdate/{{ NAME }}-lts"
    sudo /usr/bin/systemd-sysext refresh
    sudo udevadm control --reload && sudo udevadm trigger
    echo "{{ NAME }} LTS sysext removed."
