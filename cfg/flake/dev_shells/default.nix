{
  config,
  lib,
  ...
}:
let
  flakeConfig = config;
in
{
  config.perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      config.devenv = {
        modules = [
          {
            containers = lib.mkForce { };
            overlays = [ flakeConfig.flake.overlays.default ];

            git-hooks = {
              default_stages = [ "pre-push" ];
              hooks = {
                actionlint.enable = true;
                check-added-large-files = {
                  enable = true;
                  stages = [ "pre-commit" ];
                };
                check-json.enable = true;
                check-yaml.enable = true;
                deadnix.enable = true;
                detect-private-keys = {
                  enable = true;
                  stages = [ "pre-commit" ];
                };
                flake-checker.enable = true;
                fmt = {
                  enable = true;
                  entry = "nix fmt";
                  name = "fmt";
                  pass_filenames = false;
                };
                mixed-line-endings.enable = true;
                nil.enable = true;
                no-commit-to-branch = {
                  enable = true;
                  stages = [ "pre-commit" ];
                };
                ripsecrets = {
                  enable = true;
                  stages = [ "pre-commit" ];
                };
                shellcheck = {
                  enable = true;
                  excludes = [ ".envrc" ];
                };
                statix = {
                  enable = true;
                  settings.ignore = [ "hardware_configuration.nix" ];
                };
                write-files = {
                  enable = true;
                  entry = lib.getExe config.files.writer.drv;
                  name = "write-files";
                  pass_filenames = false;
                };
              };
            };

            languages.nix = {
              enable = true;
              lsp.package = pkgs.nixd;
            };
          }
        ];
        shells = {
          default =
            { pkgs, ... }:
            {
              enterShell = lib.getExe (
                pkgs.writeShellApplication rec {
                  meta.mainProgram = name;
                  name = "splashScreen";
                  runtimeInputs = [
                    pkgs.lolcat
                    pkgs.uutils-coreutils-noprefix
                    pkgs.splash
                  ];
                  text = ''
                    splash
                    printf "\033[0;1;36mDEVSHELL ACTIVATED\033[0m\n"
                  '';
                }
              );
            };
          nixos =
            { pkgs, ... }:
            {
              packages = [
                pkgs.age
                pkgs.sops
                pkgs.ssh-to-age
              ];
            };
        };
      };
    };
}
