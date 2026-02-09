# nix-config

NixOS and home-manager configuration for a Dell XPS 15 9500.

## Disaster recovery

If you lose your laptop, you need exactly two things from memory:

1. AWS root credentials (email + password) — gets you into the console,
   which gets you to Lightsail, which means Vaultwarden at
   git.barrettruth.com is reachable
2. Vaultwarden master password — unlocks everything else (GitHub, email,
   etc.)

If you have 2FA on either of these via an authenticator app, you also
need recovery codes. Print them. Store them somewhere physical that
isn't your laptop.

All SSH keys, GPG keys, and .pem files are stored as attachments in
Vaultwarden. Restoring them is step 10 below.

### Before you migrate: upload keys to Vaultwarden

Do this now, while you still have a working machine. Create a vault
entry (e.g. "keys") and attach:

- `~/.ssh/id_ed25519`
- `~/.ssh/id_ed25519.pub`
- `~/.ssh/git-keypair.pem`
- `~/.ssh/git-keypair-old.pem`
- `~/.ssh/uva_key` (if still needed)
- GPG private key (export first):

```sh
gpg --export-secret-keys --armor A6C96C9349D2FC81 > /tmp/gpg-private.asc
```

Attach `/tmp/gpg-private.asc`, then delete the temp file.

By storing the same keys, the key IDs in `git.nix` stay valid, GitHub
doesn't need updating, and git signing works immediately after restore.

## Manual steps (fresh install from zero)

### 1. Flash the installer

Download the NixOS minimal ISO from https://nixos.org/download (x86_64).

```sh
dd bs=4M if=nixos-minimal-*.iso of=/dev/sdX status=progress oflag=sync
```

### 2. Boot and connect to WiFi

Boot from USB (F12 for boot menu on XPS 15).

```sh
iwctl
[iwd]# station wlan0 scan
[iwd]# station wlan0 get-networks
[iwd]# station wlan0 connect <SSID>
```

Verify: `ping nixos.org`

### 3. Partition

```sh
lsblk -f
```

#### Option A: fresh partition table

```sh
fdisk /dev/nvme0n1

# 1. EFI System partition — 512M
# 2. Linux swap — match your RAM
# 3. Linux filesystem — rest of disk

mkfs.fat -F 32 /dev/nvme0n1p1
mkswap /dev/nvme0n1p2
mkfs.ext4 -L nixos /dev/nvme0n1p3

mount /dev/nvme0n1p3 /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi
swapon /dev/nvme0n1p2
```

#### Option B: reuse existing partitions

```sh
mkfs.ext4 -L nixos /dev/nvme0n1pX    # formats root, wipes the old OS

mount /dev/nvme0n1pX /mnt
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1pY /mnt/boot/efi
swapon /dev/nvme0n1pZ
```

### 4. Generate hardware config

```sh
nixos-generate-config --root /mnt
```

This produces `/mnt/etc/nixos/hardware-configuration.nix`. You need this
file — it describes your specific disk UUIDs, kernel modules, and
firmware. The generated `configuration.nix` next to it is not used.

### 5. Clone the repo

```sh
nix-shell -p git
git clone https://github.com/barrettruth/nix-config /mnt/home/barrett/nix-config
```

Copy the hardware config into place:

```sh
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/home/barrett/nix-config/hosts/xps15/
```

### 6. Copy fonts (optional, can be done later)

Fonts are proprietary and not in the repo. The build will succeed
without them — home-manager prints a warning and fonts fall back to
system defaults. When you're ready, populate `~/nix-config/fonts/`:

- Copy from a USB drive
- Copy from a backup
- Download from wherever you originally purchased them
- Pull from another machine via scp

```sh
cp -r /path/to/your/fonts /mnt/home/barrett/nix-config/fonts/
```

The `fonts/` directory is gitignored and symlinked to
`~/.local/share/fonts` at activation time.

### 7. Install

```sh
nixos-install --flake /mnt/home/barrett/nix-config#xps15
```

This builds the entire system (kernel, drivers, services, user
environment, home-manager) in one shot. It will ask you to set the root
password at the end.

### 8. Reboot and set user password

```sh
reboot
```

Remove the USB. Log in as root, then:

```sh
passwd barrett
logout
```

Log in as barrett.

### 9. Fix ownership

The install created `~/nix-config` as root. Fix it:

```sh
sudo chown -R barrett:users ~/nix-config
```

### 10. Restore keys from Vaultwarden

Open Zen browser and go to git.barrettruth.com. Log in with your
master password. Open the vault entry containing your keys and download
all attachments.

