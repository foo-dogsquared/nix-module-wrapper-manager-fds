{
  pkgs,
  lib,
  self,
}:

let
  inherit (self.systemd)
    escapeSystemdPath
    makeUnit
    mkUnitFileName
    getUnitName
    ;

  inherit (self.systemd.options)
    sharedOptions
    automountOptions
    commonUnitOptions
    mountOptions
    pathOptions
    sliceOptions
    serviceOptions
    socketOptions
    timerOptions
    ;
in

{
  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.units`.
    This is intended to be put inside of a module option with a submodule type.
  */
  units = { name, config, lib, ... }:
    {
      options = sharedOptions // {
        text = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = "Text of this systemd unit.";
        };

        unit = lib.mkOption {
          internal = true;
          description = "The generated unit.";
        };
      };

      config = {
        name = lib.mkDefault name;
        unit = lib.mkDefault (makeUnit name config);
        text = self.generators.toSystemdINI config.settings;
      };
    };

  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.services`.
    This is intended to be put inside of a module option with a submodule type.
  */
  services = [
    commonUnitOptions
    serviceOptions

    ({ name, ... }: {
      config = {
        name = "${getUnitName name}.service";
        filename = mkUnitFileName "service" name;
      };
    })
  ];

  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.targets`.
    This is intended to be put inside of a module option with a submodule type.
  */
  targets = [
    commonUnitOptions
    ({ name, ... }: {
      config = {
        name = "${getUnitName name}.target";
        filename = mkUnitFileName "target" name;
      };
    })
  ];

  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.sockets`.
    This is intended to be put inside of a module option with a submodule type.
  */
  sockets = [
    commonUnitOptions
    socketOptions
    ({ name, ... }: {
      config = {
        name = "${getUnitName name}.socket";
        filename = mkUnitFileName "socket" name;
      };
    })
  ];

  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.timers`.
    This is intended to be put inside of a module option with a submodule type.
  */
  timers = [
    commonUnitOptions
    timerOptions
    ({ name, ... }: {
      config = {
        name = "${getUnitName name}.timer";
        filename = mkUnitFileName "timer" name;
      };
    })
  ];

  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.paths`.
    This is intended to be put inside of a module option with a submodule type.
  */
  paths = [
    commonUnitOptions
    pathOptions
    ({ name, ... }: {
      config = {
        name = "${getUnitName name}.path";
        filename = mkUnitFileName "path" name;
      };
    })
  ];

  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.slices`.
    This is intended to be put inside of a module option with a submodule type.
  */
  slices = [
    commonUnitOptions
    sliceOptions
    ({ name, ... }: {
      config = {
        name = "${getUnitName name}.slice";
        filename = mkUnitFileName "slice" name;
      };
    })
  ];

  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.mounts`.
    This is intended to be put inside of a module option with a submodule type.
  */
  mounts = [
    commonUnitOptions
    mountOptions
    ({ config, lib, ... }: let
      name = escapeSystemdPath config.where;
    in {
      config = {
        name = "${getUnitName name}.mount";
        filename = mkUnitFileName "mount" name;
        mountConfig =
          {
            What = config.what;
            Where = config.where;
          }
          // lib.optionalAttrs (config.type != "") {
            Type = config.type;
          }
          // lib.optionalAttrs (config.options != "") {
            Options = config.options;
          };
      };
    })
  ];

  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.automounts`.
    This is intended to be put inside of a module option with a submodule type.
  */
  automounts = [
    commonUnitOptions
    automountOptions
    ({ config, lib, ... }: let
      name = escapeSystemdPath config.where;
    in {
      config = {
        name = "${getUnitName name}.automount";
        filename = mkUnitFileName "automount" name;
        automountConfig = {
          Where = config.where;
        };
      };
    })
  ];
}
