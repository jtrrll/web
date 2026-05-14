{
  config,
  lib,
  ...
}:
let
  cfg = config.adminUser;
in
{
  options.adminUser = {
    enable = lib.mkEnableOption "admin user account";
  };

  config = lib.mkIf cfg.enable {
    nix.settings.trusted-users = [ "admin" ];
    security.sudo.wheelNeedsPassword = false;
    services.openssh.settings.AllowUsers = [ "admin" ];
    users.users.admin = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHX3LNsvrkvZxKZPhtH5QFP++vZmjfoW4ZT4PVogrjJ8"
      ];
    };
  };
}
