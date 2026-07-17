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
5. Never install host RPMs from `ujust`; the root filesystem is image-managed.
6. Declare packages and groups in `packages.json`, not build scripts.
7. Declare services in `services.json`, not build scripts.
8. Preserve `ID=centos` and `VERSION_ID=10` in `/usr/lib/os-release`.
9. Do not enable Fedora-built `kyanite-sysexts` on this image.
10. Do not restore ISO recipes without a tested CentOS bootc installer path.

## Build Order

1. `00-centos-repositories.sh`: matching bootc compose repositories, CRB, EPEL, and multimedia repository.
2. `01-stage-brewfiles.sh`: runtime Homebrew manifests.
3. `02-centos-packages.sh`: workstation groups and package manifest.
4. `05-copy-files.sh`: system files, `ujust` recipes, and Flatpak manifests.
5. `06-systemd.sh`: system and user services plus graphical target.
6. `07-homebrew.sh`: Homebrew system files and timers.
7. `08-branding.sh`: Kyanite LTS release and KDE identity.
8. `09-cleanup.sh`: desktop integration and bootc cleanup.

## Configuration

- Base packages: `packages.json` under `variants.main`.
- Variant packages: `packages.json` under `variants.<name>`.
- Services: `services.json` under the matching variant.
- System overlays: `files/<variant>/`.
- Homebrew bundles: `brew/<variant>/`.
- Flatpak preinstalls: `flatpaks/<variant>.preinstall`.
- User commands: `ujust/<variant>/*.just`.

`IMAGE_FLAVOR=main` applies the main layer once. Hyphen-separated flavors compose additional exact variant blocks.

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
