_: {
  config.perSystem =
    {
      config,
      lib,
      ...
    }:
    {
      # The terranix `*-tf` wrappers are removed from `packages` (via touchup)
      # so they don't undergo package quality checks, but are still exposed as
      # apps so `nix run .#<name>-tf` keeps working.
      config.apps = lib.mapAttrs (_: tnixConfig: {
        type = "app";
        program = lib.getExe tnixConfig.result.app;
      }) config.terranix.terranixConfigurations;
    };
}
