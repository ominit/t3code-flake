# t3code-flake

A Nix flake for [T3 Code](https://t3.codes/), a GUI and server for running coding agents. It packages the official Linux AppImage and includes a NixOS module for running the server as a systemd service.

Only x86_64-linux is supported.

## Packages

`t3code` is the default package. It extracts the AppImage and patches the binaries with `autoPatchelf`, so they run natively on NixOS. It provides two commands. `t3code` opens the desktop app and `t3` runs the headless server.

`t3code-appimage` wraps the unmodified upstream AppImage with nixpkgs' `appimageTools`. Use it as a fallback if the patched package breaks. It only provides `t3code`.

If `NIXOS_OZONE_WL` is set and you're in a Wayland session, the `t3code` desktop wrapper starts the app with native Wayland flags.

To try it without installing:

```sh
nix run github:ominit/t3code-flake
nix shell github:ominit/t3code-flake --command t3 serve
```

## Installation

Add the flake to your inputs:

```nix
t3code = {
  url = "github:ominit/t3code-flake";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then use the package:

```nix
inputs.t3code.packages.${pkgs.stdenv.hostPlatform.system}.t3code
```

## Running the server

`nixosModules.default` runs `t3 serve` as the `t3code` systemd service. By default it listens on `127.0.0.1:3773`, runs as a dedicated `t3code` system user and keeps its state in `/var/lib/t3code`.

The module adds nothing to the service's `PATH`. The server needs `git`, `openssh` if your repositories use SSH remotes, and your agent harness. Add them with `systemd.services.t3code.path`:

```nix
{pkgs, ...}: {
  services.t3code.enable = true;

  systemd.services.t3code.path = with pkgs; [
    git
    openssh
    # your agent harness
  ];
}
```

Once the service is running, find the pairing URL in its log:

```sh
journalctl -u t3code
```

### Options

All options live under `services.t3code`.

| Option | Default | Description |
| --- | --- | --- |
| `enable` | `false` | Run the server. |
| `package` | `t3code` from this flake | Package that provides `t3`. |
| `user` | `"t3code"` | User the server runs as. |
| `group` | `"t3code"` | Group the server runs as. |
| `createUser` | `true` | Create `user` and `group` as a system account. |
| `dataDir` | `"/var/lib/t3code"` | State, logs, secrets and worktrees. Also the service's `HOME` and `T3CODE_HOME`. |
| `host` | `"127.0.0.1"` | Listen address. |
| `port` | `3773` | Listen port. |
| `openFirewall` | `false` | Open `port` in the firewall. |
| `environment` | `{}` | Extra environment variables. |
| `environmentFile` | `null` | systemd environment file, for example with provider API keys. |
| `extraArgs` | `[]` | Extra arguments for `t3 serve`. |

### Remote access

Keep the server on loopback and reach it through a reverse proxy that terminates TLS, or let T3 Code publish itself on your tailnet with Tailscale Serve. Tailscale Serve needs the `tailscale` CLI on the service's `PATH`:

```nix
{pkgs, ...}: {
  services.tailscale.enable = true;

  services.t3code = {
    enable = true;
    extraArgs = ["--tailscale-serve"];
  };

  systemd.services.t3code.path = with pkgs; [git tailscale];
}
```

### Running as your own user

The `t3code` system user can't read repositories in your home directory. To give the agents access to them, run the service as your own account:

```nix
services.t3code = {
  enable = true;
  user = "alice";
  group = "users";
  createUser = false;
  dataDir = "/home/alice/t3code";
};

systemd.tmpfiles.rules = ["d /home/alice/t3code 0700 alice users -"];
```

The module only creates and manages the default `/var/lib/t3code`. A custom `dataDir` has to exist with the right owner before the service starts, which is what the tmpfiles rule above does.

The service sets `HOME` to `dataDir`. If the agents should use your normal git and SSH config, also set `services.t3code.environment.HOME = "/home/alice";`.

## Updates

A scheduled GitHub Action checks for new T3 Code releases every hour. When it finds one, it opens a pull request that updates `sources.json` and merges automatically. Run `nix flake update t3code` in your own flake to pick up the new version.

## License

The Nix code in this repository is MIT licensed. T3 Code itself is distributed under its own license.
