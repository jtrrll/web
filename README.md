# web

<!-- markdownlint-disable MD013 -->
![CI Status](https://img.shields.io/github/actions/workflow/status/jtrrll/web/ci.yaml?branch=main&label=ci&logo=github)
![License](https://img.shields.io/github/license/jtrrll/web?label=license&logo=googledocs&logoColor=white)
<!-- markdownlint-enable MD013 -->

jtrrll's personal corner of the web.
Managed via [Nix](https://nixos.org/).

## Table of Contents

- [Development Shells](#development-shells)
- [Setting Up a New Server](#setting-up-a-new-server)
- [Updating a Server](#updating-a-server)
- [Adding Secrets to a Server](#adding-secrets-to-a-server)
- [Infrastructure](#infrastructure)
  - [Hetzner](#hetzner)
  - [GitHub](#github)
  - [Namecheap](#namecheap)

## Development Shells

- `default` — `nix develop .#default`
- `github-tf` — `nix develop .#github-tf`
- `hetzner-tf` — `nix develop .#hetzner-tf`
- `namecheap-tf` — `nix develop .#namecheap-tf`
- `nixos` — `nix develop .#nixos`
- `portfolio` — `nix develop .#portfolio`

## Setting Up a New Server

New servers are provisioned with [nixos-anywhere](https://github.com/nix-community/nixos-anywhere).
This installs NixOS on a server that is reachable via SSH (e.g., a fresh VPS booted into a rescue system or any Linux install with root access).

```sh
nix run github:nix-community/nixos-anywhere -- --flake .#<hostname> root@<ip> --generate-hardware-config nixos-generate-config ./modules/servers/<hostname>/hardware-configuration.nix
```

Disko defines the disk layout and will be applied automatically.
After installation, the server reboots into NixOS with the specified configuration.

## Updating a Server

Configuration changes are applied via `nixos-rebuild switch` over SSH.
The deploy workflow runs automatically on push to `main` and can also be triggered manually.

### Using the deploy script

```sh
nix run .#deploy
```

This presents an interactive list of deployments to choose from.
To deploy a specific deployment directly:

```sh
nix run .#deploy -- <deployment>
```

## Adding Secrets to a Server

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) using age encryption derived from each server's SSH host key.

### 1. Get the server's age public key

```sh
ssh-keyscan -p 2222 <server-ip> 2>/dev/null | grep ed25519 | ssh-to-age
```

### 2. Add the key to `.sops.yaml`

```yaml
keys:
  - &<hostname> <age-public-key>
creation_rules:
  - path_regex: modules/servers/<hostname>_secrets\.yaml$
    key_groups:
      - age:
        - *<hostname>
```

### 3. Create or edit the encrypted secrets file

```sh
sops modules/servers/<hostname>_secrets.yaml
```

This opens an editor where you enter secrets in plaintext.
On save, sops encrypts the file with the server's public key.
Commit the encrypted file to the repository.

### 4. Reference secrets in NixOS config

```nix
sops.secrets.my_secret.owner = "service-user";
```

The decrypted secret is available at `config.sops.secrets.my_secret.path`.

## Infrastructure

Infrastructure is managed with [terranix](https://terranix.org/) (Terraform via Nix).
Resources are defined in `modules/hetzner/`, `modules/github/`, `modules/namecheap/`, and `modules/servers/`.
State is managed locally.

### Hetzner

Manages cloud servers, SSH keys, and networking.

```sh
nix run .#hetzner-tf -- init
nix run .#hetzner-tf -- plan
nix run .#hetzner-tf -- apply
```

To import an existing server into state:

```sh
nix run .#hetzner-tf -- import hcloud_server.<name> <server-id>
nix run .#hetzner-tf -- import hcloud_ssh_key.<name> <key-id>
```

### GitHub

Manages repository settings, branch protection, and secrets.

```sh
nix run .#github-tf -- init
nix run .#github-tf -- plan
nix run .#github-tf -- apply
```

To import the existing repository into state:

```sh
nix run .#github-tf -- import github_repository.web web
nix run .#github-tf -- import github_branch_protection.main web:main
```

### Namecheap

Manages DNS records for `jtrrll.com` and `jacksonterrill.com`.

```sh
nix run .#namecheap-tf -- init
nix run .#namecheap-tf -- plan
nix run .#namecheap-tf -- apply
```

> **Warning:** Namecheap uses `mode = "OVERWRITE"`, which replaces all DNS records for a domain.
> Ensure all records are defined in the config before applying.

Requires `TF_VAR_namecheap_user` and `TF_VAR_namecheap_api_key`.
API access must be enabled in the Namecheap dashboard with your IP whitelisted.
