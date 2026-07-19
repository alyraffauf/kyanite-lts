# Enroll the Universal Blue akmods Secure Boot key
[group('HWE')]
enroll-ublue-mok:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ ! -f /etc/pki/akmods/certs/akmods-ublue.der ]]; then
        echo "The Universal Blue akmods certificate is missing from this image."
        exit 1
    fi
    echo "Enrolling the Universal Blue akmods Machine Owner Key (MOK)..."
    echo "You will be prompted to set a one-time password and reboot into the MOK manager."
    sudo mokutil --import /etc/pki/akmods/certs/akmods-ublue.der
    echo "Reboot now and follow the MOK manager prompts to complete enrollment."

# Show HWE kernel information
[group('HWE')]
show-hwe-info:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "HWE kernel: $(uname -r)"
    echo "Secure Boot: $(mokutil --sb-state 2>/dev/null || echo 'unknown')"
    echo "MOK enrollment:"
    mokutil --list-enrolled 2>/dev/null | grep -E 'Universal Blue|ublue' || echo '  Universal Blue key not enrolled'
