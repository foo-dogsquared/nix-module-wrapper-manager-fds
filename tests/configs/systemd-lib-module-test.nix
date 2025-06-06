/*
  A test config for creating custom systemd units with different output. Useful
  for creating own set of systemd units.
*/
{ config, lib, pkgs, wrapperManagerLib, ... }:

let
  name = "systemd-lib-module-test";
  customSystemdDir = "share/custom-app/examples/systemd";
  cfg = config.custom-systemd;
  customModule = { };
in
{
  options.custom-systemd.units = lib.mkOption {
    default = { };
    type = with lib.types; attrsOf (submodule (
      wrapperManagerLib.systemd.submodules.units
      ++ [ customModule ]
      ));
  };

  options.custom-systemd.services = lib.mkOption {
    default = { };
    type = with lib.types; attrsOf (submodule (
      wrapperManagerLib.systemd.submodules.services
      ++ [ customModule ]
      ));
  };

  options.custom-systemd.timers = lib.mkOption {
    default = { };
    type = with lib.types; attrsOf (submodule (
      wrapperManagerLib.systemd.submodules.timers
      ++ [ customModule ]
      ));
  };

  options.custom-systemd.paths = lib.mkOption {
    default = { };
    type = with lib.types; attrsOf (submodule (
      wrapperManagerLib.systemd.submodules.paths
      ++ [ customModule ]
      ));
  };

  options.custom-systemd.sockets = lib.mkOption {
    default = { };
    type = with lib.types; attrsOf (submodule (
      wrapperManagerLib.systemd.submodules.sockets
      ++ [ customModule ]
      ));
  };

  options.custom-systemd.slices = lib.mkOption {
    default = { };
    type = with lib.types; attrsOf (submodule (
      wrapperManagerLib.systemd.submodules.slices
      ++ [ customModule ]
      ));
  };

  config = let
    addUnitWithCondition = services: cond: f:
      let
        validServices = lib.filterAttrs cond services;
      in
        lib.mapAttrs f validServices;

    addTimerUnitByServicesWithStartAt = services: addUnitWithCondition services (_: v: v.startAt != [ ])
      (_: v: {
        wantedBy = [ "timers.target" ];
        timerConfig.OnCalendar = v.startAt;
      });

    addSocketUnitByServicesWithListenOn = services: addUnitWithCondition services (_: v: v.listenOn != [ ])
      (_: v: {
        wantedBy = [ "sockets.target" ];
        listenStreams = v.listenOn;
      });

    addPathUnitByServicesWithWatchFilesFrom = services: addUnitWithCondition services (_: v: v.watchFilesFrom != [ ])
      (_: v: {
        wantedBy = [ "paths.target" ];
        pathConfig = {
          PathModified = v.watchFilesFrom;
          MakeDirectory = lib.mkDefault true;
        };
      });
  in lib.mkMerge [
    # --- CUSTOM CONFIG ---
    {
      custom-systemd.services."hello/there" = {
        description = "A drop-in unit for hello.service";
      };

      custom-systemd.services."hello" = {
        description = "Hello greeting service";

        # It should have a timer unit.
        startAt = "weekly";
        listenOn = [ "0.0.0.0:9999" ];
        watchFilesFrom = [ "%h/whomp-whomp" ];
      };

      custom-systemd.sockets."hello" = {
        description = "Socket unit file for Hello service";
      };
    }

    # --- IMPLEMENTATION ---
    {
      custom-systemd.units =
        let
          mkUnit = (_: unit: lib.nameValuePair unit.filename (wrapperManagerLib.systemd.intoUnit unit));
        in
          lib.mapAttrs' mkUnit cfg.services
          // lib.mapAttrs' mkUnit cfg.timers
          // lib.mapAttrs' mkUnit cfg.paths
          // lib.mapAttrs' mkUnit cfg.sockets
          // lib.mapAttrs' mkUnit cfg.slices;

      custom-systemd.timers = addTimerUnitByServicesWithStartAt cfg.services;
      custom-systemd.paths = addPathUnitByServicesWithWatchFilesFrom cfg.services;
      custom-systemd.sockets = addSocketUnitByServicesWithListenOn cfg.services;

      files."${customSystemdDir}".source =
        wrapperManagerLib.systemd.generateUnits { inherit (cfg) units; };

      build.extraPassthru.wrapperManagerTests = {
        actuallyBuilt = let
          wrapper = config.build.toplevel;
          customSystemdDir' = "${wrapper}/${customSystemdDir}";
        in
          pkgs.runCommand "wrapper-manager-tests-${name}" { } ''
            [ -f "${customSystemdDir'}/hello.service" ] \
            && [ -f "${customSystemdDir'}/hello.service.d/there.conf" ] \
            && [ -f "${customSystemdDir'}/hello.socket" ] \
            && [ -f "${customSystemdDir'}/hello.timer" ] \
            && [ -f "${customSystemdDir'}/hello.path" ] \
            && touch $out
          '';
      };
    }
  ];
}
