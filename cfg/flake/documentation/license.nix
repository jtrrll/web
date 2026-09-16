_: {
  config.perSystem =
    { pkgs, ... }:
    {
      config.files.file."LICENSE".source = pkgs.runCommand "LICENSE" { } ''
        cp ${./agpl_3.0.txt} $out
      '';
    };
}
