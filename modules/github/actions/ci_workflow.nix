{ inputs, ... }:
let
  nixInstallerStep = {
    uses = "DeterminateSystems/nix-installer-action@v22";
    "with".extra-conf = ''
      extra-substituters = https://devenv.cachix.org https://install.determinate.systems https://nix-community.cachix.org
      extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw= cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
    '';
  };

  freeDiskStep = {
    name = "Free disk space";
    uses = "endersonmenezes/free-disk-space@v3";
    "with" = {
      remove_dotnet = true;
      remove_haskell = true;
      remove_packages = "azure-cli microsoft-edge-stable google-chrome-stable firefox postgresql* *llvm* mysql*";
      testing = false;
    };
  };

  workflow = {
    name = "CI";
    on = {
      pull_request.branches = [ "*" ];
      push.branches = [ "main" ];
      schedule = [ { cron = "0 06 * * MON"; } ];
      workflow_dispatch = { };
    };
    concurrency = {
      cancel-in-progress = true;
      group = "\${{ github.workflow }}-\${{ github.ref }}";
    };
    env.NIXPKGS_ALLOW_UNFREE = 1;
    jobs = {
      checks = {
        name = "Checks";
        runs-on = "ubuntu-latest";
        steps = [
          { uses = "actions/checkout@v6"; }
          nixInstallerStep
          { uses = "DeterminateSystems/flake-checker-action@v12"; }
          {
            name = "Build checks";
            run = "nix run github:Mic92/nix-fast-build -- --no-nom --skip-cached --flake .#checks.x86_64-linux";
          }
        ];
      };
      build = {
        name = "Build";
        runs-on = "ubuntu-latest";
        steps = [
          freeDiskStep
          { uses = "actions/checkout@v6"; }
          nixInstallerStep
          {
            name = "Build packages";
            run = "nix run github:Mic92/nix-fast-build -- --no-nom --skip-cached --flake .#packages.x86_64-linux";
          }
          {
            name = "Build passthru tests";
            run = "nix run github:Mic92/nix-fast-build -- --no-nom --skip-cached --flake .#packages.x86_64-linux.portfolio.passthru.tests";
          }
          {
            name = "Build servers";
            run = "nix run github:Mic92/nix-fast-build -- --no-nom --skip-cached --flake .#nixosConfigurations --select 'configs: builtins.mapAttrs (_: c: c.config.system.build.toplevel) configs'";
          }
        ];
      };
    };
  };
in
{
  imports = [ inputs.files.flakeModules.default ];

  config.perSystem =
    { pkgs, ... }:
    let
      writeYAML = (pkgs.formats.yaml { }).generate;
      generated = writeYAML "ci.yaml" workflow;
      ordered = pkgs.runCommand "ci.yaml" { nativeBuildInputs = [ pkgs.yq-go ]; } ''
        yq '
          . |= pick(["name", "on", "concurrency", "env", "jobs"])
          | (.. | select(tag == "!!str" and test("\n"))) style="literal"
        ' ${generated} > $out
      '';
    in
    {
      config.files.files = [
        {
          path_ = ".github/workflows/ci.yaml";
          drv = ordered;
        }
      ];
    };
}
