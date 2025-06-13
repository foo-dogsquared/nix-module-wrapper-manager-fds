{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.build = {
    drvName = lib.mkOption {
      type = lib.types.nonEmptyStr;
      description = ''
        The name of the final derivation output.
      '';
      default =
        if lib.isList config.basePackages then
          "wrapper-manager-fds-wrapped-package"
        else
          let
            package = config.basePackages;
          in
          "${package.pname}-${package.version}-wm-wrapped";
      defaultText = ''
        if `config.basePackages` is a list then
          `"wrapper-manager-fds-wrapped-package"`
        else
          `"''$PACKAGE_PNAME-$PACKAGE_VERSION-wm-wrapped"`
      '';
      example = "my-custom-package-name";
    };

    variant = lib.mkOption {
      type = lib.types.enum [
        "binary"
        "shell"
      ];
      description = ''
        Indicates the type of wrapper to be made. By default, wrapper-manager
        sets this to `binary`.
      '';
      default = "binary";
      example = "shell";
    };

    extraSetup = lib.mkOption {
      type = lib.types.lines;
      description = ''
        Additional script for setting up the wrapper script derivation.
      '';
      default = "";
    };

    extraPassthru = lib.mkOption {
      type = with lib.types; attrsOf anything;
      description = ''
        Set of data to be passed through `passthru` of the resulting
        derivation.
      '';
      default = { };
    };

    extraMeta = lib.mkOption {
      type = with lib.types; attrsOf anything;
      description = ''
        Additional attributes to be passed as part of `meta` in the resulting
        derivation.
      '';
      default = { };
      example = lib.literalExpression ''
        {
          mainProgram = config.wrappers.hello.executableName;
        }
      '';
    };

    toplevel = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      internal = true;
      description = "A derivation containing the wrapper script.";
    };
  };

  config = {
    build = {
      toplevel =
        let
          inherit (config.build) variant;
          makeWrapperArg0 =
            if variant == "binary" then
              "makeBinaryWrapper"
            else if variant == "shell" then
              "makeShellWrapper"
            else
              "makeWrapper";

          mkWrapBuild =
            wrappers:
            lib.concatMapStrings (v: ''
              ${makeWrapperArg0} "${v.arg0}" "${builtins.placeholder "out"}/bin/${v.executableName}" ${lib.concatStringsSep " " v.makeWrapperArgs}
            '') wrappers;

          mkDesktopEntries = desktopEntries: builtins.map (entry: pkgs.makeDesktopItem entry) desktopEntries;

          desktopEntries = mkDesktopEntries (lib.attrValues config.xdg.desktopEntries);
        in
        if lib.isList config.basePackages then
          pkgs.buildEnv {
            passthru = config.build.extraPassthru;
            meta = config.build.extraMeta;
            name = config.build.drvName;
            paths = desktopEntries ++ config.basePackages;
            nativeBuildInputs =
              if variant == "binary" then
                [ pkgs.makeBinaryWrapper ]
              else if variant == "shell" then
                [ pkgs.makeShellWrapper ]
              else
                [ ];
            postBuild = ''
              ${config.build.extraSetup}
              ${mkWrapBuild (lib.attrValues config.wrappers)}
            '';
          }
        else
          config.basePackages.overrideAttrs (
            final: prev: {
              name = config.build.drvName;
              nativeBuildInputs =
                (prev.nativeBuildInputs or [ ])
                ++ (
                  if variant == "binary" then
                    [ pkgs.makeBinaryWrapper ]
                  else if variant == "shell" then
                    [ pkgs.makeShellWrapper ]
                  else
                    [ ]
                )
                ++ lib.optionals (config.xdg.desktopEntries != { }) [ pkgs.copyDesktopItems ];
              desktopItems = (prev.desktopItems or [ ]) ++ desktopEntries;
              postFixup = ''
                ${prev.postFixup or ""}
                ${mkWrapBuild (lib.attrValues config.wrappers)}
              '';
              passthru = lib.recursiveUpdate (prev.passthru or { }) (
                config.build.extraPassthru
                // {
                  unwrapped = config.basePackages;
                }
              );
              meta = lib.recursiveUpdate (prev.meta or { }) config.build.extraMeta;
            }
          );
    };
  };
}
