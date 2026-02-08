{ pkgs, lib, config, zen-browser, system, ... }:

let
  claude = true;
  zen = true;
  sioyek = true;
  vesktop = true;
  neovim = config.programs.neovim.enable;
in {
  home.sessionVariables = lib.optionalAttrs zen {
    BROWSER = "zen-browser";
  };

  programs.mpv.enable = true;

  home.packages = with pkgs; [
    signal-desktop
    slack
    bitwarden-desktop
  ]
  ++ lib.optionals claude [ claude-code ]
  ++ lib.optionals zen [ zen-browser.packages.${system}.default ]
  ++ lib.optionals sioyek [ sioyek ]
  ++ lib.optionals vesktop [ vesktop ];

  xdg.configFile."claude/settings.json" = lib.mkIf claude {
    text = builtins.toJSON {
      permissions.defaultMode = "acceptEdits";
      network_access = true;
      allowed_domains = [
        "github.com"
        "raw.githubusercontent.com"
        "api.github.com"
      ];
      tools.web_fetch = true;
    };
  };

  home.activation.linkZenProfile = lib.mkIf zen (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      zen_config="$HOME/.zen"
      repo_zen="${config.home.homeDirectory}/nix-config/config/zen"

      if [ ! -d "$zen_config" ]; then
        exit 0
      fi

      profile=""
      for d in "$zen_config"/*.Default\ \(release\); do
        [ -d "$d" ] && profile="$d" && break
      done

      if [ -z "$profile" ]; then
        exit 0
      fi

      mkdir -p "$profile/chrome"

      for f in userChrome.css user.js containers.json handlers.json zen-keyboard-shortcuts.json; do
        src="$repo_zen/$f"
        if [ "$f" = "userChrome.css" ]; then
          dest="$profile/chrome/$f"
        else
          dest="$profile/$f"
        fi

        [ -f "$src" ] || continue

        if [ -L "$dest" ]; then
          continue
        fi

        if [ -f "$dest" ]; then
          rm "$dest"
        fi

        ln -s "$src" "$dest"
      done
    ''
  );

  xdg.configFile."electron-flags.conf".text = ''
    --enable-features=WaylandWindowDecorations
    --ozone-platform-hint=auto
  '';

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {}
    // lib.optionalAttrs zen {
      "x-scheme-handler/http" = "zen.desktop";
      "x-scheme-handler/https" = "zen.desktop";
      "text/html" = "zen.desktop";
    }
    // lib.optionalAttrs neovim {
      "text/plain" = "nvim.desktop";
    }
    // lib.optionalAttrs sioyek {
      "application/pdf" = "sioyek.desktop";
      "application/epub" = "sioyek.desktop";
    }
    // lib.optionalAttrs vesktop {
      "x-scheme-handler/discord" = "vesktop.desktop";
    };
  };
}
