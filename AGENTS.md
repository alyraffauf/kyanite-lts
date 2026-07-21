# Agent Instructions for Kyanite LTS

Kyanite LTS is a CentOS Stream 10 bootc image with KDE Plasma from EPEL. It shares Git history with Fedora-based Kyanite but is released independently.

## Pre-Commit Checklist

1. Use Conventional Commits: `<type>(<scope>): <description>`.
2. Run shellcheck on all `.sh` files.
3. Run `jq empty packages.json services.json` and `just --list`.
4. Run `pre-commit run --all-files` when available.
5. Always ask before committing.

Valid types: `feat`, `fix`, `docs`, `chore`, `build`, `ci`, `refactor`, `test`.

## Critical Rules

1. Use `dnf` in build scripts; CentOS Stream 10 does not guarantee `dnf5`.
2. Enable CRB before installing EPEL.
3. Add external repositories disabled and enable them only for the required transaction.
4. Do not use Fedora RPMs or Fedora-only COPR chroots in the image.
   Exception: `main-hwe` and other HWE variants may consume the Fedora CoreOS
   kernel from the Universal Blue akmods cache for Secure Boot-capable hardware
   enablement; non-HWE variants must remain on the CentOS Stream kernel.
5. Never install host RPMs from `ujust`; the root filesystem is image-managed.
6. Declare packages and groups in `packages.json`, not build scripts.
7. Declare services in `services.json`, not build scripts.
8. Preserve `ID=centos` and `VERSION_ID=10` in `/usr/lib/os-release`.
9. Do not install Fedora-built `kyanite-sysexts`; use the CentOS 10 LTS track.
10. Validate ISO builds by booting the generated installer in QEMU and completing a guided installation before considering the installer path supported.
11. Shared distro-neutral assets come from the digest-pinned `kyanite-common` OCI layer; keep CentOS/EPEL-specific overrides in this repository.

## Build Order

1. `00-centos-repositories.sh`: matching bootc compose repositories, CRB, EPEL, and multimedia repository.
2. `01-stage-brewfiles.sh`: runtime Homebrew manifests.
3. `02-centos-packages.sh`: workstation groups and package manifest.
4. `03-hwe-kernel.sh`: HWE-only kernel swap (Fedora CoreOS kernel + common akmods).
5. `05-copy-files.sh`: system files, `ujust` recipes, and Flatpak manifests.
6. `06-systemd.sh`: system and user services plus graphical target.
7. `07-homebrew.sh`: Homebrew system files and timers.
8. `08-branding.sh`: Kyanite LTS release and KDE identity.
9. `09-cleanup.sh`: desktop integration and bootc cleanup.
10. `10-selinux-workarounds.sh`: compile and install SELinux policy modules from `files/main/usr/share/selinux/packages/`.

## Configuration

- Base packages: `packages.json` under `variants.main`.
- Variant packages: `packages.json` under `variants.<name>`.
- Services: `services.json` under the matching variant.
- System overlays: `files/<variant>/`.
- Homebrew bundles: `brew/<variant>/`.
- Flatpak preinstalls: `flatpaks/<variant>.preinstall`.
- User commands: `ujust/<variant>/*.just`.

`IMAGE_FLAVOR=main` applies the main layer once. Hyphen-separated flavors compose additional exact variant blocks.
Use `IMAGE_FLAVOR=main-hwe` to apply the HWE kernel and common akmods on top of the main layer.

## Validation

```bash
jq empty packages.json services.json
shellcheck build/*.sh files/main/usr/bin/ujust files/main/usr/lib/ujust/ujust.sh
just --list
just build
```

The final image must pass `bootc container lint`. Before release, also build and boot a QCOW2 image.

## Upstream Relationship

The `upstream` remote points to `alyraffauf/kyanite`. Merge reusable changes from `upstream/main`, but preserve deliberate divergence in `Containerfile`, `build/`, `packages.json`, `services.json`, signing policy, CI metadata, and documentation.
