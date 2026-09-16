{ inputs, lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      ...
    }:
    let
      inherit ((pkgs.extend (import inputs.nix-lib { inherit lib; }).overlays.default)) snekcheck;
    in
    {
      config = {
        treefmt = {
          imports = [
            (import inputs.nix-lib { inherit lib; }).modules.treefmt.default
          ];
          programs = {
            actionlint.enable = true;
            gofumpt = {
              enable = true;
              includes = [ "pkgs/portfolio/src/**/*.go" ];
            };
            keep-sorted = {
              enable = true;
              excludes = [ "*.go" ];
            };
            shellcheck = {
              enable = true;
              excludes = [ ".envrc" ];
            };
            shfmt.enable = true;
            templ.enable = true;
            typstyle.enable = true;
            yamlfmt.enable = true;
          };
          settings = {
            excludes = [ "*/hardware_configuration.nix" ];
            formatter.snekcheck = {
              command = lib.getExe snekcheck;
              options = [ "--fix" ];
              includes = [ "*" ];
            };
          };
        };
      };
    };
}
