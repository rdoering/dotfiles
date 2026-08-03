{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  # NOTE: home.username and home.homeDirectory are NOT set here. They are
  # platform-specific and injected by the flake (see flake.nix mkHome) so
  # this module stays portable across macOS (/Users/<user>) and Linux
  # (/home/<user>). The switch script selects the matching homeConfiguration
  # via uname.

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards-incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then change it, run `home-manager switch`, and do
  # not use Home Manager again until you have reverted to the old value.
  home.stateVersion = "25.05";

  # All packages managed by Nix Home Manager. migrated off mise/brew.
  home.packages = [
    pkgs.starship
    pkgs.ripgrep
    pkgs.fd
    pkgs.eza
    pkgs.btop
    pkgs.yazi
    pkgs.zoxide
    pkgs.atuin
    pkgs.delta
    pkgs.fzf
    pkgs.doggo
    pkgs.yq
    pkgs.jqp
    pkgs.gron
    pkgs.step-cli
    pkgs.kubernetes-helm
    pkgs.marksman
    pkgs.just
    pkgs.rclone
    pkgs.restic
    pkgs.gh
    pkgs.awscli
    pkgs.herdr
    pkgs.neovim
    pkgs.tmux
    pkgs.opencode
    pkgs.claude-code
    pkgs.zsh
    pkgs.unzip
    pkgs.p7zip
    pkgs.sysbench
    pkgs.globalping
    pkgs.croc
    pkgs.lazygit
    pkgs.xh
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
