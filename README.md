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
