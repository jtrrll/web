{
  cfg,
  config,
  inputs,
  lib,
  ...
}:
{
  config.flake.nixosConfigurations =
    let
      sharedModules = builtins.attrValues config.flake.nixosModules ++ [
        (import inputs.nix-lib { inherit lib; }).modules.nixos.default
        inputs.determinate.nixosModules.default
        (inputs.disko + "/module.nix")
        (inputs.sops-nix + "/modules/sops")
        {
          nixpkgs.overlays = [
            config.flake.overlays.default
          ];
        }
      ];
    in
    lib.mapAttrs (
      _: module:
      inputs.nixpkgs-nixos.lib.nixosSystem {
        modules = sharedModules ++ [ module ];
      }
    ) (cfg.nixos or { });

  config.perSystem = {
    nixosConfigurationBuildChecks.enable = true;
    nixosConfigurationTestChecks.enable = true;
  };
}
