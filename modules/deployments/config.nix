{ config, ... }:
{
  config.flake.deployments.production = [
    {
      nixosConfiguration = config.flake.nixosConfigurations.vivi;
      ipAddress = "5.161.233.216";
    }
  ];
}
