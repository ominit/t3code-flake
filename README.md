Flake for [T3 Code](https://t3.codes/)

The source is kept up to date via a Github Action.

There are four outputs:

- `t3code`
- `t3code-appimage`
- `t3code-with-codex`
- `t3code-appimage-with-codex`

They are different ways of packaging the latest release.
The `-with-codex` variants additionally include `codex` from [`github:numtide/llm-agents.nix#codex`](https://github.com/numtide/llm-agents.nix) on `PATH` at runtime.

You should most likely pick the `t3code` version.
The AppImage version exists primarily for compatibility reasons.

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

The flake exports `nixosModules.default`, which runs the bundled T3 Code server
headlessly under systemd. It listens on loopback by default. Provider CLIs and
other tools can be added to the service `PATH` with `extraPackages`.

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

Retrieve the initial pairing URL from `journalctl -u t3code`. For remote
access, keep the default loopback binding behind a TLS reverse proxy or use
Tailscale Serve:

```nix
services.t3code = {
  extraPackages = [pkgs.tailscale];
  extraArgs = ["--tailscale-serve"];
};
```

The default dedicated `t3code` user can only access repositories readable by
that account. To operate on repositories owned by an existing user:

```nix
services.t3code = {
  user = "alice";
  group = "users";
  createUser = false;
  dataDir = "/home/alice/.t3";
};
```

When using a custom data directory, create it with the appropriate ownership
before starting the service. Provider CLIs can be added with
`services.t3code.extraPackages`, and credentials can be supplied with
`services.t3code.environmentFile`.
