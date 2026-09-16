{
  config.perSystem =
    { pkgs, ... }:
    let
      yaml = pkgs.formats.yaml { };

      nixInstallerConf = ''
        extra-substituters = https://devenv.cachix.org https://install.determinate.systems https://nix-community.cachix.org
        extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw= cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
      '';

      generated = yaml.generate "update-packages.yaml" {
        name = "Update packages";
        "on" = {
          # Mirrors the "nix" ecosystem's weekly Friday schedule in
          # .github/dependabot.yaml -- the closest remaining analog now that
          # Go dependencies (and any other package's own dependencies) are
          # managed by each package's updateScript instead of dependabot.
          schedule = [ { cron = "0 06 * * FRI"; } ];
          workflow_dispatch = { };
        };
        permissions = {
          contents = "write";
          pull-requests = "write";
        };
        jobs.update-packages = {
          name = "Update packages";
          runs-on = "ubuntu-latest";
          steps = [
            { uses = "actions/checkout@v6"; }
            {
              uses = "DeterminateSystems/nix-installer-action@v22";
              "with".extra-conf = nixInstallerConf;
            }
            {
              name = "Update packages";
              run = "nix run .#update-packages";
            }
            {
              name = "Open pull request";
              uses = "peter-evans/create-pull-request@v8";
              "with" = {
                commit-message = "deps(packages): update package dependencies";
                title = "deps(packages): update package dependencies";
                body = "Automated update of package dependencies via each package's `passthru.updateScript`.";
                branch = "update-packages";
                labels = "automated,dependencies";
                token = "\${{ secrets.PR_BOT_PERSONAL_ACCESS_TOKEN }}";
              };
            }
          ];
        };
      };
    in
    {
      config.files.file.".github/workflows/update_packages.yaml".source =
        pkgs.runCommand "update_packages.yaml" { nativeBuildInputs = [ pkgs.yq-go ]; }
          ''
            yq '
              pick(["name", "on", "permissions", "jobs"]) |
              .jobs[] |= pick(["name", "runs-on", "steps"]) |
              .jobs[].steps[] |= pick(["name", "uses", "with", "run"])
            ' ${generated} > $out
          '';
    };
}
