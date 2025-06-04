{ config, lib, wrapperManagerLib, ... }:

let
  systemdUtils = wrapperManagerLib.systemd;

  mkSystemdOption = name: unitTypeSingular: systemdUnitAttr: let
  in {
    enable = lib.mkEnableOption "${unitTypeSingular} unit generation";
    settings = lib.mkOption {
      type = lib.types.submodule (
        systemdUtils.submodules.${systemdUnitAttr}
        ++ lib.singleton {
          _module.args.name = lib.mkForce name;
        }
      );
      # We don't need to clutter more of the systemd unit options, come on now.
      visible = "shallow";
      default = { };
      description = ''
        The systemd ${unitTypeSingular} unit settings for this wrapper configured the
        same way as {option}`programs.systemd.$VARIANT.${systemdUnitAttr}.$NAME`.
      '';
    };
  };

  systemdModule = { config, lib, name, ... }: let
    submoduleCfg = config.systemd;
    mkSystemdOption' = mkSystemdOption name;
  in {
    options.systemd = {
      enable = lib.mkEnableOption "systemd unit generation associated with this wrapper";

      variant = lib.mkOption {
        type = lib.types.enum [ "system" "user" ];
        default = "user";
        description = ''
          Determines where the unit will be placed as a system or a user unit.
        '';
        example = "system";
      };

      serviceUnit = mkSystemdOption' "service" "services";
      timerUnit = mkSystemdOption' "timer" "timers";
      pathUnit = mkSystemdOption' "path" "paths";
      socketUnit = mkSystemdOption' "socket" "sockets";
    };

    config = lib.mkIf submoduleCfg.enable (lib.mkMerge [
      (lib.mkIf submoduleCfg.serviceUnit.enable {
        systemd.serviceUnit.settings = {
          serviceConfig.ExecStart = config.executableName;
          wantedBy = lib.optionals (submoduleCfg.variant == "user") (lib.mkDefault [ "default.target" ]);
        };
      })

      (lib.mkIf (submoduleCfg.serviceUnit.settings.startAt != [ ]) {
        systemd.timerUnit.enable = lib.mkDefault true;
        systemd.timerUnit.settings = {
          wantedBy = [ "timers.target" ];
          timerConfig.OnCalendar = submoduleCfg.serviceUnit.settings.startAt;
        };
      })
    ]);
  };
in
{
  options.wrappers = lib.mkOption {
    type = with lib.types; attrsOf (submodule systemdModule);
  };

  config = let
    wrappersWithSystemdEnabled = variant:
      lib.filterAttrs (_: v: v.systemd.enable && v.systemd.variant == variant) config.wrappers;

    mkSystemdUnitConfig = name: wrapperConfig:
      let
        inherit (wrapperConfig.systemd) serviceUnit timerUnit pathUnit socketUnit;
      in
        lib.optionalAttrs serviceUnit.enable {
          "${name}.service" = systemdUtils.intoUnit serviceUnit.settings;
        }
        // lib.optionalAttrs timerUnit.enable {
          "${name}.timer" = systemdUtils.intoUnit timerUnit.settings;
        }
        // lib.optionalAttrs pathUnit.enable {
          "${name}.path" = systemdUtils.intoUnit pathUnit.settings;
        }
        // lib.optionalAttrs socketUnit.enable {
          "${name}.socket" = systemdUtils.intoUnit socketUnit.settings;
        };
    in
  {
    programs.systemd.user.units =
      lib.concatMapAttrs mkSystemdUnitConfig (wrappersWithSystemdEnabled "user");

    programs.systemd.system.units =
      lib.concatMapAttrs mkSystemdUnitConfig (wrappersWithSystemdEnabled "system");
  };
}
