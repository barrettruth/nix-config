{ pkgs, config, ... }:

{
  programs.git = {
    enable = true;
    lfs.enable = true;

    ignores = [
      "*.swp"
      "*.swo"
      "*~"
      ".vscode/"
      ".idea/"
      ".DS_Store"
      "Thumbs.db"
      "*.o"
      "*.a"
      "*.so"
      "*.pyc"
      "__pycache__/"
      "node_modules/"
      "target/"
      "dist/"
      "build/"
      "out/"
      "*.class"
      "*.log"
      ".env"
      ".env.local"
      ".envrc"
      "venv/"
      ".mypy_cache/"
      "result"
      "result-*"
      ".claude/settings.local.json"
    ];

    settings = {
      user = {
        name = "Barrett Ruth";
        email = "br@barrettruth.com";
      };
      alias = {
        a = "add";
        b = "branch";
        c = "commit";
        acp = "!acp() { git add . && git commit -m \"$*\" && git push; }; acp";
        cane = "commit --amend --no-edit";
        cf = "config";
        ch = "checkout";
        cl = "clone";
        cp = "cherry-pick";
        d = "diff";
        dt = "difftool";
        f = "fetch";
        i = "init";
        lg = "log --oneline --graph --decorate";
        m = "merge";
        p = "pull";
        pu = "push";
        r = "remote";
        rb = "rebase";
        rs = "restore";
        rt = "reset";
        s = "status";
        sm = "submodule";
        st = "stash";
        sw = "switch";
        wt = "worktree";
      };
      init.defaultBranch = "main";
      core = {
        editor = "nvim";
        whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
      };
      color.ui = "auto";
      diff.tool = "codediff";
      difftool.prompt = false;
      difftool.codediff.cmd = "nvim -c 'CodeDiff' $LOCAL $REMOTE";
      merge.tool = "codediff";
      mergetool.prompt = false;
      mergetool.codediff.cmd = "nvim -c 'CodeDiff' $LOCAL $REMOTE $MERGED";
      push.autoSetupRemote = true;
      credential.helper = "cache";
    };
  };

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
    };
  };
}
