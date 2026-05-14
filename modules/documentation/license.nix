{ inputs, ... }:
{
  imports = [ inputs.files.flakeModules.default ];

  config.perSystem =
    { pkgs, ... }:
    {
      config.files.files = [
        {
          path_ = "LICENSE";
          drv = pkgs.runCommand "LICENSE" { } ''
            cp ${./agpl-3.0.txt} $out
          '';
        }
      ];
    };
}
