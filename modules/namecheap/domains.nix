_: {
  config.perSystem =
    { pkgs, ... }:
    {
      config.terranix.terranixConfigurations.namecheap-tf = {
        workdir = ".terraform/namecheap";
        terraformWrapper.package = pkgs.opentofu.withPlugins (p: [ p.namecheap_namecheap ]);
        modules = [
          {
            terraform.required_providers.namecheap = {
              source = "namecheap/namecheap";
              version = "~> 2.0";
            };

            provider.namecheap = {
              user_name = "\${var.namecheap_user}";
              api_user = "\${var.namecheap_user}";
              api_key = "\${var.namecheap_api_key}";
            };

            variable.namecheap_user = {
              type = "string";
              description = "Namecheap account username";
            };

            variable.namecheap_api_key = {
              type = "string";
              sensitive = true;
              description = "Namecheap API key";
            };

            resource.namecheap_domain_records.jtrrll_com = {
              domain = "jtrrll.com";
              mode = "OVERWRITE";

              record = [
                {
                  hostname = "@";
                  type = "A";
                  address = "5.161.233.216";
                }
                {
                  hostname = "*";
                  type = "A";
                  address = "5.161.233.216";
                }
              ];
            };

            resource.namecheap_domain_records.jacksonterrill_com = {
              domain = "jacksonterrill.com";
              mode = "OVERWRITE";

              record = [
                {
                  hostname = "@";
                  type = "A";
                  address = "5.161.233.216";
                }
                {
                  hostname = "*";
                  type = "A";
                  address = "5.161.233.216";
                }
              ];
            };
          }
        ];
      };
    };
}
