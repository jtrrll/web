_:
let
  flakeModule =
    {
      lib,
      ...
    }:
    {
      options.flake.meta = lib.mkOption {
        description = "Metadata for this flake";
        type = lib.types.submodule {
          freeformType = lib.types.attrsOf lib.types.anything;
          options = {
            homepage = lib.mkOption {
              description = "The homepage of this flake";
              type = lib.types.str;
            };
            maintainers = lib.mkOption {
              description = "The maintainers of this flake";
              type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
            };
          };
        };
      };
    };
in
{
  imports = [
    { config.flake.modules.flake.flakeMetadata = flakeModule; }
    flakeModule
  ];

  config.flake.meta = {
    homepage = "https://github.com/jtrrll/web";
    maintainers = [
      {
        github = "jtrrll";
        githubId = 77407057;
        name = "Jackson Terrill";
      }
    ];
  };
}
