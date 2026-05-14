{ inputs, ... }:
let
  flakeModule =
    {
      config,
      flake-parts-lib,
      ...
    }:
    let
      flakeConfig = config;
    in
    {
      options.perSystem = flake-parts-lib.mkPerSystemOption (
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.nixosModuleQualityChecks;
        in
        {
          options.nixosModuleQualityChecks = {
            enable = lib.mkEnableOption "NixOS module quality checks";
            nixosModules = lib.mkOption {
              type = lib.types.attrsOf lib.types.raw;
              default = flakeConfig.flake.nixosModules;
              description = "The NixOS modules to validate";
            };
            checks = lib.mkOption {
              type = lib.types.listOf lib.types.raw;
              default = [ ];
              description = "List of functions (option -> { success: bool; error: nullable string; }) to validate NixOS module options";
            };
            optionPaths = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Option path prefixes to check (e.g., [\"services.portfolio\" \"adminUser\"])";
            };
          };

          config.checks.nixosModuleQuality = lib.mkIf cfg.enable (
            let
              evaluatedOptions =
                let
                  fakeSystem = inputs.nixpkgs-nixos.lib.nixosSystem {
                    modules = lib.attrValues cfg.nixosModules ++ [
                      { nixpkgs.hostPlatform = "x86_64-linux"; }
                    ];
                  };
                in
                fakeSystem.options;

              collectOptions =
                prefix: opts:
                lib.concatLists (
                  lib.mapAttrsToList (
                    name: opt:
                    let
                      path = prefix ++ [ name ];
                      pathStr = lib.concatStringsSep "." path;
                    in
                    if opt ? _type && opt._type == "option" then
                      [
                        {
                          inherit path pathStr;
                          option = opt;
                        }
                      ]
                    else if lib.isAttrs opt then
                      collectOptions path opt
                    else
                      [ ]
                  ) opts
                );

              isOurOption = optEntry: lib.any (p: lib.hasPrefix p optEntry.pathStr) cfg.optionPaths;

              allOptions = collectOptions [ ] evaluatedOptions;
              ourOptions = lib.filter isOurOption allOptions;

              checkOption =
                optEntry:
                let
                  results = lib.pipe cfg.checks [
                    (lib.map (check: check optEntry))
                    (lib.filter ({ success, ... }: !success))
                  ];
                in
                {
                  inherit (optEntry) pathStr;
                  success = lib.length results == 0;
                  errors = lib.map ({ error, ... }: error) results;
                };

              results = lib.map checkOption ourOptions;
              failedOptions = lib.filter (r: !r.success) results;
            in
            pkgs.runCommand "check-nixos-module-quality" { } (
              let
                failedCount = lib.length failedOptions;
                errorMessages = lib.concatMapStringsSep "\n" (
                  r: lib.concatMapStringsSep "\n" (e: "  - ${e}") r.errors
                ) failedOptions;
              in
              if failedCount > 0 then
                throw "\n${toString failedCount} option(s) failed quality validation:\n${errorMessages}"
              else
                "echo 'All NixOS module options passed quality validation' > $out"
            )
          );
        }
      );
    };
in
{
  imports = [
    { config.flake.modules.flake.nixosModuleQualityChecks = flakeModule; }
    flakeModule
  ];

  config.perSystem =
    { lib, ... }:
    {
      config.nixosModuleQualityChecks = {
        enable = true;
        optionPaths = [
          "adminUser"
          "services.portfolio"
        ];
        checks = [
          (
            { option, pathStr, ... }:
            if (option.description or null) != null then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "Option `${pathStr}` must have a description";
              }
          )
          (
            { option, pathStr, ... }:
            if option ? type then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "Option `${pathStr}` must have a type";
              }
          )
          (
            { option, pathStr, ... }:
            if option ? default then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "Option `${pathStr}` must have a default value";
              }
          )
          (
            { option, pathStr, ... }:
            if option ? example then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "Option `${pathStr}` must have an example";
              }
          )
          (
            { option, pathStr, ... }:
            let
              isReadOnly = option.readOnly or false;
              hasDefault = option ? default;
            in
            if !isReadOnly || !hasDefault then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "ReadOnly option `${pathStr}` must not have a default";
              }
          )
          (
            { option, pathStr, ... }:
            let
              isEnable = lib.hasSuffix ".enable" pathStr;
              hasDefault = option ? default;
            in
            if !isEnable || (hasDefault && !option.default) then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "Enable option `${pathStr}` must default to false";
              }
          )
          (
            { option, pathStr, ... }:
            let
              isInternal = option.internal or false;
              isVisible = option.visible or true;
            in
            if !isInternal || !isVisible then
              {
                success = true;
                error = null;
              }
            else
              {
                success = false;
                error = "Internal option `${pathStr}` must have visible = false";
              }
          )
        ];
      };
    };
}
