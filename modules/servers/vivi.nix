{
  config,
  inputs,
  lib,
  ...
}:
{
  config = {
    perSystem = _: {
      config.terranix.terranixConfigurations.hetzner-tf.modules = [
        {
          resource.hcloud_server.vivi = {
            name = "vivi";
            server_type = "cpx11";
            location = "ash";
            image = "ubuntu-24.04";
            ssh_keys = [ "\${hcloud_ssh_key.admin.id}" ];

            lifecycle.ignore_changes = [
              "image"
              "ssh_keys"
            ];
          };

          output.vivi_ip = {
            value = "\${hcloud_server.vivi.ipv4_address}";
          };
        }
      ];
    };

    flake.nixosConfigurations.vivi = inputs.nixpkgs-nixos.lib.nixosSystem {
      modules =
        let
          disko = {
            disko.devices.disk.main = {
              type = "disk";
              device = "/dev/sda";
              content = {
                type = "gpt";
                partitions = {
                  boot = {
                    size = "1M";
                    type = "EF02";
                  };
                  swap = {
                    size = "2G";
                    content.type = "swap";
                  };
                  root = {
                    size = "100%";
                    content = {
                      type = "filesystem";
                      format = "ext4";
                      mountpoint = "/";
                    };
                  };
                };
              };
            };
          };
          hardwareConfiguration =
            { lib, modulesPath, ... }:
            {
              imports = [
                (modulesPath + "/profiles/qemu-guest.nix")
              ];

              boot = {
                initrd.availableKernelModules = [
                  "ahci"
                  "xhci_pci"
                  "virtio_pci"
                  "virtio_scsi"
                  "sd_mod"
                  "sr_mod"
                ];
                initrd.kernelModules = [ ];
                kernelModules = [ ];
                extraModulePackages = [ ];
              };

              networking.useDHCP = lib.mkDefault true;
              nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
            };
        in
        lib.attrValues config.flake.nixosModules
        ++ [
          inputs.determinate.nixosModules.default
          inputs.disko.nixosModules.disko
          inputs.sops-nix.nixosModules.sops
          disko
          hardwareConfiguration
          (
            { config, ... }:
            {
              networking.hostName = "vivi";

              sops = {
                defaultSopsFile = ./vivi_secrets.yaml;
                age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
                secrets.caddy_basic_auth_hash = { };
                templates."caddy.env" = {
                  owner = "caddy";
                  content = "CADDY_BASIC_AUTH_HASH=${config.sops.placeholder.caddy_basic_auth_hash}";
                };
              };

              boot.loader.grub = {
                enable = true;
                configurationLimit = 2;
              };

              adminUser.enable = true;

              services = {
                caddy = {
                  enable = true;
                  openFirewall = true;
                  environmentFile = config.sops.templates."caddy.env".path;

                  virtualHosts = {
                    "www.jtrrll.com".extraConfig = ''
                      reverse_proxy localhost:8080
                    '';

                    "jtrrll.com".extraConfig = ''
                      redir https://www.jtrrll.com{uri}
                    '';

                    "jacksonterrill.com".extraConfig = ''
                      redir https://www.jtrrll.com{uri}
                    '';

                    "www.jacksonterrill.com".extraConfig = ''
                      redir https://www.jtrrll.com{uri}
                    '';

                    "admin.jtrrll.com".extraConfig = ''
                      basic_auth {
                        admin {$CADDY_BASIC_AUTH_HASH}
                      }
                      reverse_proxy localhost:5678
                    '';
                  };
                };

                fail2ban = {
                  enable = true;
                  maxretry = 3;
                };

                openssh = {
                  enable = true;
                  ports = [ 2222 ];
                  settings = {
                    PasswordAuthentication = false;
                    KbdInteractiveAuthentication = false;
                    PermitRootLogin = "no";
                  };
                };

                glance = {
                  enable = true;
                  settings = {
                    server = {
                      port = 5678;
                      proxied = true;
                    };
                    pages = [
                      {
                        name = "Home";
                        columns = [
                          {
                            size = "full";
                            widgets = [
                              {
                                type = "server-stats";
                                servers = [
                                  {
                                    type = "local";
                                    name = config.networking.hostName;
                                  }
                                ];
                              }
                              {
                                type = "monitor";
                                cache = "1m";
                                title = "Services";
                                sites = [
                                  {
                                    title = "Portfolio";
                                    url = "https://www.jtrrll.com";
                                    icon = "si:globe";
                                  }
                                ];
                              }
                            ];
                          }
                        ];
                      }
                    ];
                  };
                };

                portfolio.enable = true;
              };

              system.stateVersion = "25.11";
            }
          )
        ];
    };
  };
}
