# NixOS Migration Guide

## Before you start

Things to have ready:

- A USB stick (4GB+)
- WiFi password
- This guide on your phone

Your nix-config already has both `homeConfigurations.barrett` (standalone
home-manager, what you use now on Arch) and `nixosConfigurations.xps15` (full
NixOS). The flake, configuration.nix, and all home-manager modules are ready.
The only file you're missing is `hosts/xps15/hardware-configuration.nix`, which
gets generated during install.

## 1. Prep on Arch (before wiping)

### Back up

```sh
# Secrets
cp -r ~/.gnupg /tmp/gnupg-backup
cp -r ~/.ssh /tmp/ssh-backup
cp -r ~/.local/share/pass /tmp/pass-backup

# Fonts (not in nixpkgs)
tar cf /tmp/fonts.tar ~/.local/share/fonts

# Browser profile
tar cf /tmp/zen.tar ~/.zen

# Any uncommitted work
cd ~/dev && git status  # check each repo

# Wallpapers and lock screen images
tar cf /tmp/img.tar ~/img
```

Copy all of `/tmp/*-backup` and `/tmp/*.tar` to the USB stick or another
machine.

### Push this repo

```sh
cd ~/nix-config  # (as barrett, or sg barrett)
git push
```

### Download NixOS ISO

Grab the minimal ISO from https://nixos.org/download — you want the "Minimal
ISO image" (not graphical), x86_64.

Flash it:

```sh
sudo dd bs=4M if=nixos-minimal-*.iso of=/dev/sdX status=progress oflag=sync
```

## 2. Boot the installer

Reboot, mash F12 for boot menu, pick USB.

You'll land in a root shell. Connect to WiFi:

Prepare `iwd` (available in the installer too):

```sh
iwctl
[iwd]# station wlan0 scan
[iwd]# station wlan0 get-networks
[iwd]# station wlan0 connect YourSSID
```

Verify: `ping nixos.org`

## 3. Partition

Your current disk layout (from fstab):

| Mount    | FS   | UUID              |
|----------|------|-------------------|
| `/`      | ext4 | `1ac6e3de-...`    |
| `/boot/efi` | vfat | `5646-BF32`   |
| swap     | swap | `39cde381-...`    |

### Option A: Reuse existing partitions (if dual-boot / keeping data)

```sh
# Find your partitions
lsblk -f

# Format root (THIS WIPES ARCH)
mkfs.ext4 -L nixos /dev/nvme0n1pX

# Mount
mount /dev/nvme0n1pX /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1pY /mnt/boot/efi
swapon /dev/nvme0n1pZ
```

### Option B: Fresh partition table

```sh
# Wipe and repartition
fdisk /dev/nvme0n1

# Create:
# 1. EFI partition  (512M, type EFI System)
# 2. Swap partition (16G or match your RAM)
# 3. Root partition (rest of disk, type Linux filesystem)

mkfs.fat -F 32 /dev/nvme0n1p1
mkswap /dev/nvme0n1p2
mkfs.ext4 -L nixos /dev/nvme0n1p3

mount /dev/nvme0n1p3 /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi
swapon /dev/nvme0n1p2
```

## 4. Generate hardware config

```sh
nixos-generate-config --root /mnt
```

This creates:

- `/mnt/etc/nixos/configuration.nix` (ignore this, we have our own)
- `/mnt/etc/nixos/hardware-configuration.nix` (we need this)

Copy it into your config structure:

```sh
mkdir -p /mnt/home/barrett/nix-config/hosts/xps15
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/home/barrett/nix-config/hosts/xps15/
```

## 5. Get your config onto the new system

### Option A: Clone from git (needs network)

```sh
nix-shell -p git
git clone https://github.com/YOUR/nix-config /mnt/home/barrett/nix-config
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/home/barrett/nix-config/hosts/xps15/
```

### Option B: Copy from USB

```sh
mount /dev/sdX1 /mnt2  # your usb
cp -r /mnt2/nix-config /mnt/home/barrett/nix-config
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/home/barrett/nix-config/hosts/xps15/
```

## 6. Install

```sh
nixos-install --flake /mnt/home/barrett/nix-config#xps15
```

It will:

- Build the full system closure
- Install GRUB
- Ask you to set the root password

This takes a while. Let it run.

## 7. First boot

```sh
reboot
```

Remove the USB. GRUB should appear. Boot NixOS.

Log in as root (password you just set), then set barrett's password:

```sh
passwd barrett
```

Log out, log in as barrett.

## 8. Post-install setup

### Fix ownership

```sh
sudo chown -R barrett:users ~/nix-config
```

### Home-manager (already integrated)

Your flake uses `home-manager.nixosModules.home-manager` so HM is part of the
system build. No separate `home-manager switch` needed — it all happens during
`nixos-rebuild switch`.

### Restore secrets

```sh
# From USB or wherever you backed up
cp -r /path/to/gnupg-backup ~/.gnupg
chmod 700 ~/.gnupg
chmod 600 ~/.gnupg/*

cp -r /path/to/ssh-backup ~/.ssh
chmod 700 ~/.ssh
chmod 600 ~/.ssh/*

cp -r /path/to/pass-backup ~/.local/share/pass
```

