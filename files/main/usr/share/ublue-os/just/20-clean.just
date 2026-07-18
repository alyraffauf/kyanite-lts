# vim: set ft=make :

# Clean up old and unused podman images, volumes, flatpak packages
clean-system:
    #!/usr/bin/bash
    podman image prune -af
    flatpak uninstall --unused
    if command -v brew &>/dev/null; then
        brew autoremove
        brew cleanup
    fi
