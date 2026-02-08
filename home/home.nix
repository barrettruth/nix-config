{ lib, config, pkgs, ... }:

let
  isNixOS = builtins.pathExists /etc/NIXOS;
in {
  imports = [
    ./modules/theme.nix
    ./modules/shell.nix
    ./modules/terminal.nix
    ./modules/git.nix
    ./modules/editor.nix
    ./modules/ui.nix
    ./modules/packages.nix
  ];

  config = {
    theme = "midnight";

    home.username = "barrett";
    home.homeDirectory = "/home/${config.home.username}";
    home.stateVersion = "24.11";

    xdg.enable = true;
    targets.genericLinux.enable = !isNixOS;
    news.display = "silent";

    home.file.".local/bin/scripts" = {
      source = ../scripts;
      recursive = true;
      executable = true;
    };

    programs.home-manager.enable = true;
  };
}
