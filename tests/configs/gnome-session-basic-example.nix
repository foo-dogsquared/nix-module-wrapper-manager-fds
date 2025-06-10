{ config, lib, pkgs, ... }:

let
  workflowId = "com.example.ExampleSession";
in
{
  programs.gnome-session.sessions."${workflowId}" = {
    fullName = "Example Session";
    desktopNames = [ workflowId ];

    components = {
      window-manager = {
        script = lib.getExe' pkgs.emptyDirectory "window-manager-bazaar-galore-mania-6000-from-the-future";
        description = "Window manager";

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

          startLimitBurst = 5;
          startLimitIntervalSec = 10;
        };

        systemd.targetUnit = {
          partOf = [ "gnome-session-initialized.target" ];
          after = [ "gnome-session-initialized.target" ];
        };
      };

      desktop-widgets = {
        script = lib.getExe' pkgs.emptyDirectory "desktop-widget-system";
        description = "Desktop widgets";

        systemd.serviceUnit = {
          serviceConfig = {
            Type = "notify";
            NotifyAccess = "all";
            OOMScoreAdjust = -1000;
          };

          listenOn = [ "0.0.0.0:7432" ];
          watchFilesFrom = [ "%D/${workflowId}" ];

          unitConfig = {
            OnFailure = [ "gnome-session-shutdown.target" ];
            OnFailureJobMode = "replace-irreversibly";
          };
        };

        systemd.targetUnit = {
          partOf = [ "gnome-session-initialized.target" ];
          after = [ "gnome-session-initialized.target" ];
        };
      };

      auth-agent = {
        script = lib.getExe' pkgs.emptyDirectory "authenticator-3000";
        description = "Authentication agent";

        systemd.serviceUnit = {
          serviceConfig = {
            Type = "notify";
            NotifyAccess = "all";
            OOMScoreAdjust = -500;
          };
        };

        systemd.targetUnit = {
          partOf = [ "graphical-session.target" "gnome-session.target" ];
        };
      };
    };
  };

  build.extraPassthru.wrapperManagerTests = {
    actuallyBuilt = let
      wrapper = config.build.toplevel;
    in
      pkgs.runCommand "wrapper-manager-test-gnome-session-actually-built" { } ''
        [ -x "${wrapper}/libexec/${workflowId}-session" ] \
        && [ -f "${wrapper}/share/gnome-session/sessions/${workflowId}.session" ] \
        && [ -f "${wrapper}/share/wayland-sessions/${workflowId}.desktop" ] \
        && [ -f "${wrapper}/share/applications/${workflowId}.desktop-widgets.desktop" ] \
        && [ -f "${wrapper}/share/applications/${workflowId}.auth-agent.desktop" ] \
        && [ -f "${wrapper}/share/applications/${workflowId}.window-manager.desktop" ] \
        && [ -f "${wrapper}/etc/systemd/user/gnome-session@${workflowId}.target.d/session.conf" ] \
        && [ -f "${wrapper}/etc/systemd/user/${workflowId}.desktop-widgets.service" ] \
        && [ -f "${wrapper}/etc/systemd/user/${workflowId}.desktop-widgets.socket" ] \
        && [ -f "${wrapper}/etc/systemd/user/${workflowId}.desktop-widgets.target" ] \
        && [ -f "${wrapper}/etc/systemd/user/${workflowId}.desktop-widgets.path" ] \
        && [ -f "${wrapper}/etc/systemd/user/${workflowId}.auth-agent.service" ] \
        && [ -f "${wrapper}/etc/systemd/user/${workflowId}.auth-agent.target" ] \
        && [ -f "${wrapper}/etc/systemd/user/${workflowId}.window-manager.service" ] \
        && [ -f "${wrapper}/etc/systemd/user/${workflowId}.window-manager.target" ] \
        && touch $out
      '';

    checkMetadata =
      let
        workflowSettings = config.programs.gnome-session.sessions.${workflowId};
      in
      lib.optionalAttrs (
        lib.length workflowSettings.requiredComponents == 3
        && workflowSettings.components.desktop-widgets.id == "${workflowId}.desktop-widgets"
        && workflowSettings.components.desktop-widgets.systemd.socketUnit != null
        && workflowSettings.components.desktop-widgets.systemd.pathUnit != null
        && workflowSettings.components.auth-agent.id == "${workflowId}.auth-agent"
        && workflowSettings.components.auth-agent.systemd.socketUnit == null
        && workflowSettings.components.auth-agent.systemd.pathUnit == null
        && workflowSettings.components.window-manager.id == "${workflowId}.window-manager"
        && workflowSettings.components.window-manager.systemd.socketUnit == null
        && workflowSettings.components.window-manager.systemd.pathUnit == null
      ) pkgs.emptyFile;
  };
}
