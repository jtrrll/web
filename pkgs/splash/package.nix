{
  lib,
  lolcat,
  uutils-coreutils-noprefix,
  writeShellApplication,
}:
(writeShellApplication {
  meta = {
    description = "Prints a splash screen";
    mainProgram = "splash";
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
  name = "splash";
  runtimeInputs = [
    lolcat
    uutils-coreutils-noprefix
  ];
  text = ''
    printf "┬ ┬┌─┐┌┐
    │││├┤ ├┴┐
    └┴┘└─┘└─┘\n" | lolcat
  '';
}).overrideAttrs
  { version = "0.0.0"; }
