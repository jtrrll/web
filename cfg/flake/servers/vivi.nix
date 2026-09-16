_: {
  config.perSystem = _: {
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
}
