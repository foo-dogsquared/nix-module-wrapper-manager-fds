{ config, lib, pkgs, ... }:

{
  dataFormats.files."/etc/app/config.json" = {
    variant = "json";
    content = {
      words.allowlist = [
        "Why,"
        "Hello"
        "There"
      ];

      words.denylist = [
        "What"
        "WUUUUUUUUUUUUT"
        "WHHHUUUUUUUUUUUUUUUUUUUUUUUT"
      ];
    };
  };

  dataFormats.files."/etc/com.example.SampleApp/config" = {
    variant = "toml";

    # This is just to test if it's possible to merge them (AKA define them in
    # two different modules).
    content = lib.mkMerge [
      {
        health = 1.0000;
        battle.skills = [
          "Fireball"
          "Pocket sand"
        ];
      }

      {
        battle.skills = lib.mkBefore [
          "Mach 13 Elephant Explosion"
          "Galaxy Impact"
        ];
      }
    ];
  };

  dataFormats.files."share/org.example.SampleApp/config.ini" = {
    variant = "ini";
    content = lib.mkMerge [
      {
        "Desktop Thingies" = {
          MouseSupport = true;
          ControllerSupport = true;
        };

        "Temper Issues" = {
          DontHaveManagementLessons = true;
          MaximumHeatTolerance = 90;
          MinimumHeatTolerance = 35;
        };
      }

      {
        "Desktop Thingies" = {
          MouseSupport = lib.mkForce false;
          ControllerSupport = lib.mkDefault false;
        };
      }
    ];
  };

  build.extraPassthru.wrapperManagerTests = {
    actuallyBuilt =
      let
        wrapper = config.build.toplevel;
      in
      pkgs.runCommand "wrapper-manager-data-files-actually-built" { } ''
        [ -f "${wrapper}/etc/com.example.SampleApp/config" ] \
        && [ -f "${wrapper}/etc/app/config.json" ] \
        && [ -f "${wrapper}/share/org.example.SampleApp/config.ini" ] \
        && touch $out
      '';
  };
}
