{
  inputs,
  lib,
  ...
}:
{
  imports = [ inputs.devenv.flakeModule ];

  config.perSystem =
    {
      config,
      pkgs,
      self',
      ...
    }:
    let
      shellsFromDirectory =
        let
          nameFn = lib.replaceStrings [ "_" ] [ "-" ];
          importFn = import;
        in
        directory:
        lib.concatMapAttrs (
          name: type:
          let
            path = directory + "/${name}";
          in
          if type == "directory" then
            { "${nameFn name}" = importFn "${path}/shell.nix"; }
          else if type == "regular" && lib.hasSuffix ".nix" name then
            { "${nameFn (lib.removeSuffix ".nix" name)}" = importFn path; }
          else
            { }
        ) (builtins.readDir directory);
    in
    {
      config = {
        devenv = {
          modules = (lib.attrValues inputs.justix.modules.devenv) ++ [
            {
              containers = lib.mkForce { };

              enterShell = lib.getExe (
                pkgs.writeShellApplication rec {
                  meta.mainProgram = name;
                  name = "splashScreen";
                  runtimeInputs = [
                    pkgs.lolcat
                    pkgs.uutils-coreutils-noprefix
                    self'.packages.splash
                  ];
                  text = ''
                    splash
                    printf "\033[0;1;36mDEVSHELL ACTIVATED\033[0m\n"
                  '';
                }
              );

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
          shells = shellsFromDirectory ./by_name;
        };
      };
    };
}
