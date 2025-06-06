{ config, lib, pkgs, ... }:

{
  wrappers.fastfetch = {
    arg0 = lib.getExe' pkgs.fastfetch "fastfetch";
    appendArgs = [ "--logo" "Guix" ];
    env.NO_COLOR.value = "1";
    systemd.enable = true;
    systemd.serviceUnit = {
      enable = true;
      settings = {
        description = "fastfetch service that exists for some reason";
        wantedBy = [ "default.target" ];
        extraSectionsConfig.HELLO.THERE = [ "WORLD" "WITH" "COMMA" ];
      };
    };
  };

  wrappers.yt-dlp-audio = {
    arg0 = lib.getExe' pkgs.yt-dlp "yt-dlp";
    appendArgs = [ "--config-location" (placeholder "out") ];
    systemd.enable = true;
    systemd.variant = "system";
    systemd.serviceUnit = {
      enable = true;
      settings = {
        startAt = "daily";
        watchFilesFrom = [
          "%h/.config/yt-dlp"
        ];
        listenOn = [
          "0.0.0.0:993"
        ];
      };
    };
  };

  build.extraPassthru.wrapperManagerTests = {
    actuallyBuilt =
      let
        wrapper = config.build.toplevel;
      in
      pkgs.runCommand "wrapper-manager-wrappers-with-systemd-units-actually-built" { } ''
        [ -x "${wrapper}/bin/fastfetch" ] \
        && [ -f "${wrapper}/etc/systemd/user/fastfetch.service" ] \
        && [ -x "${wrapper}/bin/yt-dlp-audio" ] \
        && [ -f "${wrapper}/etc/systemd/system/yt-dlp-audio.service" ] \
        && [ -f "${wrapper}/etc/systemd/system/yt-dlp-audio.timer" ] \
        && [ -f "${wrapper}/etc/systemd/system/yt-dlp-audio.path" ] \
        && [ -f "${wrapper}/etc/systemd/system/yt-dlp-audio.socket" ] \
        && touch $out
      '';
  };
}
