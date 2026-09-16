{
  description = "jtrrll's personal corner of the web";

  inputs = {
    ### Flake dependencies ###
    # keep-sorted start block=yes
    files = {
      flake = false;
      url = "github:mightyiam/files/master";
    };
    flake-parts.url = "github:hercules-ci/flake-parts/main";
    nix-lib = {
      flake = false;
      url = "github:jtrrll/nix-lib/main";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # keep-sorted end

    ### Development dependencies ###
    # keep-sorted start block=yes
    devenv.url = "github:cachix/devenv/main";
    treefmt-nix = {
      flake = false;
      url = "github:numtide/treefmt-nix/main";
    };
    # keep-sorted end

    ### NixOS dependencies ###
    # keep-sorted start block=yes
    determinate.url = "github:DeterminateSystems/determinate/main";
    disko = {
      flake = false;
      url = "github:nix-community/disko/master";
    };
    nixpkgs-nixos.url = "github:NixOS/nixpkgs/nixos-unstable";
    sops-nix = {
      flake = false;
      url = "github:Mic92/sops-nix/master";
    };
    # keep-sorted end

    ### Infrastructure dependencies ###
    # keep-sorted start block=yes
    terranix.url = "github:terranix/terranix/main";
    # keep-sorted end
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      {
        config,
        lib,
        ...
      }:
      let
        nix-lib = import inputs.nix-lib { inherit lib; };
        inherit (nix-lib.lib.modules) aggregate modulesByClassAndName;
        inherit (nix-lib.lib.strings) snakeToCamel;

        modules = lib.mapAttrs (_: aggregate) (modulesByClassAndName {
          path = ./modules;
          transform = class: name: module: {
            class = snakeToCamel class;
            name = lib.replaceStrings [ "_" ] [ "-" ] name;
            inherit module;
          };
        });

        cfg = modulesByClassAndName {
          path = ./cfg;
          transform = class: name: module: {
            class = snakeToCamel class;
            name = lib.replaceStrings [ "_" ] [ "-" ] name;
            inherit module;
          };
        };
      in
      {
        imports = [
          inputs.devenv.flakeModule
          (inputs.files + "/flake-module.nix")
          inputs.flake-parts.flakeModules.modules
          inputs.flake-parts.flakeModules.touchup
          inputs.terranix.flakeModule
          (inputs.treefmt-nix + "/flake-module.nix")
          nix-lib.modules.flake.default
        ]
        ++ lib.attrValues (cfg.flake or { });

        config = {
          _module.args.cfg = cfg;
          flake = {
            inherit modules;
            nixosModules = config.flake.modules.nixos or { };
          };
          systems = [
            # keep-sorted start
            "aarch64-darwin"
            "aarch64-linux"
            "x86_64-linux"
            # keep-sorted end
          ];
          touchup = {
            any.enable = lib.mkDefault false;
            attr = {
              # keep-sorted start block=yes
              apps.enable = true;
              checks.enable = true;
              devShells.enable = true;
              formatter.enable = true;
              nixosConfigurations.enable = true;
              nixosModules.enable = true;
              overlays.enable = true;
              packages = {
                enable = true;
                # Remove the deprecated `*-devenv-test` / `*-devenv-up`
                # packages that devenv generates for each shell, and the
                # terranix `*-tf` wrappers (kept as apps, not packages).
                any.any =
                  { attrName, lib, ... }:
                  {
                    enable =
                      !(
                        lib.hasInfix "devenv-test" attrName
                        || lib.hasInfix "devenv-up" attrName
                        || lib.hasSuffix "-tf" attrName
                      );
                  };
              };
              # keep-sorted end
            };
          };
        };
      }
    );
}
