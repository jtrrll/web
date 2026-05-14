{
  config,
  ...
}:
let
  flakeModule =
    {
      flake-parts-lib,
      ...
    }:
    {
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.packageQualityChecks;
        in
        {
          options.packageQualityChecks = {
            enable = lib.mkEnableOption "package quality checks";
            metadataChecks = lib.mkOption {
              type = lib.types.listOf lib.types.raw;
              default = [ ];
              description = "List of functions (meta -> { success: bool; error: nullable string; }) to validate package metadata";
            };
            packageChecks = lib.mkOption {
              type = lib.types.listOf lib.types.raw;
              default = [ ];
              description = "List of functions (package -> { success: bool; error: nullable string; }) to validate package attributes";
            };
            packages = lib.mkOption {
              type = lib.types.attrsOf lib.types.package;
              default = config.flake.packages;
              description = "The set of packages to check";
            };
          };

          config.checks.packageQuality = lib.mkIf cfg.enable (
            let
              checkPackage =
                _: pkg:
                let
                  meta = pkg.meta or { };
                  metaResults = lib.pipe cfg.metadataChecks [
                    (lib.map (check: check meta))
                    (lib.filter ({ success, ... }: !success))
                  ];
                  packageResults = lib.pipe cfg.packageChecks [
                    (lib.map (check: check pkg))
                    (lib.filter ({ success, ... }: !success))
                  ];
                  allFailures = metaResults ++ packageResults;
                in
                if lib.length allFailures == 0 then
                  {
                    success = true;
                    error = null;
                  }
                else
                  {
                    success = false;
                    error = ''
                      Package `${pkg.name or "unknown"}` failed the following quality checks:
                      ${lib.concatMapStringsSep "\n" ({ error, ... }: "  - ${error}") allFailures}
                    '';
                  };
              results = lib.mapAttrsToList checkPackage cfg.packages;
              failedPackages = lib.filter (result: !result.success) results;
            in
            pkgs.runCommand "check-package-quality" { } (
              let
                failedCount = lib.length failedPackages;
              in
              if failedCount > 0 then
                throw "\n${toString failedCount} package(s) failed quality validation:\n${
                  lib.concatMapStringsSep "\n" (result: result.error) failedPackages
                }"
              else
                "echo 'All packages passed quality validation' > $out"
            )
          );
        }
      );
    };

  semverPattern = "([0-9]+)\\.([0-9]+)\\.([0-9]+)(-[a-zA-Z0-9.]+)?(\\+[a-zA-Z0-9.]+)?";
in
{
  imports = [
    { config.flake.modules.flake.packageQualityChecks = flakeModule; }
    flakeModule
  ];

  config.perSystem =
    let
      inherit (config.flake.meta) homepage;
    in
    {
      config,
      lib,
      ...
    }:
    {
      config.packageQualityChecks = {
        enable = true;
        metadataChecks = [
          (
            meta:
            if meta ? description then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "A description must be set";
              }
          )
          (
            meta:
            if lib.hasPrefix (meta.name or "") (meta.description or "") then
              {
                success = false;
                error = "The description should not repeat the package name";
              }
            else
              {
                success = true;
                error = null;
              }
          )
          (
            meta:
            if
              lib.substring 0 1 (meta.description or "")
              == lib.toUpper (lib.substring 0 1 (meta.description or ""))
            then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "The first word of the description should be capitalized";
              }
          )
          (
            meta:
            if lib.hasInfix "\n" (meta.description or "") then
              {
                success = false;
                error = "The description should not contain newlines";
              }
            else
              {
                success = true;
                error = null;
              }
          )
          (
            meta:
            if lib.hasSuffix "." (meta.description or "") then
              {
                success = false;
                error = "The description should not end with punctuation";
              }
            else
              {
                success = true;
                error = null;
              }
          )
          (
            meta:
            if meta ? homepage then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "A homepage must be set";
              }
          )
          (
            meta:
            if (meta.homepage or "") == homepage then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "The homepage must be ${homepage}";
              }
          )
          (
            meta:
            if meta ? license then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "A license must be set";
              }
          )
          (
            meta:
            if meta.license.free or false then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "The license must be free";
              }
          )
          (
            meta:
            if meta ? maintainers then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "The maintainers must be set";
              }
          )
          (
            meta:
            if lib.isList (meta.maintainers or [ ]) then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "The maintainers must be a list";
              }
          )
          (
            meta:
            if (lib.length (meta.maintainers or [ ])) > 0 then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "At least one maintainer must be set";
              }
          )
          (
            meta:
            if meta ? platforms then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "The supported platforms must be set";
              }
          )
          (
            meta:
            if lib.isList (meta.platforms or [ ]) then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "The supported platforms must be a list";
              }
          )
          (
            meta:
            if (lib.length (meta.platforms or [ ])) > 0 then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "The supported platforms must not be empty";
              }
          )
        ];
        packageChecks = [
          (
            pkg:
            if (pkg.version or "") != "" then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "A version must be set";
              }
          )
          (
            pkg:
            if builtins.match semverPattern (pkg.version or "0.0.0") != null then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "The version must follow semver (got: ${pkg.version or ""})";
              }
          )
          (
            pkg:
            if pkg.doCheck or true then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "doCheck must not be disabled";
              }
          )
          (
            pkg:
            if pkg.doInstallCheck or true then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "doInstallCheck must not be disabled";
              }
          )
        ];
        packages = lib.filterAttrs (
          name: _:
          !lib.hasInfix "devenv" name
          && !lib.elem name [
            "github-tf"
            "hetzner-tf"
            "namecheap-tf"
            "preflight"
            "resume"
            "splash"
          ]
        ) config.packages;
      };
    };
}