### Restore fonts

```sh
mkdir -p ~/.local/share/fonts
tar xf /path/to/fonts.tar -C /
fc-cache -fv
```

### Restore images

```sh
tar xf /path/to/img.tar -C /
```

### Restore browser profile

```sh
tar xf /path/to/zen.tar -C /
```

### Rebuild (the main command going forward)

```sh
sudo nixos-rebuild switch --flake ~/nix-config#xps15
```

## 9. Gaps — things still needed in configuration.nix

Your `configuration.nix` already covers: GRUB, nvidia, iwd, keyd, pipewire,
docker, libvirtd, openssh, hyprland, bluetooth, zsh, xdg portals.

Still missing:

### Must add

```nix
# /bin/sh = dash (you have a pacman hook for this on Arch)
environment.binsh = "${pkgs.dash}/bin/dash";

# doas (you use this instead of sudo on Arch)
security.doas = {
  enable = true;
  extraRules = [{
    groups = [ "wheel" ];
    persist = true;
  }];
};

# Auto timezone (replaces your tzupdate timer)
services.automatic-timezoned.enable = true;
# (already in your config, just confirming)

# Multilib equivalent — enable 32-bit support for Steam/Wine if needed
# hardware.graphics.enable32Bit = true;
```

### Should add

```nix
# Reflector equivalent — NixOS handles mirrors differently, but you may want
# to pin a substituter or add cachix
nix.settings = {
  experimental-features = [ "nix-command" "flakes" ];
  # already there, just noting
};

# geoclue for timezone detection
services.geoclue2.enable = true;

# X11 session (spectrwm/dwm) — if you want to keep X11 as an option
services.xserver = {
  enable = true;
  videoDrivers = [ "nvidia" ];
  windowManager.spectrwm.enable = true;
  # or just use xinit manually
};

# Fonts — system-wide
fonts.packages = with pkgs; [
  jetbrains-mono
  joypixels
  font-awesome
  # Your custom fonts (berkeley-mono etc) aren't in nixpkgs,
  # keep them in ~/.local/share/fonts
];

# Yubikey / smartcard
services.pcscd.enable = true;

# QEMU/KVM
virtualisation.libvirtd.qemu.package = pkgs.qemu_full;

# Firewall (you have iptables on Arch)
networking.firewall.enable = true;
```

### Packages to add to environment.systemPackages or HM

Compare your 207 explicit Arch packages against what's in
`home/modules/packages.nix`. The big categories not yet covered:

- **TeX**: texlive, biber, typst, quarto — add to HM packages
- **Languages**: rustup, go, ocaml, opam, uv, luarocks — add to HM packages
  (or use devShells per-project)
- **Dev tools**: cmake, ninja, gdb, valgrind, perf — add to HM or devShells
- **CLI**: fastfetch, socat, rsync, bind (dig), time — add to HM packages
- **AUR equivalents**: pikaur (not needed), sioyek (already in HM),
  basedpyright, pistol, clipmenu (not needed on Wayland)

### Things you DON'T need on NixOS

- pacman hooks (dash, nvidia) — use NixOS options instead
- pikaur/AUR — use nixpkgs, overlays, or flake inputs
- reflector — not applicable
- mkinitcpio — NixOS uses its own initrd builder
- GRUB manual config — declarative via `boot.loader.grub`

## 10. Day-to-day workflow

```sh
# Edit config
nvim ~/nix-config/hosts/xps15/configuration.nix
# or any home-manager module
nvim ~/nix-config/home/modules/shell.nix

# Rebuild
sudo nixos-rebuild switch --flake ~/nix-config#xps15

# Update all inputs
nix flake update --flake ~/nix-config
sudo nixos-rebuild switch --flake ~/nix-config#xps15

# Rollback if something breaks
sudo nixos-rebuild switch --flake ~/nix-config#xps15 --rollback
# or pick a previous generation from GRUB

# Garbage collect old generations
sudo nix-collect-garbage -d
```

## 11. Checklist

- [ ] Back up gnupg, ssh, pass, fonts, img, zen profile
- [ ] Push nix-config repo
- [ ] Flash NixOS minimal ISO to USB
- [ ] Boot USB, connect WiFi
- [ ] Partition and mount
- [ ] Generate hardware-configuration.nix
- [ ] Get nix-config onto /mnt
- [ ] `nixos-install --flake /mnt/home/barrett/nix-config#xps15`
- [ ] Set root password, reboot
- [ ] Set barrett password, log in
- [ ] Fix nix-config ownership
- [ ] Restore secrets (gnupg, ssh, pass)
- [ ] Restore fonts, images, browser profile
- [ ] `sudo nixos-rebuild switch --flake ~/nix-config#xps15`
- [ ] Verify: terminal, editor, browser, WM all working
- [ ] Add missing packages to configuration.nix / HM modules
- [ ] Add `environment.binsh = dash`
- [ ] Add doas config
- [ ] Add fonts.packages
- [ ] Add pcscd for Yubikey
- [ ] Commit hardware-configuration.nix
