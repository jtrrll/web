{ config, ... }:
let
  getPortfolioPackage = system: (config.perSystem system).packages.portfolio;
in
{
  config.flake.modules.nixos.portfolio =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.portfolio;
    in
    {
      options = {
        services.portfolio = {
          enable = lib.mkEnableOption "the portfolio service";

          package = lib.mkOption {
            type = lib.types.package;
            default = getPortfolioPackage pkgs.stdenv.system;
            description = "The portfolio package to use.";
            example = lib.literalExpression "pkgs.portfolio";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 8080;
            description = "The port the portfolio server listens on.";
            example = 9090;
          };
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.portfolio = {
          description = "Portfolio web server";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            ExecStart = "${cfg.package}/bin/server --port ${toString cfg.port}";
            DynamicUser = true;
            Restart = "on-failure";
          };
        };
      };
    };
}
