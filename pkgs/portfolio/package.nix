{
  buildGoModule,
  curl,
  git,
  go,
  lib,
  nix-gitignore,
  nix-update,
  preflight,
  resume,
  runCommand,
  templ,
  testers,
  versionCheckHook,
  writeShellApplication,
}:
buildGoModule (finalAttrs: {
  pname = "portfolio";
  version = "0.0.0";
  src = lib.cleanSource (nix-gitignore.gitignoreRecursiveSource [ ] ./src);
  vendorHash = "sha256-UABDY1dtEel9/eUBasEcZQIWB3FBMWXDA7znbPQY8as=";

  meta = {
    description = "Jackson Terrill's personal portfolio";
    mainProgram = "server";
    platforms = lib.platforms.all;
    license = lib.licenses.agpl3Plus;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
  passthru = {
    inherit preflight resume templ;
    # `src` is in-tree, so instead of tracking an upstream release we update
    # the Go module dependencies (go.mod/go.sum) and recompute `vendorHash`.
    updateScript = writeShellApplication {
      name = "update-portfolio";
      runtimeInputs = [
        git
        go
        nix-update
      ];
      text = ''
        root="$(git rev-parse --show-toplevel)"
        cd "$root/pkgs/portfolio/src"
        go get -u ./...
        go mod tidy
        cd "$root"
        nix-update --flake --version=skip portfolio
      '';
    };
    tests = {
      version = testers.testVersion { package = finalAttrs.finalPackage; };
      smoke =
        runCommand "portfolio-smoke-test"
          {
            nativeBuildInputs = [
              curl
              finalAttrs.finalPackage
            ];
          }
          ''
            server --port 8484 &
            SERVER_PID=$!
            sleep 1

            STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8484/api/health)
            kill $SERVER_PID

            if [ "$STATUS" != "200" ]; then
              echo "Health check failed with status $STATUS" >&2
              exit 1
            fi

            echo "Smoke test passed" > $out
          '';
    };
  };

  env.CGO_ENABLED = 0;

  nativeBuildInputs = [ templ ];
  preBuild = ''
    templ generate
    cp ${preflight} cmd/server/static/preflight.css
    cp ${resume} cmd/server/static/jackson_terrill_resume.pdf
  '';
  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
})
