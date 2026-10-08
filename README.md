# bazzite-nitro

An opinionated [Bazzite](https://bazzite.gg) image, developed on an Acer Nitro ANV16S laptop. It is based on `bazzite-nvidia-open:stable` and adds a few things on top. Like the base image, it needs an NVIDIA GPU of the GTX 16 or RTX series or newer.

## What's different from Bazzite

- **Brave Origin** is installed as a system package. The Brave repo ships disabled, so updates arrive with each new image.
- **`ujust nitro-setup`** installs the chosen apps after a fresh install:
  - Flatpaks in user scope. System Flatpaks that Bazzite does not ship move to user scope.
  - Homebrew packages
  - the Claude CLI

  The lists live in `system_files/usr/share/bazzite-nitro/`. The recipe only adds what is missing, so it is safe to run again.
- **`acpi_backlight=native`** kernel argument, so the display brightness can be changed. It comes from `/usr/lib/bootc/kargs.d/`.
- **Keyboard backlight** is set at boot. The ENE controller (`0CF2:5130`) starts dark and no kernel driver sets it. A udev rule starts `bazzite-nitro-kbd-backlight@.service`, which sets a static blue (`00a0ff`) at 10 % on all four zones. To change it, run `sudo systemctl edit bazzite-nitro-kbd-backlight@.service` and add:

  ```ini
  [Service]
  Environment=BRIGHTNESS=30 COLOR=ffffff
  ```

  The firmware still turns the backlight off after about 30 seconds without a key press.

Everything else is plain Bazzite.

## Install

`<owner>` is the GitHub owner of this repository.

### From an existing Bazzite install

```bash
sudo bootc switch ghcr.io/<owner>/bazzite-nitro:latest
systemctl reboot
```

### Fresh install

1. Run the **Build disk images** workflow in GitHub Actions.
2. Download the `anaconda-iso` artifact and write `install.iso` to a USB stick.
3. Boot from the stick and install. The installed system tracks `ghcr.io/<owner>/bazzite-nitro:latest` with signature verification enabled.

After the first login, run `ujust nitro-setup`.

## Verify the signature

Images are signed with cosign. Verify with the key from this repository:

```bash
cosign verify --key cosign.pub ghcr.io/<owner>/bazzite-nitro:latest
```

### Enforce the signature on the installed system

The image ships the public key and a `policy.json` entry for its own repository. Installs from the ISO enforce signatures from the start. A system that was installed earlier, or moved to the image with a plain `bootc switch`, registers it as `ostree-unverified-registry`, so `bootc upgrade` does not check signatures there. To enforce them, switch once from a booted image that already ships the policy:

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/<owner>/bazzite-nitro:latest
systemctl reboot
```

`rpm-ostree status` then shows the origin as `ostree-image-signed:docker://…`, and `bootc upgrade` rejects images that are not signed with this key. To return to unverified updates, run `sudo bootc switch` without the flag.

## Updates and rollback

CI builds a new image on every push to `main`. Every day it also checks for a new Bazzite base image, an unbuilt commit or a missing signature, and builds only then. To build without a change, run the **Build container image** workflow by hand. To update by hand:

```bash
sudo bootc upgrade && systemctl reboot
```

Kernel arguments from the image are only applied by `bootc`, not by `rpm-ostree`. With layered packages, the automatic update (`uupd`) falls back to `rpm-ostree`, and new kernel arguments are not applied.

To go back to the previous image:

```bash
sudo bootc rollback && systemctl reboot
```

The labels `org.opencontainers.image.base.digest` and `org.opencontainers.image.revision` name the base image digest and the commit of an image:

```bash
skopeo inspect --no-tags docker://ghcr.io/<owner>/bazzite-nitro:latest | jq .Labels
```

## Building locally

Needs `just`, `podman`, `skopeo` and `jq`.

```bash
just build                      # container image
just build-iso                  # installer ISO from the built image, needs sudo
just lint                       # shellcheck
bash tests/nitro-setup.test.sh  # tests for nitro-setup
bash tests/needs-build.test.sh  # tests for the base image check
```
