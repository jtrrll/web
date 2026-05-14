{
  description = "jtrrll's personal corner of the web";

  inputs = {
    ### Flake dependencies ###
    # keep-sorted start block=yes
    files.url = "github:mightyiam/files/main";
    flake-parts.url = "github:hercules-ci/flake-parts/main";
    import-tree.url = "github:vic/import-tree/main";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # keep-sorted end

    ### Development dependencies ###
    # keep-sorted start block=yes
    devenv.url = "github:cachix/devenv/main";
    justix = {
      inputs.nixpkgs.follows = "devenv/nixpkgs";
      url = "github:jtrrll/justix/main";
    };
    snekcheck = {
      inputs.nixpkgs.follows = "devenv/nixpkgs";
      url = "github:jtrrll/snekcheck/main";
    };
    treefmt-nix = {
      inputs.nixpkgs.follows = "devenv/nixpkgs";
      url = "github:numtide/treefmt-nix/main";
    };
    # keep-sorted end

    ### NixOS dependencies ###
    # keep-sorted start block=yes
    determinate.url = "github:DeterminateSystems/determinate/main";
    disko = {
      inputs.nixpkgs.follows = "nixpkgs-nixos";
      url = "github:nix-community/disko/master";
    };
    nixpkgs-nixos.url = "github:NixOS/nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix/master";
    # keep-sorted end

    ### Infrastructure dependencies ###
    # keep-sorted start block=yes
    terranix.url = "github:terranix/terranix/main";
    # keep-sorted end
  };

  outputs =
    {
      flake-parts,
      import-tree,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      {
        config,
        lib,
        ...
      }:
      let
        modules-tree = lib.pipe import-tree [
          (it: it.withLib lib)
          (it: it.addPath ./modules)
          (it: it.filterNot (lib.hasInfix "/by_name/"))
        ];
      in
      {
        imports = [
          inputs.flake-parts.flakeModules.flakeModules
          inputs.terranix.flakeModule
          modules-tree.result
        ];

        options = {
          flake.lib = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
            description = "A top-level library";
          };
        };

        config = {
          flake = {
            lib = {
              inherit modules-tree;
            };
            flakeModules = config.flake.modules.flake // {
              default = {
                imports = lib.attrValues config.flake.modules.flake;
              };
            };
          };
          systems = lib.systems.flakeExposed;
        };
      }
    );
}
