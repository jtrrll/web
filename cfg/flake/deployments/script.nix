{
  config,
  lib,
  ...
}:
let
  inherit (config.flake) deployments;

  deploymentsJson = builtins.toJSON (
    lib.mapAttrs (
      _: targets:
      builtins.map (target: {
        hostname = target.nixosConfiguration.config.networking.hostName;
        host = target.ipAddress;
        ssh_port = builtins.head target.nixosConfiguration.config.services.openssh.ports;
      }) targets
    ) deployments
  );
in
{
  config.perSystem =
    { pkgs, ... }:
    let
      script = pkgs.replaceVars ./deploy.sh {
        deployments = deploymentsJson;
      };
      deploy = pkgs.writeShellApplication {
        name = "deploy";
        meta = {
          description = "Deploy NixOS configurations to remote machines";
          platforms = lib.platforms.all;
        };
        runtimeInputs = [
          pkgs.gum
          pkgs.jq
          pkgs.nixos-rebuild
          pkgs.openssh
        ];
        text = lib.readFile script;
      };
    in
    {
      config.apps.deploy = {
        inherit (deploy) meta;
        type = "app";
        program = lib.getExe deploy;
      };
    };
}
