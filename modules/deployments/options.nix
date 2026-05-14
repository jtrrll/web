{ lib, ... }:
let
  targetModule = lib.types.submodule {
    options = {
      nixosConfiguration = lib.mkOption {
        type = lib.types.raw;
        description = "The NixOS system configuration to deploy";
      };
      ipAddress = lib.mkOption {
        type =
          let
            ipv4Pattern = "([0-9]{1,3}\\.){3}[0-9]{1,3}";
          in
          lib.types.strMatching ipv4Pattern;
        description = "The IPv4 address of the target machine";
      };
    };
  };
in
{
  options.flake.deployments = lib.mkOption {
    description = "Named groups of NixOS systems to deploy";
    type = lib.types.attrsOf (lib.types.listOf targetModule);
    default = { };
  };
}
