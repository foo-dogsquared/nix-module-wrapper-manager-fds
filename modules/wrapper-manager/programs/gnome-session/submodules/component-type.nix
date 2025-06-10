{ name, config, pkgs, lib, wrapperManagerLib, session, ... }:

let
  optionalSystemdUnitOption = { unitType, systemdModuleAttribute, otherType, }:
    lib.mkOption {
      type = lib.types.nullOr otherType;
      description = ''
        An optional systemd ${unitType} configuration to be generated. This should
        be configured if the session is managed by systemd.

        :::{.note}
        This has the same options as
        {option}`programs.systemd.user.${systemdModuleAttribute}.<name>`.
        :::
      '';
      visible = "shallow";
      default = null;
    };

  submodule' = name:
    lib.singleton ({ lib, ... }: { _module.args.name = lib.mkForce name; });
in {
  options = {
    description = lib.mkOption {
      type = lib.types.nonEmptyStr;
      description = "One-sentence description of the component.";
      default = name;
      example = "Desktop widgets";
    };

    script = lib.mkOption {
      type = lib.types.lines;
      description = ''
        Shell script fragment of the component.

        The way it is handled is different per startup methods.

        * This will be wrapped in a script for proper integration with the
        legacy non-systemd session management.

        * For systemd-managed sessions, it will be part of
        {option}`programs.gnome-session.sessions.<sessions>.components.<name>.serviceUnit.script`.
      '';
    };

    desktopEntrySettings = lib.mkOption {
      type = with lib.types; attrsOf anything;
      description = ''
        The configuration for the gnome-session desktop file. For more
        information, look into `makeDesktopItem` nixpkgs builder.

        You should configure this is if you use the built-in service
        management to be able to customize the session.

        ::: {.note}
        This module appends several options for the desktop item builder such
        as the script path and `X-GNOME-HiddenUnderSystemd` which is set to
        `true`.
        :::
      '';
      default = { };
      example = {
        extraConfig = {
          X-GNOME-Autostart-Phase = "WindowManager";
          X-GNOME-AutoRestart = "true";
        };
      };
    };

    systemd = {
      # Most of the systemd config types are trying to eliminate as much of the
      # NixOS systemd extensions as much as possible. For more details, see
      # `config` attribute of the `sessionType`.
      serviceUnit = lib.mkOption {
        type = lib.types.submodule (wrapperManagerLib.systemd.submodules.services ++ (submodule' config.id));
        description = ''
          systemd service configuration to be generated. This should be
          configured if the session is managed by systemd.

          :::{.note}
          This has the same options as
          {option}`programs.systemd.user.services.<name>`.

          By default, this module sets the service unit as part of the respective
          target unit (i.e., `PartOf=$COMPONENTID.target`).

          On a typical case, you shouldn't mess with much of the dependency
          ordering of the service unit. You should configure `targetUnit` for
          that instead.
          :::
        '';
        default = { };
        visible = "shallow";
      };

      targetUnit = lib.mkOption {
        type = lib.types.submodule (
          wrapperManagerLib.systemd.submodules.targets
          ++ (submodule' config.id)
        );
        description = ''
          systemd target configuration to be generated. This should be
          configured if the session is managed by systemd.

          :::{.note}
          This has the same options as
          {option}`programs.systemd.user.targets.<name>`.

          This module doesn't set the typical dependency ordering relative to
          gnome-session targets. This is on the user to manually set them.
          :::
        '';
        default = { };
        visible = "shallow";
      };

      timerUnit = optionalSystemdUnitOption {
        unitType = "timer";
        systemdModuleAttribute = "timers";
        otherType = lib.types.submodule (
          wrapperManagerLib.systemd.submodules.timers
          ++ (submodule' config.id)
        );
      };

      socketUnit = optionalSystemdUnitOption {
        unitType = "socket";
        systemdModuleAttribute = "sockets";
        otherType = lib.types.submodule (
          wrapperManagerLib.systemd.submodules.sockets
          ++ (submodule' config.id)
        );
      };

      pathUnit = optionalSystemdUnitOption {
        unitType = "path";
        systemdModuleAttribute = "paths";
        otherType = lib.types.submodule (
          wrapperManagerLib.systemd.submodules.paths
          ++ (submodule' config.id)
        );
      };
    };

    id = lib.mkOption {
      type = lib.types.str;
      description = ''
        The identifier of the component used in generating filenames for its
        `.desktop` files and as part of systemd unit names.
      '';
      default = "${session.name}.${name}";
      defaultText = "$SESSION_NAME.$COMPONENT_NAME";
      readOnly = true;
    };
  };

  config = {
    # Make with the default configurations for the built-in-managed
    # components.
    desktopEntrySettings = {
      name = lib.mkForce config.id;
      desktopName = lib.mkDefault "${session.fullName} - ${config.description}";
      exec =
        let
          script = pkgs.writeShellScript "${session.name}-${name}-script" config.script;
        in
          lib.mkDefault (builtins.toString script);
      noDisplay = lib.mkForce true;
      onlyShowIn = session.desktopNames;

      # For more information, you'll have to take a look into the
      # gnome-session/README from its source code. Not even documented in the
      # manual page but whatever. This is on the user to know.
      extraConfig = {
        X-GNOME-AutoRestart = lib.mkDefault "false";
        X-GNOME-Autostart-Notify = lib.mkDefault "true";
        X-GNOME-Autostart-Phase = lib.mkDefault "Application";
        X-GNOME-HiddenUnderSystemd = lib.mkDefault "true";
      };
    };

    /* Setting some recommendation and requirements for systemd-managed
       gnome-session components. Note there are the missing directives that
       COULD include some sane defaults here.

       * The `Unit.OnFailure=` and `Unit.OnFailureJobMode=` directives. Since
       different components don't have the same priority and don't handle
       failures the same way, we didn't set it here. This is on the user to
       know how different desktop components interact with each other
       especially if one of them failed.

       * Even if we have a way to limit starting desktop components with
       `systemd-xdg-autostart-condition`, using `Service.ExecCondition=` would
       severely limit possible reuse of desktop components with other
       NixOS-module-generated gnome-session sessions so we're not bothering with
       those.

       * `Service.Type=` is obviously not included since not all desktop
       components are the same either. Some of them could be a D-Bus service,
       some of them are oneshots, etc. Though, it might be better to have this
       as an explicit option set by the user instead of setting `Type=notify` as
       a default.

       * Most sandboxing options. Aside from the fact we're dealing with a
       systemd user unit, much of them are unnecessary and rarely needed (if
       ever like `Service.PrivateTmp=`?) so we didn't set such defaults here.
    */
    systemd.serviceUnit = {
      script = lib.mkAfter config.script;
      description = lib.mkDefault config.description;

      # The typical workflow for service units to have them set as part of
      # the respective target unit.
      requisite = [ "${config.id}.target" ];
      before = [ "${config.id}.target" ];
      partOf = [ "${config.id}.target" ];

      # Some sane service configuration for a desktop component.
      serviceConfig = {
        Slice = lib.mkDefault "session.slice";
        Restart = lib.mkDefault "on-failure";
        TimeoutStopSec = lib.mkDefault 5;

        # We'll assume most of the components are reasonably required so we'll
        # set a reasonable middle-in-the-ground value for this one. The user
        # should have the responsibility passing judgement for what is best for
        # this.
        OOMScoreAdjust = lib.mkDefault (-500);
      };

      startLimitBurst = lib.mkDefault 3;
      startLimitIntervalSec = lib.mkDefault 15;

      unitConfig = {
        # Units managed by gnome-session are required to have CollectMode=
        # set to this value.
        CollectMode = lib.mkForce "inactive-or-failed";

        # We leave those up to the target units to start the services.
        RefuseManualStart = lib.mkDefault true;
        RefuseManualStop = lib.mkDefault true;
      };
    };

    /* Take note, we'll assume the session target unit will be the one to set
       the dependency-related directives (i.e., `After=`, `Before=`, `Requires=`)
       so no need to set any in here.

       And another thing, we didn't set a default value for dependency-related
       directives to one of the gnome-session-specific target unit. It is more
       likely for a user to design their own desktop session with full control
       so it would be better for these options to be empty for less confusion.
    */
    systemd.targetUnit = {
      # This should be the dependency-related directive to be configured. The
      # rest is for the user to judge.
      wants = [ "${config.id}.service" ];

      description = lib.mkDefault config.description;
      documentation = [ "man:gnome-session(1)" "man:systemd.special(7)" ];

      # Similar to the service unit, this is very much required as noted from
      # the `gnome-session(1)` manual page.
      unitConfig.CollectMode = lib.mkForce "inactive-or-failed";
    };

    # Set all of the optional systemd units from the typical additional service
    # options.
    systemd.timerUnit = lib.mkIf (config.systemd.serviceUnit.startAt != [ ]) {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = config.systemd.serviceUnit.startAt;
      unitConfig.CollectMode = lib.mkForce "inactive-or-failed";
    };

    systemd.socketUnit = lib.mkIf (config.systemd.serviceUnit.listenOn != [ ]) {
      wantedBy = [ "sockets.target" ];
      listenStreams = config.systemd.serviceUnit.listenOn;
      unitConfig.CollectMode = lib.mkForce "inactive-or-failed";
    };

    systemd.pathUnit = lib.mkIf (config.systemd.serviceUnit.watchFilesFrom != [ ]) {
      wantedBy = [ "paths.target" ];
      pathConfig.PathModified = config.systemd.serviceUnit.watchFilesFrom;
      unitConfig.CollectMode = lib.mkForce "inactive-or-failed";
    };
  };
}
