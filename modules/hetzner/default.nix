_: {
  config.perSystem =
    { pkgs, ... }:
    {
      config.terranix.terranixConfigurations.hetzner-tf = {
        workdir = ".terraform/hetzner";
        terraformWrapper.package = pkgs.opentofu.withPlugins (p: [ p.hetznercloud_hcloud ]);
        modules = [
          {
            terraform.required_providers.hcloud = {
              source = "hetznercloud/hcloud";
              version = "~> 1.45";
            };

            provider.hcloud = {
              token = "\${var.hcloud_token}";
            };

            variable.hcloud_token = {
              type = "string";
              sensitive = true;
              description = "Hetzner Cloud API token";
            };

            resource.hcloud_ssh_key.admin = {
              name = "admin";
              public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHX3LNsvrkvZxKZPhtH5QFP++vZmjfoW4ZT4PVogrjJ8";
            };
          }
        ];
      };
    };
}
