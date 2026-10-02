# Hyprland session

A Hyprland session next to Plasma, with uwsm, waybar, fuzzel, mako, hyprlock and hypridle. Colors come from the wallpaper through matugen.

This folder is a snapshot of a live setup. It is **not** part of the image yet: the build ignores it, and nothing here reaches `system_files/`.

- `home/` mirrors `$HOME`.
- `etc/` mirrors `/etc`: the COPR repo files and a logind drop-in that locks instead of suspending on lid close.
- `packages.txt` lists the packages layered with `rpm-ostree`.

## Opinions

- **German UI.** Menus, notifications and the lock screen are in German.
- **No suspend.** There is no auto-suspend and no suspend entry, because resume is unreliable on this laptop (NVIDIA, DisplayLink dock).
- **Hardware.** The monitor and lid settings in `home/.config/hypr/hyprland.lua` are for the Acer Nitro ANV16S panel (`eDP-1`).

## Apply

Run these from this folder.

1. Copy the repo files and layer the packages. The `video` group lets swayosd change the brightness; on Fedora Atomic it has to be copied to `/etc/group` first.

   ```bash
   sudo cp -r etc/. /etc/ && { grep -q '^video:' /etc/group || grep '^video:' /usr/lib/group | sudo tee -a /etc/group; } && sudo usermod -aG video "$USER" && sudo rpm-ostree install $(grep -v '^#' packages.txt)
   ```

2. Reboot, then copy the user files and set a wallpaper. This also writes the matching colors.

   ```bash
   cp -a home/. ~/ && ~/.config/hypr/scripts/wallpaper.sh /usr/share/wallpapers/convergence.png
   ```

3. Log out and pick the Hyprland (uwsm-managed) session.

## Personal files

These files in `home/.config/` are meant to be changed:

- `hypr/user.lua`: keyboard layout (`de`), screenshot folder, gaps, blur, rounding
- `hypr/user.conf`: wallpaper path
- `fuzzel/user.ini`, `mako/user`, `waybar/config.jsonc`, `waybar/style.css`

The `colors.*` files are generated. Change the templates in `matugen/templates/` instead, then run `wallpaper.sh` again.

## Notes

- `rpm-ostree` also pulls in kitty and nwg-panel as weak dependencies. The `Hidden=true` launchers in `.local/share/applications/` hide them.
- GTK apps read `~/.config/gtk-3.0` and `gtk-4.0`, which Plasma writes. Log into Plasma once, or GTK apps use their defaults.
- The default wallpaper `/usr/share/wallpapers/convergence.png` comes from Bazzite, not from a package.
