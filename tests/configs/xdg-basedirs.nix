{
  config,
  lib,
  pkgs,
  wrapperManagerLib,
  ...
}:

{
  xdg.configDirs = wrapperManagerLib.getXdgConfigDirs (
    with pkgs;
    [
      yt-dlp
    ]
  );

  xdg.dataDirs = wrapperManagerLib.getXdgDataDirs (
    with pkgs;
    [
      yt-dlp
    ]
  );

  wrappers.xdg-config-dirs-script = {
    arg0 =
      let
        app = pkgs.writeShellScript "xdg-dirs-script" ''
          echo "$XDG_CONFIG_DIRS" | tr ':' '\n'
        '';
      in
      builtins.toString app;
  };

  wrappers.xdg-data-dirs-script = {
    arg0 =
      let
        app = pkgs.writeShellScript "xdg-dirs-script" ''
          echo "$XDG_DATA_DIRS" | tr ':' '\n'
        '';
      in
      builtins.toString app;
  };

  build.extraPassthru.wrapperManagerTests = {
    actuallyBuilt =
      let
        wrapper = config.build.toplevel;
      in
      pkgs.runCommand "wrapper-manager-xdg-desktop-entry-actually-built" { } ''
        [ -x "${wrapper}/bin/xdg-data-dirs-script" ] && {
          ${lib.getExe' wrapper "xdg-data-dirs-script"} | grep "${pkgs.yt-dlp}/share" > /dev/null
        } && [ -x "${wrapper}/bin/xdg-config-dirs-script" ] && {
          ${lib.getExe' wrapper "xdg-config-dirs-script"} | grep "${pkgs.yt-dlp}/etc/xdg" > /dev/null
        } && touch $out
      '';
  };
}
