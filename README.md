# T3 Code flake

Nix packages and a NixOS module for [T3 Code](https://t3.codes/). A GitHub Action tracks new T3 Code releases and updates the packaged source.

## Packages

The flake provides four packages:

- `t3code`
- `t3code-appimage`
- `t3code-with-codex`
- `t3code-appimage-with-codex`

Use `t3code` unless you need the original AppImage wrapper. The `-with-codex` packages add nixpkgs' `codex` package to `PATH`.

Add the flake to your inputs:

```nix
t3code = {
  url = "github:ominit/t3code-flake";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

```nix
inputs.t3code.packages."${pkgs.system}".t3code
```

## NixOS service

`nixosModules.default` runs the bundled T3 Code server as a systemd service. The server listens on loopback by default. Add provider CLIs and other tools to its `PATH` with `extraPackages`.

```nix
{
  inputs.t3code.url = "github:ominit/t3code-flake";

  outputs = {nixpkgs, t3code, ...}: {
    nixosConfigurations.server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        t3code.nixosModules.default
        ({pkgs, ...}: {
          services.t3code.enable = true;
          services.t3code.extraPackages = [pkgs.codex];
        })
      ];
    };
  };
}
```

Read the initial pairing URL from `journalctl -u t3code`.

For remote access, leave the server bound to loopback and put it behind a TLS reverse proxy. Tailscale Serve also works:

```nix
services.t3code = {
  extraPackages = [pkgs.tailscale];
  extraArgs = ["--tailscale-serve"];
};
```

By default, the service runs as a dedicated `t3code` user and can only access repositories readable by that account. To work with repositories owned by an existing user, run the service as that user:

```nix
services.t3code = {
  user = "alice";
  group = "users";
  createUser = false;
  dataDir = "/home/alice/.t3";
};
```

Create a custom data directory with the correct ownership before starting the service. Add provider CLIs with `services.t3code.extraPackages` and supply credentials through `services.t3code.environmentFile`.
