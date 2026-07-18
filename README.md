# Kyanite LTS

A long-term-support counterpart to [Kyanite](https://github.com/alyraffauf/kyanite), built on CentOS Stream 10 with KDE Plasma.

Kyanite LTS keeps Kyanite's desktop defaults, Flatpak-first application model, Homebrew integration, local-LLM Quadlets, and custom `ujust` recipes while following the slower CentOS and EPEL package lifecycle.

## Highlights

- KDE Plasma 6 from EPEL with a Wayland SDDM session.
- Firefox from Mozilla's official Flatpak and Bazaar in place of Discover.
- Flathub configured for first-boot application installation.
- Multimedia codecs from Negativo17's EL multimedia repository.
- Fish, Homebrew, Podman, development tools, and hardware utilities included.
- PipeWire filter chains for supported laptop speaker configurations.
- Ollama and Open WebUI Quadlets for local LLM workloads.
- Automatic OS updates through bootc's native update timer.

## Install

Kyanite LTS and Fedora-based Kyanite are separate operating-system families. Reinstall when moving between them; an in-place Fedora-to-CentOS rebase is not supported.

From an existing compatible CentOS bootc system:

```bash
sudo bootc switch ghcr.io/alyraffauf/kyanite-lts:stable
sudo systemctl reboot
```

After the first boot, enable signature enforcement for subsequent updates:

```bash
sudo bootc switch ghcr.io/alyraffauf/kyanite-lts:stable --enforce-container-sigpolicy
```

Run `ujust --list` to see the included system and application recipes.

## Local LLMs

```bash
ujust enable-ollama          # CPU or supported container GPU passthrough
ujust enable-ollama-rocm     # AMD GPU through the Ollama ROCm image
ujust enable-ollama-vulkan   # AMD GPU through Vulkan
ujust enable-open-webui
```

The services share a Podman network and store persistent data in named volumes. Templates live under `/usr/share/kyanite/quadlets/`.

## Current Differences

The first Kyanite LTS release intentionally omits components without maintained EL10 builds:

- Ghostty is replaced by Konsole.
- Fedora-built `kyanite-sysexts` are unavailable and must not be installed on Kyanite LTS.
- Several fcitx5 language modules, dynamic Plasma wallpapers, and a few hardware utilities are not yet packaged in EPEL 10.

## Configuration

- `packages.json` declares package groups and RPM inclusions/exclusions.
- `services.json` declares enabled system and user services.
- `files/<variant>/` contains system overlays.
- `brew/` contains Homebrew bundles.
- `flatpaks/` contains first-boot Flatpak manifests.
- `ujust/` contains custom user recipes.

## Build

Requires Podman and Just:

```bash
just build           # build the kyanite-lts container
just build-qcow2     # build a qcow2 for VM testing
just build-iso       # ~10 GB, takes 30+ min (local only)
just run-vm          # boot the qcow2 in qemu
```

The shared desktop assets come from the digest-pinned
[`kyanite-common`](https://github.com/alyraffauf/kyanite-common) OCI layer.
For local common-layer development, build it first and pass
`COMMON_IMAGE=localhost/kyanite-common:stable`.

Output lands in `output/`.

## Upstream Sync

This repository shares history with Kyanite and keeps it as the `upstream` Git remote. Reusable changes can be merged from `upstream/main`; CentOS-specific build, package, service, signing, and documentation files should be resolved deliberately rather than overwritten.

## Security

Published images are signed with the dedicated key in [`cosign.pub`](cosign.pub):

```bash
cosign verify \
  --key https://raw.githubusercontent.com/alyraffauf/kyanite-lts/main/cosign.pub \
  ghcr.io/alyraffauf/kyanite-lts:stable
```

The private signing key and password are stored only as encrypted GitHub Actions secrets. Local signing material belongs under the gitignored `.secrets/` directory.

## License

Apache 2.0. See [LICENSE.md](LICENSE.md). Kyanite LTS incorporates CentOS Stream, EPEL, KDE Plasma, and bootc under their respective licenses.
