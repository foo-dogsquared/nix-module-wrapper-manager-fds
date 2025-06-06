{ pkgs, lib, self }:

let
  settingsFormat = self.formats.systemdIni { };

  inherit (self.systemd)
    assertValueOneOf
    checkUnitConfig
    makeJobScript
    unitNameType
    ;

  inherit (lib)
    any
    concatMap
    filterOverrides
    isList
    literalExpression
    mergeEqualOption
    mkIf
    mkMerge
    mkOption
    mkOptionType
    singleton
    toList
    types
    ;

  checkService = checkUnitConfig "Service" [
    (assertValueOneOf "Type" [
      "exec"
      "simple"
      "forking"
      "oneshot"
      "dbus"
      "notify"
      "notify-reload"
      "idle"
    ])
    (assertValueOneOf "Restart" [
      "no"
      "on-success"
      "on-failure"
      "on-abnormal"
      "on-abort"
      "always"
    ])
  ];

in
rec {

  unitOption = mkOptionType {
    name = "systemd option";
    merge =
      loc: defs:
      let
        defs' = filterOverrides defs;
      in
      if any (def: isList def.value) defs' then
        concatMap (def: toList def.value) defs'
      else
        mergeEqualOption loc defs';
  };

  # This is a baseline option set for the unit which is shared by ALL systemd
  # unit modules.
  sharedOptions = {
    name = lib.mkOption {
      type = lib.types.str;
      description = ''
        The name of this systemd unit, including its extension.
        This can be used to refer to this unit from other systemd units.
      '';
    };

    enableStatelessInstallation =
      lib.mkEnableOption "stateless setup of the systemd units in the derivation";

    # The filename can be different especially if it's a drop-in unit.
    filename = lib.mkOption {
      type = lib.types.str;
      description = ''
        The filename of the systemd unit. This should be preferred to refer to
        the file path in the resulting output path where it can generate
        systemd drop-in units.
      '';
    };

    # NOTE: I like having these options so we're keeping this.
    requiredBy = mkOption {
      default = [ ];
      type = types.listOf unitNameType;
      description = ''
        Units that require (i.e. depend on and need to go down with) this unit.
      '';
    };

    upheldBy = mkOption {
      default = [ ];
      type = types.listOf unitNameType;
      description = ''
        Keep this unit running as long as the listed units are running. This is a continuously
        enforced version of wantedBy.
      '';
    };

    wantedBy = mkOption {
      default = [ ];
      type = types.listOf unitNameType;
      description = ''
        Units that want (i.e. depend on) this unit. The default method for
        starting a unit by default at boot time is to set this option to
        `["multi-user.target"]` for system services. Likewise for user units
        (`programs.systemd.user.<name>.*`) set it to `["default.target"]` to make a unit
        start by default when the user `<name>` logs on.
      '';
    };

    aliases = mkOption {
      default = [ ];
      type = types.listOf unitNameType;
      description = "Aliases of that unit to be put under `Install.Alias=` directive.";
    };

    # This should be used sparingly outside of the official modules. Anyways,
    # the reason why this exists is because wrapper-manager can afford to have
    # this unlike NixOS maintainers that has to follow systemd's version within
    # NixOS channels. Not to mention, wrapper-manager can generate systemd
    # units for any target version of systemd where the module options can go
    # adrift compared to the user's target systemd version.
    #
    # Basically, this is an (ugly) escape hatch if ever the user's target
    # version is a mismatch from the module maintainer's target version AND
    # THERE'S REALLY REALLY REALLY REALLY NO WAY to configure the thing they
    # want.
    settings = mkOption {
      type = settingsFormat.type;
      default = { };
      description = ''
        The settings for the systemd unit.

        :::{.caution}
        This could be used to completely override settings associated with the
        rest of the unit module such as {option}`unitConfig` being associated
        with `settings.Unit` settings.

        Just use this only as a last resort if your target systemd version does
        not match with the module's target version AND there's no plausible way
        to set the unit directive you want.
        :::
      '';
    };
  };

  commonUnitOptions = { config, options, ... }: {
    options = sharedOptions // {
      description = mkOption {
        default = "";
        type = types.singleLineStr;
        description = "Description of this unit used in systemd messages and progress indicators.";
      };

      documentation = mkOption {
        default = [ ];
        type = types.listOf types.str;
        description = "A list of URIs referencing documentation for this unit or its configuration.";
      };

      requires = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          Start the specified units when this unit is started, and stop
          this unit when the specified units are stopped or fail.
        '';
      };

      wants = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          Start the specified units when this unit is started.
        '';
      };

      upholds = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          Keeps the specified running while this unit is running. A continuous version of `wants`.
        '';
      };

      after = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          If the specified units are started at the same time as
          this unit, delay this unit until they have started.
        '';
      };

      before = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          If the specified units are started at the same time as
          this unit, delay them until this unit has started.
        '';
      };

      bindsTo = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          Like ‘requires’, but in addition, if the specified units
          unexpectedly disappear, this unit will be stopped as well.
        '';
      };

      partOf = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          If the specified units are stopped or restarted, then this
          unit is stopped or restarted as well.
        '';
      };

      conflicts = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          If the specified units are started, then this unit is stopped
          and vice versa.
        '';
      };

      requisite = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          Similar to requires. However if the units listed are not started,
          they will not be started and the transaction will fail.
        '';
      };

      unitConfig = mkOption {
        default = { };
        example = {
          RequiresMountsFor = "/data";
        };
        type = types.attrsOf unitOption;
        description = ''
          Settings under `[Unit]` section of the unit.  See
          {manpage}`systemd.unit(5)` for details.
        '';
      };

      installConfig = mkOption {
        default = { };
        example = {
          WantedBy = [ "default.target" ];
        };
        type = types.attrsOf unitOption;
        description = ''
          Settings under `[Install]` section of the unit. See
          {manpage}`systemd.unit(5)` for details.
        '';
      };

      extraSectionsConfig = mkOption {
        default = { };
        example = literalExpression ''
          {
            "Custom Section" = {
              Hello = "there";
              AnotherCustomConfigSettings = builtins.toString [
                "SPACE"
                "DELIMITED"
                "VALUES"
              ];
            };

            "org.example.App" = {
              additional_search_path = lib.makeBinPath [
                "/root"
                "/usr"
                "/usr/local"
              ];
            };
          }
        '';
        type = types.attrsOf (types.attrsOf unitOption);
        description = ''
          Additional sections with their configuration to be included. Each of
          attribute's section name is prepended with `X-` in the unit file.

          :::{.note}
          Any sections prepended with `X-` is ignored by systemd and only meant
          to be used by third-party applications in getting those settings. See
          {manpage}`systemd.unit(5)` for more details.
          :::
        '';
      };

      onFailure = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          A list of one or more units that are activated when
          this unit enters the "failed" state.
        '';
      };

      onSuccess = mkOption {
        default = [ ];
        type = types.listOf unitNameType;
        description = ''
          A list of one or more units that are activated when
          this unit enters the "inactive" state.
        '';
      };

      startLimitBurst = mkOption {
        type = types.int;
        description = ''
          Configure unit start rate limiting. Units which are started
          more than startLimitBurst times within an interval time
          interval are not permitted to start any more.
        '';
      };

      startLimitIntervalSec = mkOption {
        type = types.int;
        description = ''
          Configure unit start rate limiting. Units which are started
          more than startLimitBurst times within an interval time
          interval are not permitted to start any more.
        '';
      };
    };

    config = {
      unitConfig =
        lib.optionalAttrs (config.requires != [ ]) { Requires = config.requires; }
        // lib.optionalAttrs (config.wants != [ ]) { Wants = config.wants; }
        // lib.optionalAttrs (config.upholds != [ ]) { Upholds = config.upholds; }
        // lib.optionalAttrs (config.after != [ ]) { After = config.after; }
        // lib.optionalAttrs (config.before != [ ]) { Before = config.before; }
        // lib.optionalAttrs (config.bindsTo != [ ]) { BindsTo = config.bindsTo; }
        // lib.optionalAttrs (config.partOf != [ ]) { PartOf = config.partOf; }
        // lib.optionalAttrs (config.conflicts != [ ]) { Conflicts = config.conflicts; }
        // lib.optionalAttrs (config.requisite != [ ]) { Requisite = config.requisite; }
        // lib.optionalAttrs (config.description != "") {
          Description = config.description;
        }
        // lib.optionalAttrs (config.documentation != [ ]) {
          Documentation = config.documentation;
        }
        // lib.optionalAttrs (config.onFailure != [ ]) {
          OnFailure = config.onFailure;
        }
        // lib.optionalAttrs (config.onSuccess != [ ]) {
          OnSuccess = config.onSuccess;
        }
        // lib.optionalAttrs (options.startLimitIntervalSec.isDefined) {
          StartLimitIntervalSec = toString config.startLimitIntervalSec;
        }
        // lib.optionalAttrs (options.startLimitBurst.isDefined) {
          StartLimitBurst = toString config.startLimitBurst;
        };

      installConfig =
        lib.optionalAttrs (config.wantedBy != [ ]) {
          WantedBy = config.wantedBy;
        }
        // lib.optionalAttrs (config.aliases != [ ]) {
          Alias = config.aliases;
        }
        // lib.optionalAttrs (config.requiredBy != [ ]) {
          RequiredBy = config.requiredBy;
        }
        // lib.optionalAttrs (config.upheldBy != [ ]) {
          UpheldBy = config.upheldBy;
        };

      settings = let
        inherit (config) unitConfig installConfig;
      in lib.mkMerge [
        (lib.mkIf (unitConfig != { }) { Unit = unitConfig; })
        (lib.mkIf (installConfig != { }) { Install = installConfig; })
        (lib.mapAttrs' (n: v: lib.nameValuePair "X-${n}" v) config.extraSectionsConfig)
      ];
    };
  };

  serviceOptions =
    { name, config, ... }:
    {
      imports = [ execOptions ];

      options = {
        serviceConfig = mkOption {
          default = { };
          example = {
            RestartSec = 5;
          };
          type = types.addCheck (types.attrsOf unitOption) checkService;
          description = ''
            Each attribute in this set specifies an option in the
            `[Service]` section of the unit.  See
            {manpage}`systemd.service(5)` for details.
          '';
        };

        startAt = mkOption {
          type = with types; either str (listOf str);
          default = [ ];
          example = "Sun 14:00:00";
          description = ''
          Automatically start this unit at the given date/time, which
          must be in the format described in
          {manpage}`systemd.time(7)`.  This is equivalent
          to adding a corresponding timer unit with
          {option}`OnCalendar` set to the value given here.
          '';
          apply = v: if isList v then v else [ v ];
        };

        listenOn = mkOption {
          type = with types; listOf str;
          default = [ ];
          example = [
            "0.0.0.0:993"
            "/run/my-socket"
          ];
          description = ''
            List of addresses to listen on. Each of the items will be included
            as part of `Socket.ListenStream=` directive of the corresponding
            socket unit. See {manpage}`systemd.socket(5)` for more details.
          '';
        };

        watchFilesFrom = mkOption {
          type = with types; listOf str;
          default = [ ];
          example = [
          ];
          description = ''
            List of file globs to monitor changes to the files. Each of the
            items will be included as part of the `Path.Modified=` directive as
            well as automatically create those directories with
            `Path.MakeDirectory=` set to true of the corresponding path unit.
            See {manpage}`systemd.path(5)` for more details.
          '';
        };

        script = mkOption {
          type = types.lines;
          default = "";
          description = "Shell commands executed as the service's main process.";
        };

        scriptArgs = mkOption {
          type = types.str;
          default = "";
          example = "%i";
          description = ''
            Arguments passed to the main process script.
            Can contain specifiers (`%` placeholders expanded by systemd, see {manpage}`systemd.unit(5)`).
          '';
        };

        reload = mkOption {
          type = types.lines;
          default = "";
          description = ''
            Shell commands executed when the service's main process
            is reloaded.
          '';
        };
      };

      config = mkMerge [
        {
          settings.Service = lib.mkIf (config.serviceConfig != { }) config.serviceConfig;
        }

        (lib.mkIf (config.environment != { }) {
          serviceConfig.Environment = let
            env = config.environment;
          in
          lib.map (
            n:
            let
              s = lib.optionalString (env.${n} != null) "${lib.strings.toJSON "${n}=${env.${n}}"}";
              # systemd max line length is now 1MiB
              # https://github.com/systemd/systemd/commit/e6dde451a51dc5aaa7f4d98d39b8fe735f73d2af
            in
            if lib.stringLength s >= 1048576 then
              throw "The value of the environment variable ‘${n}’ in systemd service ‘${config.name}.service’ is too long."
            else
              s
          ) (lib.attrNames env);
        })

        (mkIf (config.preStart != "") rec {
          jobScripts = makeJobScript {
            name = "${name}-pre-start";
            text = config.preStart;
            inherit (config) enableStrictShellChecks;
          };
          serviceConfig.ExecStartPre = [ jobScripts ];
        })
        (mkIf (config.script != "") rec {
          jobScripts = makeJobScript {
            name = "${name}-start";
            text = config.script;
            inherit (config) enableStrictShellChecks;
          };
          serviceConfig.ExecStart = jobScripts + " " + config.scriptArgs;
        })
        (mkIf (config.postStart != "") rec {
          jobScripts = makeJobScript {
            name = "${name}-post-start";
            text = config.postStart;
            inherit (config) enableStrictShellChecks;
          };
          serviceConfig.ExecStartPost = [ jobScripts ];
        })
        (mkIf (config.reload != "") rec {
          jobScripts = makeJobScript {
            name = "${name}-reload";
            text = config.reload;
            inherit (config) enableStrictShellChecks;
          };
          serviceConfig.ExecReload = jobScripts;
        })
        (mkIf (config.preStop != "") rec {
          jobScripts = makeJobScript {
            name = "${name}-pre-stop";
            text = config.preStop;
            inherit (config) enableStrictShellChecks;
          };
          serviceConfig.ExecStop = jobScripts;
        })
        (mkIf (config.postStop != "") rec {
          jobScripts = makeJobScript {
            name = "${name}-post-stop";
            text = config.postStop;
            inherit (config) enableStrictShellChecks;
          };
          serviceConfig.ExecStopPost = jobScripts;
        })
      ];

    };

  execOptions = { config, ... }: {
    options = {
      path = mkOption {
        default = [ ];
        type =
          with types;
          listOf (oneOf [
            package
            str
          ]);
        description = ''
          Packages added to the service's {env}`PATH`
          environment variable.  Both the {file}`bin`
          and {file}`sbin` subdirectories of each
          package are added.
        '';
      };

      environment = mkOption {
        default = { };
        type =
          with types;
          attrsOf (
            nullOr (oneOf [
              str
              path
              package
            ])
          );
        example = {
          PATH = "/foo/bar/bin";
          LANG = "nl_NL.UTF-8";
        };
        description = "Environment variables passed to the unit's execution environment.";
      };

      enableStrictShellChecks = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable running `shellcheck` on the generated scripts for this unit.

          When enabled, scripts generated by the unit will be checked with
          `shellcheck` and any errors or warnings will cause the build to
          fail.

          This affects all scripts that have been created through the `script`,
          `reload`, `preStart`, `postStart`, `preStop` and `postStop` options
          for systemd service and socket units. This does not affect command
          lines passed directly to `ExecStart`, `ExecReload`, `ExecStartPre`,
          `ExecStartPost`, `ExecStop` or `ExecStopPost`.
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

      preStart = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Shell commands executed before the execution environment's main
          process is started.
        '';
      };

      postStart = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Shell commands executed after the execution environment's main
          process is started.
        '';
      };

      preStop = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Shell commands executed to stop the execution environment's .
        '';
      };

      postStop = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Shell commands executed after the service's main process
          has exited.
        '';
      };

      jobScripts = mkOption {
        type = with types; coercedTo path singleton (listOf path);
        internal = true;
        description = "A list of all job script derivations of this unit.";
        default = [ ];
      };
    };

    config = lib.mkMerge [
      (lib.mkIf config.enableCommonDependencies {
        # The common dependencies is just based from NixOS' version of
        # stage 2 systemd services except without systemd since this is
        # more focused on generating generic systemd units.
        path = lib.mkAfter [
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnugrep
          pkgs.gnused
        ];
      })

      (lib.mkIf (config.path != [ ]) {
        environment.PATH = "${lib.makeBinPath config.path}:${lib.makeSearchPathOutput "bin" "sbin" config.path}";
      })
    ];
  };

  socketOptions = { name, config, ... }: {
    imports = [ execOptions ];

    options = {
      listenStreams = mkOption {
        default = [ ];
        type = types.listOf types.str;
        example = [
          "0.0.0.0:993"
          "/run/my-socket"
        ];
        description = ''
          For each item in this list, a `ListenStream`
          option in the `[Socket]` section will be created.
        '';
      };

      listenDatagrams = mkOption {
        default = [ ];
        type = types.listOf types.str;
        example = [
          "0.0.0.0:993"
          "/run/my-socket"
        ];
        description = ''
          For each item in this list, a `ListenDatagram`
          option in the `[Socket]` section will be created.
        '';
      };

      socketConfig = mkOption {
        default = { };
        example = {
          ListenStream = "/run/my-socket";
        };
        type = types.attrsOf unitOption;
        description = ''
          Each attribute in this set specifies an option in the
          `[Socket]` section of the unit.  See
          {manpage}`systemd.socket(5)` for details.
        '';
      };
    };

    config = lib.mkMerge [
      {
        settings.Socket = config.socketConfig;
      }

      (lib.mkIf (config.environment != { }) {
        socketConfig.Environment = let
          env = config.environment;
        in
        lib.concatMapStrings (
          n:
          let
            s = lib.optionalString (env.${n} != null) "${lib.strings.toJSON "${n}=${env.${n}}"}\n";
            # systemd max line length is now 1MiB
            # https://github.com/systemd/systemd/commit/e6dde451a51dc5aaa7f4d98d39b8fe735f73d2af
          in
          if lib.stringLength s >= 1048576 then
            throw "The value of the environment variable ‘${n}’ in systemd service ‘${config.name}.service’ is too long."
          else
            s
        ) (lib.attrNames env);
      })

      (lib.mkIf (config.listenStreams != [ ]) {
        socketConfig.ListenStream = config.listenStreams;
      })

      (lib.mkIf (config.listenDatagrams != [ ]) {
        socketConfig.ListenDatagram = config.listenDatagrams;
      })

      (mkIf (config.preStart != "") rec {
        jobScripts = makeJobScript {
          name = "${name}-pre-start";
          text = config.preStart;
          inherit (config) enableStrictShellChecks;
        };
        socketConfig.ExecStartPre = [ jobScripts ];
      })
      (mkIf (config.postStart != "") rec {
        jobScripts = makeJobScript {
          name = "${name}-post-start";
          text = config.postStart;
          inherit (config) enableStrictShellChecks;
        };
        socketConfig.ExecStartPost = [ jobScripts ];
      })
      (mkIf (config.preStop != "") rec {
        jobScripts = makeJobScript {
          name = "${name}-pre-stop";
          text = config.preStop;
          inherit (config) enableStrictShellChecks;
        };
        socketConfig.ExecStop = jobScripts;
      })
      (mkIf (config.postStop != "") rec {
        jobScripts = makeJobScript {
          name = "${name}-post-stop";
          text = config.postStop;
          inherit (config) enableStrictShellChecks;
        };
        socketConfig.ExecStopPost = jobScripts;
      })
    ];

  };

  timerOptions = { config, ... }: {
    options = {
      timerConfig = mkOption {
        default = { };
        example = {
          OnCalendar = "Sun 14:00:00";
          Unit = "foo.service";
        };
        type = types.attrsOf unitOption;
        description = ''
          Each attribute in this set specifies an option in the
          `[Timer]` section of the unit.  See
          {manpage}`systemd.timer(5)` and
          {manpage}`systemd.time(7)` for details.
        '';
      };
    };

    config.settings.Timer = config.timerConfig;
  };

  pathOptions = { config, ... }: {
    options = {
      pathConfig = mkOption {
        default = { };
        example = {
          PathChanged = "/some/path";
          Unit = "changedpath.service";
        };
        type = types.attrsOf unitOption;
        description = ''
          Each attribute in this set specifies an option in the
          `[Path]` section of the unit.  See
          {manpage}`systemd.path(5)` for details.
        '';
      };
    };

    config.settings.Path = config.pathConfig;
  };

  mountOptions = { config, ... }: {
    options = {
      what = mkOption {
        example = "/dev/sda1";
        type = types.str;
        description = "Absolute path of device node, file or other resource. (Mandatory)";
      };

      where = mkOption {
        example = "/mnt";
        type = types.str;
        description = ''
          Absolute path of a directory of the mount point.
          Will be created if it doesn't exist. (Mandatory)
        '';
      };

      type = mkOption {
        default = "";
        example = "ext4";
        type = types.str;
        description = "File system type.";
      };

      options = mkOption {
        default = "";
        example = "noatime";
        type = types.commas;
        description = "Options used to mount the file system.";
      };

      mountConfig = mkOption {
        default = { };
        example = {
          DirectoryMode = "0775";
        };
        type = types.attrsOf unitOption;
        description = ''
          Each attribute in this set specifies an option in the
          `[Mount]` section of the unit.  See
          {manpage}`systemd.mount(5)` for details.
        '';
      };
    };

    config.settings.Mount = config.mountConfig;
  };

  automountOptions = { config, ... }: {
    options = {
      where = mkOption {
        example = "/mnt";
        type = types.str;
        description = ''
          Absolute path of a directory of the mount point.
          Will be created if it doesn't exist. (Mandatory)
        '';
      };

      automountConfig = mkOption {
        default = { };
        example = {
          DirectoryMode = "0775";
        };
        type = types.attrsOf unitOption;
        description = ''
          Each attribute in this set specifies an option in the
          `[Automount]` section of the unit.  See
          {manpage}`systemd.automount(5)` for details.
        '';
      };
    };

    config.settings.Automount = config.automountConfig;
  };

  sliceOptions = { config, ... }: {
    options = {
      sliceConfig = mkOption {
        default = { };
        example = {
          MemoryMax = "2G";
        };
        type = types.attrsOf unitOption;
        description = ''
          Each attribute in this set specifies an option in the
          `[Slice]` section of the unit.  See
          {manpage}`systemd.slice(5)` for details.
        '';
      };
    };

    config.settings.Slice = config.sliceConfig;
  };
}
