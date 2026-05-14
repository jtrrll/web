{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [ inputs.flake-parts.flakeModules.modules ];

  config.flake =
    let
      modulesFromDirectory =
        let
          nameFn = lib.replaceStrings [ "_" ] [ "-" ];
          importFn = dir: { imports = [ (inputs.import-tree dir) ]; };
        in
        dir:
        lib.concatMapAttrs (
          name: type:
          if type == "directory" then
            {
              "${nameFn name}" = importFn "${dir}/${name}";
            }
          else
            { }
        ) (builtins.readDir dir);
    in
    {
      nixosModules = lib.mapAttrs (_: module: {
        imports = [ module ];
        meta = {
          inherit (config.flake.meta) maintainers;
        };
      }) (config.flake.modules.nixos // (modulesFromDirectory ./by_name));
    };
}
