_: {
  config.perSystem =
    {
      pkgs,
      self',
      ...
    }:
    {
      config.devenv.shells.portfolio = _: {
        scripts = {
          build-assets.exec =
            let
              assetDir = "pkgs/portfolio/src/cmd/server/static";
            in
            ''
              cp --force "$(nix build --no-link --print-out-paths .#preflight)" ${assetDir}/preflight.css
              cp --force "$(nix build --no-link --print-out-paths .#resume)" ${assetDir}/jackson_terrill_resume.pdf
            '';
          dev.exec = ''
            build-assets
            cd pkgs/portfolio/src
            templ generate --watch --cmd="go run -tags dev ./cmd/server"
          '';
        };

        languages = {
          go = {
            enable = true;
            package = self'.packages.portfolio.go;
          };
          nix.enable = true;
          typst = {
            enable = true;
            package = self'.packages.resume.typst;
          };
        };

        packages = [
          self'.packages.portfolio.templ
          pkgs.woff2
        ];

        env.OTEL_EXPORTER_OTLP_INSECURE = "true";

        services.opentelemetry-collector = {
          enable = true;
          settings = {
            receivers.otlp.protocols.grpc.endpoint = "localhost:4317";
            exporters.debug.verbosity = "detailed";
            service.pipelines = {
              traces = {
                receivers = [ "otlp" ];
                exporters = [ "debug" ];
              };
              metrics = {
                receivers = [ "otlp" ];
                exporters = [ "debug" ];
              };
              logs = {
                receivers = [ "otlp" ];
                exporters = [ "debug" ];
              };
            };
          };
        };
      };
    };
}
