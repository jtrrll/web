{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  config.perSystem =
    {
      config,
      inputs',
      lib,
      ...
    }:
    {
      config = {
        devenv.modules = [
          {
            justix.config.recipes.fmt = {
              attributes.doc = "Formats and lints files";
              commands = ''
                @find "{{ paths }}" ! -path '*/.*' -exec ${lib.getExe inputs'.snekcheck.packages.default} --fix {} +
                @${lib.getExe config.treefmt.build.wrapper} {{ paths }}
              '';
              parameters = [ "*paths='.'" ];
            };
          }
        ];
        treefmt = {
          programs = {
            actionlint.enable = true;
            deadnix.enable = true;
            gofumpt = {
              enable = true;
              includes = [ "modules/portfolio/src/**/*.go" ];
            };
            keep-sorted = {
              enable = true;
              excludes = [ "*.go" ];
            };
            nixfmt.enable = true;
            shellcheck = {
              enable = true;
              excludes = [ ".envrc" ];
            };
            shfmt.enable = true;
            statix.enable = true;
            templ.enable = true;
            typstyle.enable = true;
            yamlfmt.enable = true;
          };
          settings.excludes = [ "*/hardware_configuration.nix" ];
        };
      };
    };
}
