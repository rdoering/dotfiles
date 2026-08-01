{
  description = "Robert's home environment — managed by chezmoi + Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      # Local derivations not in nixpkgs are wired in as an overlay so
      # home.nix can reference them by attribute name (e.g. globalping).
      localOverlay = final: prev: {
        globalping = final.callPackage ./globalping.nix { };
      };

      # Build a home-manager configuration for one target platform.
      # system:        nixpkgs system string (e.g. "aarch64-darwin")
      # username:      login name
      # homeDirectory: absolute path to $HOME on that platform
      mkHome = { system, username, homeDirectory }:
        let
          pkgs = nixpkgs.legacyPackages.${system}.extend localOverlay;
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./home.nix
            {
              # Platform-specific values injected here so home.nix stays
              # platform-agnostic. Chezmoi could also template these, but
              # keeping them in the flake avoids re-rendering on every host
              # and lets `home-manager switch` work without chezmoi too.
              home.username = username;
              home.homeDirectory = homeDirectory;
            }
          ];
        };
    in
    {
      # One configuration per (system, host) combination. The switch script
      # (run_onchange_40_home_manager_switch.sh.tmpl) picks the right one via
      # `uname -s` + `uname -m`.
      homeConfigurations.robert-darwin-arm64 = mkHome {
        system = "aarch64-darwin";
        username = "robert";
        homeDirectory = "/Users/robert";
      };
      homeConfigurations.robert-darwin-x86_64 = mkHome {
        system = "x86_64-darwin";
        username = "robert";
        homeDirectory = "/Users/robert";
      };
      homeConfigurations.robert-linux-x86_64 = mkHome {
        system = "x86_64-linux";
        username = "robert";
        homeDirectory = "/home/robert";
      };
      homeConfigurations.robert-linux-arm64 = mkHome {
        system = "aarch64-linux";
        username = "robert";
        homeDirectory = "/home/robert";
      };
    };
}
