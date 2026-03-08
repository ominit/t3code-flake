Flake for [T3 Code](https://t3.codes/)

The source is kept up to date via a Github Action.

There are two outputs: `t3code` and `t3code-appimage`.
They are both different ways of packaging the latest release.

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
