# bazzite-nitro

A personal [Bazzite](https://bazzite.gg) image for an Acer Nitro ANV16S laptop. It is based on `bazzite-nvidia-open:stable` and adds a few things on top.

## What's different from Bazzite

- **Brave Origin** is installed as a system package. The Brave repo ships disabled, so updates arrive with each new image.
- **`ujust nitro-setup`** restores personal apps after a fresh install:
  - Flatpaks in user scope. System Flatpaks that Bazzite does not ship move to user scope.
  - Homebrew packages
  - the Claude CLI

  The lists live in `system_files/usr/share/bazzite-nitro/`. The recipe only adds what is missing, so it is safe to run again.
- **`acpi_backlight=native`** kernel argument, so the display brightness can be changed. It comes from `/usr/lib/bootc/kargs.d/`.

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
3. Boot from the stick and install. The installed system tracks `ghcr.io/<owner>/bazzite-nitro:latest`.

After the first login, run `ujust nitro-setup`.

## Verify the signature

Images are signed with cosign. Verify with the key from this repository:

```bash
cosign verify --key cosign.pub ghcr.io/<owner>/bazzite-nitro:latest
```

## Updates and rollback

CI builds a new image every day and on every push to `main`. To update by hand:

```bash
sudo bootc upgrade && systemctl reboot
```

Kernel arguments from the image are only applied by `bootc`, not by `rpm-ostree`. With layered packages, the automatic update (`uupd`) falls back to `rpm-ostree`, and new kernel arguments are not applied.

To go back to the previous image:

```bash
sudo bootc rollback && systemctl reboot
```

## Building locally

Needs `just` and `podman`.

```bash
just build                      # container image
just build-iso                  # installer ISO from the built image, needs sudo
just lint                       # shellcheck
bash tests/nitro-setup.test.sh  # tests for nitro-setup
```
