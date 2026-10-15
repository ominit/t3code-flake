{
  inputs,
  lib,
  self,
  ...
}: {
  perSystem = {
    pkgs,
    self',
    system,
    ...
  }: let
    packages = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") self'.packages;

    headlessCli = package:
      pkgs.runCommand "${package.name}-headless-cli" {nativeBuildInputs = [package];} ''
        t3 --version | grep -F "t3 v"
        t3 serve --help | grep -F "Run the T3 Code server without opening a browser"
        touch "$out"
      '';

    testSystem = inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        self.nixosModules.default
        {services.t3code.enable = true;}
      ];
    };
  in {
    checks =
      packages
      // {
        headless-cli = headlessCli self'.packages.t3code;
        headless-cli-nightly = headlessCli self'.packages.t3code-nightly;

        nixos-module = pkgs.writeText "t3code-nixos-module.json" (builtins.toJSON {
          inherit (testSystem.config.systemd.services.t3code.serviceConfig) ExecStart User Group;
          inherit (testSystem.config.systemd.services.t3code.environment) T3CODE_HOME;
        });
      };
  };
}