#### SSH keys

```sh
mkdir -p ~/.ssh
cp ~/Downloads/id_ed25519 ~/.ssh/
cp ~/Downloads/id_ed25519.pub ~/.ssh/
cp ~/Downloads/git-keypair.pem ~/.ssh/
cp ~/Downloads/git-keypair-old.pem ~/.ssh/
```

Permissions are fixed automatically by the activation script in
`git.nix` on the next rebuild. If you want them right now:

```sh
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519 ~/.ssh/git-keypair.pem ~/.ssh/git-keypair-old.pem
chmod 644 ~/.ssh/id_ed25519.pub
```

Set the repo remote to SSH for push access:

```sh
cd ~/nix-config
git remote set-url origin git@github.com:barrettruth/nix-config.git
```

#### GPG key

```sh
gpg --import ~/Downloads/gpg-private.asc
gpg --edit-key A6C96C9349D2FC81 trust
```

Select trust level 5 (ultimate), then `quit`. The key ID matches what's
in `git.nix`, so git signing works immediately.

#### Clean up

Delete the downloaded key files from `~/Downloads/`.

### 11. Rebuild

After all manual steps are done:

```sh
sudo nixos-rebuild switch --flake ~/nix-config#xps15
```

### 12. Verify

- Terminal opens (ghostty)
- Neovim works and plugins install on first launch
- Browser opens (zen)
- Waybar shows at top
- Audio works (XF86 keys)
- Git push works (SSH)
- Git commits are signed (GPG)

## What's automated vs. what's manual

### Automated (handled by the flake)

- All packages and their exact versions
- Zsh, tmux, fzf, direnv, lf configuration
- Ghostty terminal configuration
- Hyprland, waybar, rofi, dunst, hypridle, hyprlock, hyprpaper
- Git config, aliases, ignore patterns
- SSH config (host definitions, not keys)
- GPG agent config (not the keys themselves)
- Keyd keyboard remapping
- NVIDIA drivers and prime offload
- Pipewire audio stack
- Docker and libvirt
- Systemd services and timers
- XDG directories and MIME associations
- Scripts symlinked to ~/.local/bin/scripts
- Directory creation (~/dev, ~/dl, ~/img, ~/wp)
- Cloning this repo to ~/nix-config on first activation
- Wallpaper symlinks from the repo to ~/img/screen
- Daily flake input updates

### Manual (you must do these yourself)

- Flash and boot the installer
- Partition and mount disks
- Generate hardware-configuration.nix
- Set root and user passwords
- Restore SSH keys, GPG key, and .pem files from Vaultwarden
- Copy fonts into nix-config/fonts/ (optional, can be done later)
- Restore browser profile (~/.zen) if you want tabs/extensions back

## Day-to-day

```sh
# edit config, rebuild
sudo nixos-rebuild switch --flake ~/nix-config#xps15

# update all inputs (nixpkgs, home-manager, etc.)
nix flake update --flake ~/nix-config
sudo nixos-rebuild switch --flake ~/nix-config#xps15

# rollback
sudo nixos-rebuild switch --flake ~/nix-config#xps15 --rollback
# or pick a previous generation from GRUB at boot

# garbage collect old generations
sudo nix-collect-garbage -d

# home-manager is integrated into nixos-rebuild, no separate command needed
```

## Architecture

```
flake.nix
  inputs: nixpkgs, home-manager, nixos-hardware, neovim-nightly,
          zen-browser, claude-code

  nixosConfigurations.xps15          # sudo nixos-rebuild switch --flake .#xps15
    hosts/xps15/configuration.nix    #   boot, hardware, networking, services, users
    hosts/xps15/hardware-configuration.nix  # machine-specific (not committed)
    home-manager (embedded)          #   user env built as part of system
      home/home.nix                  #   imports all modules below
        modules/bootstrap.nix        #     mkdir, clone repo, link wallpapers
        modules/theme.nix            #     midnight/daylight color palettes, fonts, cursor
        modules/shell.nix            #     zsh, tmux, lf, fzf, direnv, ripgrep, fd, eza
        modules/terminal.nix         #     ghostty
        modules/git.nix              #     git, gh, ssh hosts, gpg agent
        modules/editor.nix           #     neovim (config is out-of-store symlink)
        modules/ui.nix               #     hyprland, waybar, rofi, dunst, hyprlock
        modules/packages.nix         #     apps (zen, signal, slack, etc.)

  homeConfigurations.barrett         # home-manager switch --flake .#barrett
    (same home/home.nix, for non-NixOS systems)
```
