{ config, lib, options, wrapperManagerLib, ... }:

let
  systemdUtils = wrapperManagerLib.systemd;
  cfg = config.programs.systemd;
  envConfig = config;

  mkSystemdDescription = unitType: typeDir: ''
    Set of systemd ${unitType} units to be placed in
    {file}`$out/etc/systemd/${typeDir}/$UNITNAME` as described
    from {manpage}`systemd.${unitType}(5)`.
  '';

  sharedExecConfig = {
    config = {
      enableStrictShellChecks = lib.mkOptionDefault cfg.enableStrictShellChecks;
      enableCommonDependencies = lib.mkOptionDefault cfg.enableCommonDependencies;

      # We're adding them with `mkBefore` assuming the user most likely
      # wants them anyways.
      environment = lib.mkMerge [
        cfg.environment

        (lib.mkIf cfg.enableCommonPathFromEnvironment {
          PATH =
            lib.mkIf cfg.enableCommonPathFromEnvironment
              (lib.mkBefore envConfig.environment.pathAdd + ":");
        })
      ];
    };
  };

  sharedUnitConfig = {
    config = {
      enableStatelessInstallation = lib.mkDefault cfg.enableStatelessInstallation;
    };
  };
in
{
  imports = [
    ./wrappers-integration.nix
  ];

  options.programs.systemd = {
    environment = lib.mkOption {
      type =
        with lib.types;
        attrsOf (
          nullOr (oneOf [
            str
            path
            package
          ])
        );
      default = { };
      example = {
        TZ = "CET";
      };
      description = ''
        Environment variables passed to all systemd service and socket units.
      '';
    };

    enableStrictShellChecks = lib.mkEnableOption null // {
      description = ''
        Whether to run `shellcheck` on all of the generated scripts defined in systemd.
      '';
      default = true;
      example = false;
    };

    enableStatelessInstallation = lib.mkEnableOption null // {
      description = ''
        Whether to enable stateless installation of the systemd units into
        their proper place. This involves the generated units within the
        derivation to be placed within additional folder structure.

        So far, this is only based from several install unit options (e.g.,
        `requiredBy`, `wantedBy`, `upheldBy`, and `aliases`).
      '';
    };

    enableCommonDependencies = lib.mkEnableOption null // {
      description = ''
        Whether to install additional dependencies on the generated scripts of
        systemd services.

        These dependencies are simply additional GNU utilities such as
        `coreutils`, `findutils`, `grep`, and `sed`.
      '';
      default = false;
      example = true;
    };

    enableCommonPathFromEnvironment =
      lib.mkEnableOption "include paths from {option}`environment.pathAdd`";

    enableInheritEnvironmentVariables =
      lib.mkEnableOption "include environment variables from {option}`environment.variables`";

    system = let
      mkSystemUnitDefinition = unitTypeSingular:
        lib.mkOption {
          description = mkSystemdDescription unitTypeSingular "system";
          default = { };
        };
    in {
      units = lib.mkOption {
        description = ''
          systemd units definition as described from
          {manpage}`systemd.unit(5)`.
        '';
        default = { };
        type = with lib.types; attrsOf (submodule (
          systemdUtils.submodules.units
          ++ [ sharedUnitConfig ]
        ));
      };

      services = mkSystemUnitDefinition "service" // {
        example = lib.literalExpression ''
          {
            hello = {
              description = "wrapper-manager systemd service example";
              path = with pkgs; [ hello ];
              script = "hello";
              startAt = "weekly";
            };

            nix-daemon = {
              description = "Fake Nix daemon build";
              documentation = [
                "man:nix-daemon"
                "https://nixos.org/manual"
              ];
              unitConfig = {
                RequireMountsFor = [
                  "/nix/store"
                  "/nix/var"
                  "/nix/var/nix/db"
                ];
              };
              serviceConfig = {
                ExecStart = "@''${lib.getExe' pkgs.nix "nix-daemon"} nix-daemon --daemon";
                KillMode = "process";
                LimitNOFILE = 1048576;
                TasksMax = 1048576;
                Delegate = "yes";
              };
              wantedBy = [ "multi-user.target" ];
            };
          }
        '';
        type = with lib.types; attrsOf (submodule
          (systemdUtils.submodules.services
          ++ [ sharedUnitConfig sharedExecConfig ])
        );
      };

      timers = mkSystemUnitDefinition "timer" // {
        type = with lib.types; attrsOf (submodule (
          systemdUtils.submodules.timers
          ++ [ sharedUnitConfig ]
        ));
        example = lib.literalExpression ''
          {
            hello = {
              description = "Get an automated message from a script";
              documentation = [
                "man:hello"
              ];
              timerConfig = {
                OnBootSec = "10m";
                OnCalendar = "weekly";
              };
              wantedBy = [ "timers.target" ];
            };
          }
        '';
      };

      targets = mkSystemUnitDefinition "target" // {
        type = with lib.types; attrsOf (submodule (
          systemdUtils.submodules.targets
          ++ [ sharedUnitConfig ]
        ));
      };

      sockets = mkSystemUnitDefinition "socket" // {
        type = with lib.types; attrsOf (submodule
          (systemdUtils.submodules.sockets
          ++ [ sharedExecConfig sharedUnitConfig ])
        );
      };

      mounts = mkSystemUnitDefinition "mount" // {
        type = with lib.types; attrsOf (submodule (
          systemdUtils.submodules.mounts
          ++ [ sharedUnitConfig ]
        ));
      };

      automounts = mkSystemUnitDefinition "automount" // {
        type = with lib.types; attrsOf (submodule (
          systemdUtils.submodules.automounts
          ++ [ sharedUnitConfig ]
        ));
      };

      slices = mkSystemUnitDefinition "slice" // {
        type = with lib.types; attrsOf (submodule (
          systemdUtils.submodules.slices
          ++ [ sharedUnitConfig ]
        ));
      };

      paths = mkSystemUnitDefinition "path" // {
        type = with lib.types; attrsOf (submodule (
          systemdUtils.submodules.paths
          ++ [ sharedUnitConfig ]
        ));
      };
    };

    # This is acceptable to just do it lazily like this. They don't have any
    # differences aside from the installation directory anyways.
    user = {
      units = options.programs.systemd.system.units;

      services = options.programs.systemd.system.services // {
        description = mkSystemdDescription "service" "user";
      };

      timers = options.programs.systemd.system.timers // {
        description = mkSystemdDescription "timer" "user";
      };

      targets = options.programs.systemd.system.targets // {
        description = mkSystemdDescription "target" "user";
      };

      sockets = options.programs.systemd.system.sockets // {
        description = mkSystemdDescription "socket" "user";
      };

      paths = options.programs.systemd.system.paths // {
        description = mkSystemdDescription "path" "user";
      };

      automounts = options.programs.systemd.system.automounts // {
        description = mkSystemdDescription "automount" "user";
      };

      mounts = options.programs.systemd.system.mounts // {
        description = mkSystemdDescription "mount" "user";
      };

      slices = options.programs.systemd.system.slices // {
        description = mkSystemdDescription "slice" "user";
      };
    };
  };

  config = let
    addTimerUnitByServicesWithStartAt = services:
      let
        validServices = lib.filterAttrs (_: v: v.startAt != [ ]) services;
      in
        lib.mapAttrs (_: v: {
          wantedBy = [ "timers.target" ];
          timerConfig.OnCalendar = v.startAt;
        }) validServices;

    collectSystemdUnits = ns:
      let
        inherit (systemdUtils) intoUnit;
        mkUnit = n: v: lib.nameValuePair v.filename (intoUnit v);
      in
        # The programmer in you might scream but take note that every thing in
        # each of the attrset here can have the same unit name so we're
        # manually combining them instead.
        lib.mapAttrs' mkUnit ns.services
        // lib.mapAttrs' mkUnit ns.timers
        // lib.mapAttrs' mkUnit ns.targets
        // lib.mapAttrs' mkUnit ns.sockets
        // lib.mapAttrs' mkUnit ns.slices
        // lib.mapAttrs' mkUnit ns.mounts
        // lib.mapAttrs' mkUnit ns.automounts
        // lib.mapAttrs' mkUnit ns.paths;
  in {
    programs.systemd.system.timers = addTimerUnitByServicesWithStartAt cfg.system.services;
    programs.systemd.user.timers = addTimerUnitByServicesWithStartAt cfg.user.services;

    programs.systemd.system.units = collectSystemdUnits cfg.system;
    programs.systemd.user.units = collectSystemdUnits cfg.user;

    files = lib.mkMerge [
      (lib.mkIf (cfg.system.units != { }) {
        "/etc/systemd/system".source = wrapperManagerLib.systemd.generateUnits { inherit (cfg.system) units; };
      })

      (lib.mkIf (cfg.user.units != { }) {
        "/etc/systemd/user".source = wrapperManagerLib.systemd.generateUnits { inherit (cfg.user) units; };
      })
    ];
  };
}
