#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

### Brave Origin
# Third-party repo: ship it disabled, updates arrive via image rebuilds.
dnf5 config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
dnf5 config-manager setopt brave-browser.enabled=0
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc

# /opt -> var/opt in the base image. Install there, then relocate into immutable /usr
# and link it back at boot, the same layout rpm-ostree uses for layered /opt packages.
# See https://github.com/ublue-os/bazzite-dx/blob/main/build_files/50-fix-opt.sh
mkdir -p /var/opt /usr/lib/opt
dnf5 -y install --enable-repo=brave-browser brave-origin
mv /var/opt/brave.com /usr/lib/opt/brave.com
echo 'L+ /var/opt/brave.com - - - - /usr/lib/opt/brave.com' >/usr/lib/tmpfiles.d/brave-origin.conf
# /var/opt itself is recreated at boot by rpm-ostree-0-integration-opt-usrlocal.conf
rmdir /var/opt

### Bazzite default Flatpaks, used by ujust nitro-setup to skip them during migration
mkdir -p /usr/share/bazzite-nitro
curl -fsSL https://raw.githubusercontent.com/ublue-os/bazzite/main/installer/kde_flatpaks/flatpaks \
	-o /usr/share/bazzite-nitro/bazzite-defaults
