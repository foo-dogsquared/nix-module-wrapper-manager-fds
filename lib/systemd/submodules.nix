/**
  A convenient set of module types for the systemd unit. Take note, all of the
  documented items here contain a list of modules and intended to be included as
  a submodule. You can use it like in the following code:

  ```nix
  { config, lib, wrapperManagerLib, ... }:

  let
    otherCustomModules = [ ];
  in
  {
    options.custom-systemd-option.units = lib.mkOption {
      type = with lib.types; attrsof (submodule (
        wrapperManagerLib.systemd.submodules.units
        ++ [ otherCustomModules ];
      ));
    };
  }
  ```

  Furthermore, it doesn't set any of the global systemd options found in the
  base module configuration (e.g., `programs.systemd.enableCommonDependencies`,
  `programs.systemd.enableStatelessInstallation`).
*/
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

  sharedExecConfig = cfg: { config, lib, ... }: {
    config = {
      enableStrictShellChecks = lib.mkOptionDefault cfg.programs.systemd.enableStrictShellChecks;
      enableCommonDependencies = lib.mkOptionDefault cfg.programs.systemd.enableCommonDependencies;
    };
  };

  sharedUnitConfig = cfg: {
    config = {
      enableStatelessInstallation = lib.mkOptionDefault cfg.programs.systemd.enableStatelessInstallation;
    };
  };
in
rec {
  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.units`.
  */
  units = lib.singleton (
    { name, config, lib, ... }:
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
    }
  );

  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.services`.
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
    Convenience function around `services` to make a list of modules with the
    global wrapper-manager systemd-related options.

    # Arguments

    cfg
    : The wrapper-manager configuration.

    # Type

    ```
    services' :: Attrs -> [ Module ]
    ```

    # Examples

    Assume it's in a wrapper-manager module.

    ```nix
    { lib, wrapperManagerLib, config, ... }: {
      options.custom-systemd-option.services = lib.mkOption {
        type = with lib.types; attrsOf (submodule (wrapperManagerLib.systemd.submodules.services' config));
      };
    }
    ```
  */
  services' = cfg:
    services
    ++ [
      (sharedExecConfig cfg)
      (sharedUnitConfig cfg)
    ];

  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.targets`.
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
    Convenience function around `targets` to make a list of modules with the
    global wrapper-manager systemd-related options.

    # Arguments

    cfg
    : The wrapper-manager configuration.

    # Type

    ```
    targets' :: Attrs -> [ Module ]
    ```

    # Examples

    Assume it's in a wrapper-manager module.

    ```nix
    { lib, wrapperManagerLib, config, ... }: {
      options.custom-systemd-option.targets = lib.mkOption {
        type = with lib.types; attrsOf (submodule (wrapperManagerLib.systemd.submodules.targets' config));
      };
    }
    ```
  */
  targets' = cfg:
    targets
    ++ [
      (sharedUnitConfig cfg)
    ];

  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.sockets`.
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
    Convenience function around `sockets` to make a list of modules with the
    global wrapper-manager systemd-related options.

    # Arguments

    cfg
    : The wrapper-manager configuration.

    # Type

    ```
    sockets' :: Attrs -> [ Module ]
    ```

    # Examples

    Assume it's in a wrapper-manager module.

    ```nix
    { lib, wrapperManagerLib, config, ... }: {
      options.custom-systemd-option.sockets = lib.mkOption {
        type = with lib.types; attrsOf (submodule (wrapperManagerLib.systemd.submodules.sockets' config));
      };
    }
    ```
  */
  sockets' = cfg:
    sockets
    ++ [
      (sharedExecConfig cfg)
      (sharedUnitConfig cfg)
    ];

  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.timers`.
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
    Convenience function around `timers` to make a list of modules with the
    global wrapper-manager systemd-related options.

    # Arguments

    cfg
    : The wrapper-manager configuration.

    # Type

    ```
    timers' :: Attrs -> [ Module ]
    ```

    # Examples

    Assume it's in a wrapper-manager module.

    ```nix
    { lib, wrapperManagerLib, config, ... }: {
      options.custom-systemd-option.timers = lib.mkOption {
        type = with lib.types; attrsOf (submodule (wrapperManagerLib.systemd.submodules.timers' config));
      };
    }
    ```
  */
  timers' = cfg:
    timers
    ++ [
      (sharedUnitConfig cfg)
    ];

  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.paths`.
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
    Convenience function around `paths` to make a list of modules with the
    global wrapper-manager systemd-related options.

    # Arguments

    cfg
    : The wrapper-manager configuration.

    # Type

    ```
    paths' :: Attrs -> [ Module ]
    ```

    # Examples

    Assume it's in a wrapper-manager module.

    ```nix
    { lib, wrapperManagerLib, config, ... }: {
      options.custom-systemd-option.paths = lib.mkOption {
        type = with lib.types; attrsOf (submodule (wrapperManagerLib.systemd.submodules.paths' config));
      };
    }
    ```
  */
  paths' = cfg:
    paths
    ++ [
      (sharedUnitConfig cfg)
    ];

  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.slices`.
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
    Convenience function around `slices` to make a list of modules with the
    global wrapper-manager systemd-related options.

    # Arguments

    cfg
    : The wrapper-manager configuration.

    # Type

    ```
    slices' :: Attrs -> [ Module ]
    ```

    # Examples

    Assume it's in a wrapper-manager module.

    ```nix
    { lib, wrapperManagerLib, config, ... }: {
      options.custom-systemd-option.slices = lib.mkOption {
        type = with lib.types; attrsOf (submodule (wrapperManagerLib.systemd.submodules.slices' config));
      };
    }
    ```
  */
  slices' = cfg:
    slices
    ++ [
      (sharedUnitConfig cfg)
    ];

  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.mounts`.
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
    Convenience function around `mounts` to make a list of modules with the
    global wrapper-manager systemd-related options.

    # Arguments

    cfg
    : The wrapper-manager configuration.

    # Type

    ```
    mounts' :: Attrs -> [ Module ]
    ```

    # Examples

    Assume it's in a wrapper-manager module.

    ```nix
    { lib, wrapperManagerLib, config, ... }: {
      options.custom-systemd-option.mounts = lib.mkOption {
        type = with lib.types; attrsOf (submodule (wrapperManagerLib.systemd.submodules.mounts' config));
      };
    }
    ```
  */
  mounts' = cfg:
    mounts
    ++ [
      (sharedUnitConfig cfg)
    ];

  /**
    List of modules associated for {option}`programs.systemd.$VARIANT.automounts`.
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

  /**
    Convenience function around `automounts` to make a list of modules with the
    global wrapper-manager systemd-related options.

    # Arguments

    cfg
    : The wrapper-manager configuration.

    # Type

    ```
    automounts' :: Attrs -> [ Module ]
    ```

    # Examples

    Assume it's in a wrapper-manager module.

    ```nix
    { lib, wrapperManagerLib, config, ... }: {
      options.custom-systemd-option.automounts = lib.mkOption {
        type = with lib.types; attrsOf (submodule (wrapperManagerLib.systemd.submodules.automounts' config));
      };
    }
    ```
  */
  automounts' = cfg:
    automounts
    ++ [
      (sharedUnitConfig cfg)
    ];
}
