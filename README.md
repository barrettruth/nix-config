# nix-config

NixOS and home-manager configuration for a Dell XPS 15 9500.

See [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md) for install, disaster
recovery, and key restore instructions.

## Day-to-day

All commands assume you're in `~/nix-config`.

```sh
# rebuild after editing config
sudo nixos-rebuild switch --flake .#xps15

# update all flake inputs, then rebuild
nix flake update
sudo nixos-rebuild switch --flake .#xps15

# rollback to previous generation
sudo nixos-rebuild switch --flake .#xps15 --rollback

# format all nix files
nix fmt

# garbage collect old generations + store
sudo nix profile wipe-history --profile /nix/var/nix/profiles/system
nix store gc

# check flake for errors without building
nix flake check
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
