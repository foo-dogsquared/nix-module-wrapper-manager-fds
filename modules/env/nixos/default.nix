{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.wrapper-manager;
  wmDocs = import ../../../docs {
    inherit pkgs;
    inherit (cfg.documentation) extraModules;
  };
in
{
  imports = [ ../common.nix ];

  options.wrapper-manager = {
    enableInstallSystemdUnits =
      lib.mkEnableOption "install systemd units from wrapper-manager packages" // {
        default = true;
      };
  };

  config = lib.mkMerge [
    {
      environment.systemPackages =
        lib.optionals cfg.documentation.manpage.enable [ wmDocs.outputs.manpage ]
        ++ lib.optionals cfg.documentation.html.enable [ wmDocs.outputs.html ];

      wrapper-manager.extraSpecialArgs.nixosConfig = config;

      wrapper-manager.sharedModules = [
        (
          { lib, ... }:
          {
            # NixOS already has the option to set the locale so we don't need to
            # have this.
            config.locale.enable = lib.mkDefault false;
          }
        )

        (
          { lib, ... }: {
            options.enableInstallSystemdUnits = lib.mkEnableOption "install systemd units from wrapper-manager configuration" // {
              default = cfg.enableInstallSystemdUnits;
            };
          }
        )
      ];
    }

    (lib.mkIf (cfg.packages != { }) (
      let
        filterPackages = cond:
          let
            validPackages = lib.filterAttrs cond cfg.packages;
          in
          lib.mapAttrsToList (_: wrapper: wrapper.build.toplevel) validPackages;
      in
      {
        environment.systemPackages = filterPackages (_: wrapper: wrapper.enableInstall);

        systemd.packages = filterPackages (_: wrapper: wrapper.enableInstall && wrapper.enableInstallSystemdUnits);
      }
    ))
  ];
}
