{
  pkgs,
  ...
}:
{
  packages = [
    pkgs.age
    pkgs.sops
    pkgs.ssh-to-age
  ];
}
