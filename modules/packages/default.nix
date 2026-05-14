{ config, ... }:
{
  config.perSystem =
    {
      lib,
      pkgs,
      ...
    }:
    let
      addCommonMetadata = lib.addMetaAttrs {
        inherit (config.flake.meta) homepage maintainers;
        license = lib.licenses.agpl3Plus;
      };
      packagesFromDirectory =
        let
          nameFn = lib.replaceStrings [ "_" ] [ "-" ];
          importFn = lib.flip pkgs.callPackage { };
        in
        directory:
        lib.concatMapAttrs (
          name: type:
          let
            path = directory + "/${name}";
          in
          if type == "directory" then
            { "${nameFn name}" = importFn (path + "/package.nix"); }
          else if type == "regular" && lib.hasSuffix ".nix" name then
            { "${nameFn (lib.removeSuffix ".nix" name)}" = importFn path; }
          else
            { }
        ) (builtins.readDir directory);
      packages = lib.mapAttrs (_: addCommonMetadata) (packagesFromDirectory ./by_name);
    in
    {
      config = {
        inherit packages;
        devenv.modules = [ { overlays = [ (_: _: packages) ]; } ];
      };
    };
}
