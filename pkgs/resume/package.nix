{
  ibm-plex,
  lib,
  stdenvNoCC,
  typst,
}:
let
  typstWithPackages = typst.withPackages (typstPkgs: with typstPkgs; [ basic-resume_0_2_9 ]);
in
stdenvNoCC.mkDerivation {
  pname = "resume";
  version = "0.0.0";
  src = ./resume.typ;
  nativeBuildInputs = [
    ibm-plex
    typstWithPackages
  ];

  meta = {
    description = "Jackson Terrill's resume";
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
  passthru.typst = typstWithPackages;

  dontUnpack = true;
  buildPhase = ''
    typst compile --font-path ${ibm-plex} $src resume.pdf
  '';
  installPhase = ''
    cp resume.pdf $out
  '';
}
