{ config, lib, pkgs, wrapperManagerLib, ... }:

let
  cfg = config.programs.gnome-session;
  settingsFormat = wrapperManagerLib.formats.glibKeyfileIni { };
in
{
  options.programs.gnome-session = {
    package = lib.mkPackageOption pkgs "gnome-session" { };

    sessions = lib.mkOption {
      description = ''
        A set of desktop sessions to be configured with
        {manpage}`gnome-session(1)`. It generates all of the appropriate files
        for a desktop session including a Wayland session `.desktop` file, the
        desktop entries of the session's components, and a set of systemd
        units.

        :::{.note}
        In practice, you can only use either systemd or its custom system at
        any given point.
        :::

        Each of the attribute name is used as the identifier of the desktop
        environment.

        :::{.tip}
        While you can make identifiers in any way, it is encouraged to stick to
        a naming scheme. The recommended method is a reverse DNS-like scheme
        preferably with a domain name you own (e.g.,
        `com.example.MoseyBranch`).
        :::
      '';
      default = { };
      example = lib.literalExpression ''
        {
          "gnome-minimal" = let
            sessionCfg = config.programs.gnome-session.sessions."gnome-minimal";
          in
          {
            fullName = "GNOME (minimal)";
            description = "Minimal GNOME session";
            display = [ "wayland" "xorg" ];
            extraArgs = [ "--systemd" ];

            requiredComponents =
              let
                gsdComponents =
                  lib.map
                    (gsdc: "org.gnome.SettingsDaemon.''${gsdc}")
                    [
                      "A11ySettings"
                      "Color"
                      "Housekeeping"
                      "Power"
                      "Keyboard"
                      "Sound"
                      "Wacom"
                      "XSettings"
                    ];
              in
              gsdComponents ++ [ "org.gnome.Shell" ];

            systemd.targetUnit = {
              requires = [ "org.gnome.Shell.target" ];
              wants = lib.map (c: "''${c}.target") (lib.lists.remove "org.gnome.Shell" sessionCfg.requiredComponents);
            };
          };

          "one.foodogsquared.SimpleWay" = {
            fullName = "Simple Way";
            description = "A desktop environment featuring Sway window manager.";
            display = [ "wayland" ];
            extraArgs = [ "--systemd" ];

            components = {
              # This unit is intended to start with gnome-session.
              window-manager = {
                script = '''
                  ''${lib.getExe' config.programs.sway.package "sway"} --config ''${./config/sway/config}
                ''';
                description = "An i3 clone for Wayland.";

                systemd.serviceUnit = {
                  serviceConfig = {
                    Type = "notify";
                    NotifyAccess = "all";
                    OOMScoreAdjust = -1000;
                  };

                  unitConfig = {
                    OnFailure = [ "gnome-session-shutdown.target" ];
                    OnFailureJobMode = "replace-irreversibly";
                  };
                };

                systemd.targetUnit = {
                  requisite = [ "gnome-session-initialized.target" ];
                  partOf = [ "gnome-session-initialized.target" ];
                  before = [ "gnome-session-initialized.target" ];
                };
              };

              desktop-widgets = {
                script = '''
                  ''${lib.getExe' pkgs.ags "ags"} --config ''${./config/ags/config.js}
                ''';
                description = "A desktop widget system using layer-shell protocol.";

                systemd.serviceUnit = {
                  serviceConfig = {
                    OOMScoreAdjust = -1000;
                  };

                  path = with pkgs; [ ags ];

                  startLimitBurst = 5;
                  startLimitIntervalSec = 15;
                };

                systemd.targetUnit = {
                  requisite = [ "gnome-session-initialized.target" ];
                  partOf = [ "gnome-session-initialized.target" ];
                  before = [ "gnome-session-initialized.target" ];
                };
              };

              auth-agent = {
                script = "''${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
                description = "Authentication agent";

                systemd.serviceUnit = {
                  startLimitBurst = 5;
                  startLimitIntervalSec = 15;
                };

                systemd.targetUnit = {
                  partOf = [
                    "gnome-session.target"
                    "graphical-session.target"
                  ];
                  requisite = [ "gnome-session.target" ];
                  after = [ "gnome-session.target" ];
                };
              };
            };
          };
        }
      '';
      type = with lib.types; attrsOf (submoduleWith {
        modules = [ ./submodules/session-type.nix ];
        shorthandOnlyDefinesConfig = true;
        specialArgs = {
          inherit settingsFormat wrapperManagerLib pkgs;
        };
      });
    };
  };

  config = lib.mkIf (cfg.sessions != { }) {
    xdg.desktopEntries =
      let
        mkComponentEntry = _: component:
          lib.nameValuePair component.id component.desktopEntrySettings;

        mkSessionComponentDesktopEntries = _: session:
          lib.mapAttrs' mkComponentEntry session.components;
      in
      lib.concatMapAttrs mkSessionComponentDesktopEntries cfg.sessions;

    files =
      let
        mkSessionFiles = name: session: {
          "/share/wayland-sessions/${name}.desktop".text = ''
            [Desktop Entry]
            Name=${session.fullName}
            Comment=${session.description}
            Exec=${config.files."/libexec/${name}-session".source}
            Type=Application
            DesktopNames=${lib.concatStringsSep ";" session.desktopNames}
          '';

          "/share/gnome-session/sessions/${name}.session".source =
            settingsFormat.generate "session-${name}" session.settings;

          "/libexec/${name}-session" = {
            text = ''
              #!${pkgs.runtimeShell}

              ${lib.getExe' cfg.package "gnome-session"} ${
                lib.escapeShellArgs session.extraArgs
              }
            '';
            mode = "0755";
          };
        };
      in
      lib.concatMapAttrs mkSessionFiles cfg.sessions;

    programs.systemd.user.units =
      let
        inherit (wrapperManagerLib.systemd) intoUnit;
        mkSessionComponentUnits = _: component: {
          "${component.id}.service" = intoUnit component.systemd.serviceUnit;
          "${component.id}.target" = intoUnit component.systemd.targetUnit;
        } // lib.optionalAttrs (component.systemd.pathUnit != null) {
          "${component.id}.path" = intoUnit component.systemd.pathUnit;
        } // lib.optionalAttrs (component.systemd.socketUnit != null) {
          "${component.id}.socket" = intoUnit component.systemd.socketUnit;
        } // lib.optionalAttrs (component.systemd.timerUnit != null) {
          "${component.id}.timer" = intoUnit component.systemd.timerUnit;
        };

        mkSystemdUnitSet = _: session:
          {
            "${session.systemd.targetUnit.filename}" = wrapperManagerLib.systemd.intoUnit session.systemd.targetUnit;
          }
          // (lib.concatMapAttrs mkSessionComponentUnits session.components);
      in
      lib.concatMapAttrs mkSystemdUnitSet cfg.sessions;
  };
}
