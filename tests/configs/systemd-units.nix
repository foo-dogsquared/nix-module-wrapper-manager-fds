{ config, lib, pkgs, ... }:

{
  programs.systemd.system.services = {
    hello = {
      description = "wrapper-manager systemd service example";
      path = with pkgs; [ hello ];
      script = ''
        hello --help
      '';
      startAt = "weekly";
    };

    "there/10-hello" = {
      description = "wrapper-manager systemd service override example";
      wantedBy = [ "graphical.target" "gnome-session@sample.target" ];
    };

    "there/20-hello-again" = {
      wantedBy = [ "womp-womp.target" ];
    };

    service-with-custom-sections = {
      description = "wrapper-manager systemd unit with custom sections";
      wantedBy = [ "graphical.target" "gnome-session@sample.target" ];
      extraSectionsConfig = {
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
      };
    };
  };

  programs.systemd.system.sockets.hello = {
    description = "Hello socket";
    before = [ "multi-user.target" ];
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "%t/hello" ];
  };

  programs.systemd.user.targets.activitywatch = {
    wantedBy = [ "default.target" ];
    after = [ "default.target" ];
    description = "ActivityWatch server";
    requires = [ "default.target" ];
  };

  # An override drop-in target unit.
  programs.systemd.user.targets."gnome-session@one.foodogsquared.HorizontalHunger/session" = {
    wants = let
      gsdComponents =
        lib.map
        (gsdc: "org.gnome.SettingsDaemon.${gsdc}")
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
      lib.map (n: "${n}.target") (gsdComponents ++ [ "org.gnome.Shell" ]);
    requires = [ "org.gnome.Shell.target" ];
  };

  programs.systemd.user.services = {
    hello = {
      description = "Greeting service";
      path = with pkgs; [ hello hello-go ];
      script = ''
        hello
      '';
    };

    # OK, we're just trying to recreate this unit if it's doable.
    "gnome-session-manager@" = {
      description = "GNOME Session Manager (session: %i)";
      unitConfig = {
        RefuseManualStart = true;
        RefuseManualStop = true;
        OnFailureJobMode = "replace-irreversibly";
        CollectMode = "inactive-or-failed";
      };
      onFailure = [
        "gnome-session-shutdown.target"
      ];
      requisite = [ "gnome-session-pre.target" ];
      after = [ "gnome-session-pre.target" ];

      requires = [ "gnome-session-manager.target" ];
      partOf = [ "gnome-session-manager.target" ];
      before = [ "gnome-session-manager.target" ];
      serviceConfig = {
        Type = "notify";
        ExecStart = "gnome-session-binary --systemd-service --session=%i";
        ExecStopPost = "-gnome-session-ctl --shutdown";
      };
    };

    "gnome-session-manager@one.foodogsquared.HorizontalHunger/10-gnome-session-wrapper-manager-override" = {
      description = "Another override unit";
    };
  };

  build.extraPassthru.wrapperManagerTests = {
    actuallyBuilt =
      let
        wrapper = config.build.toplevel;
      in
      pkgs.runCommand "wrapper-manager-systemd-units-actually-built" { } ''
        [ -f "${wrapper}/etc/systemd/system/hello.service" ] \
        && [ -f "${wrapper}/etc/systemd/system/hello.timer" ] \
        && [ -f "${wrapper}/etc/systemd/system/service-with-custom-sections.service" ] \
        && [ -f "${wrapper}/etc/systemd/system/there.service.d/10-hello.conf" ] \
        && [ -f "${wrapper}/etc/systemd/system/there.service.d/20-hello-again.conf" ] \
        && [ -f "${wrapper}/etc/systemd/system/hello.socket" ] \
        && [ -f "${wrapper}/etc/systemd/user/activitywatch.target" ] \
        && [ -f "${wrapper}/etc/systemd/user/hello.service" ] \
        && [ -f "${wrapper}/etc/systemd/user/gnome-session-manager@.service" ] \
        && [ -f "${wrapper}/etc/systemd/user/gnome-session-manager@one.foodogsquared.HorizontalHunger.service.d/10-gnome-session-wrapper-manager-override.conf" ] \
        && touch $out
      '';
  };
}
