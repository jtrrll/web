_: {
  config.perSystem =
    {
      pkgs,
      ...
    }:
    {
      config.packages.preflight = pkgs.callPackage (
        {
          fetchFromGitHub,
          lib,
          stdenvNoCC,
        }:
        let
          tailwindcss = fetchFromGitHub {
            owner = "tailwindlabs";
            repo = "tailwindcss";
            rev = "v4.1.14";
            hash = "sha256-BGySdbLTvZ40i4LMkyXv+aD79p050tD2r/s1G3tGMfc=";
          };
        in
        stdenvNoCC.mkDerivation {
          pname = "preflight";
          version = "4.1.14";

          dontUnpack = true;

          installPhase = ''
            cp ${tailwindcss}/packages/tailwindcss/preflight.css $out
          '';

          meta = {
            description = "Tailwind CSS preflight stylesheet";
            homepage = "https://tailwindcss.com";
            license = lib.licenses.mit;
            platforms = lib.platforms.all;
            sourceProvenance = [ lib.sourceTypes.fromSource ];
          };
        }
      ) { };
    };
}
