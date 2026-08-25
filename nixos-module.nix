{self}: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.t3code;
  defaultPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.t3code;
in {
  options.services.t3code = {
    enable = lib.mkEnableOption "the T3 Code headless server";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "inputs.t3code.packages.\${pkgs.system}.t3code";
      description = "T3 Code package containing the t3 headless launcher.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "t3code";
      description = "User under which the T3 Code server runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "t3code";
      description = "Group under which the T3 Code server runs.";
    };

    createUser = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to create the configured service user and group.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/t3code";
      description = "Directory containing T3 Code state, logs, secrets, and worktrees.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which the HTTP and WebSocket server listens.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3773;
      description = "Port on which the HTTP and WebSocket server listens.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the configured port in the firewall.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      example = lib.literalExpression "[ pkgs.claude-code pkgs.opencode ]";
      description = "Additional provider CLIs and tools added to the service PATH.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Environment variables for the T3 Code server.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/t3code.env";
      description = "Optional systemd environment file containing provider credentials.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["--tailscale-serve"];
      description = "Additional arguments passed to t3 serve.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups = lib.mkIf cfg.createUser {
      ${cfg.group} = {};
    };

    users.users = lib.mkIf cfg.createUser {
      ${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
        shell = pkgs.bashInteractive;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];

    systemd.services.t3code = {
      description = "T3 Code headless server";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      environment =
        {
          HOME = cfg.dataDir;
          T3CODE_HOME = cfg.dataDir;
        }
        // cfg.environment;

      path =
        [
          pkgs.bashInteractive
          pkgs.coreutils
          pkgs.git
          pkgs.openssh
        ]
        ++ cfg.extraPackages;

      serviceConfig =
        {
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.dataDir;
          ExecStart = lib.concatStringsSep " " (
            [
              "${cfg.package}/bin/t3"
              "serve"
              "--host"
              (lib.escapeShellArg cfg.host)
              "--port"
              (toString cfg.port)
            ]
            ++ map lib.escapeShellArg cfg.extraArgs
          );
          EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
          KillMode = "mixed";
          OOMPolicy = "continue";
          Restart = "always";
          RestartSec = 5;
          TimeoutStopSec = 90;
          UMask = "0077";
        }
        // lib.optionalAttrs (cfg.dataDir == "/var/lib/t3code") {
          StateDirectory = "t3code";
          StateDirectoryMode = "0750";
        };
    };
  };
}
