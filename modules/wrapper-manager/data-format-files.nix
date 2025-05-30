{ config, lib, pkgs, options, ... }:

let
  cfg = config.dataFormats;

  dataFileModule = { config, name, lib, ... }: {
    options = {
      target = lib.mkOption {
        type = lib.types.str;
        description = ''
          Path relative to the derivation output path.
        '';
        example = lib.literalExpression "/etc/xdg/app/config.json";
        default = name;
      };

      variant = lib.mkOption {
        type = lib.types.nonEmptyStr;
        description = ''
          Indicates what data format to generate for the data file from
          {option}`dataFormats.formats`.
        '';
        default = "json";
        example = "yaml";
      };

      mode = lib.mkOption {
        type = lib.types.strMatching "[0-7]{3,4}";
        default = "0444";
        example = "0600";
        description = ''
          Permissions to be given to the file. By default, it is given with a
          symlink.
        '';
      };

      content = lib.mkOption {
        type = cfg.formats.${config.variant}.type // {
          description = "given from {option}`dataFormats.formats.<variant>.type`";
        };
        description = ''
          The data content structure in accordance to the variant's type.
        '';
        example = lib.literalExpression ''
          {
            num_of_boundaries = 67;
            battle.skills = [
              "Bushido Flow"
              "Shy Supernova"
              "Mach 13 Elephant Explosion"
              "Steel Python"
              "Cashmere Cannonball"
            ];
          }
        '';
      };
    };
  };

  formatModule = { name, ... }: {
    freeformType = with lib.types; attrsOf anything;

    options = {
      type = lib.mkOption {
        type = lib.types.optionType;
        description = ''
          The module option type for the value of the Nix-representable format.
        '';
      };

      generate = lib.mkOption {
        type = with lib.types; functionTo (functionTo package);
        description = ''
          The generator function for the Nix-representable format.
        '';
      };
    };
  };
in
{
  options.dataFormats = {
    formats = lib.mkOption {
      type = with lib.types; attrsOf (submodule formatModule);
      description = ''
        A set of [Nix-representable
        formats](https://nixos.org/manual/nixos/unstable/#sec-settings-nix-representable)
        to generate the files configured from
        {option}`dataFormats.files.<name>.content`.
      '';
      default = { };
      example = lib.literalExpression ''
        {
          json = pkgs.formats.json { };
          ini = pkgs.formats.ini { };
        }
      '';
    };

    enableCommonFormats =
      lib.mkEnableOption null // {
        description = ''
          Whether to initialize {option}`dataFormats.formats` with common formats.

          For future references, the formats exported are JSON, YAML, TOML, and
          INI. With the following code being equivalent to the module effect:

          ```nix
          {
            json = pkgs.formats.json { };
            yaml = pkgs.formats.yaml { };
            toml = pkgs.formats.toml { };
            ini = pkgs.formats.ini { };
          }
          ```
        '';
        default = true;
        example = false;
      };

    files = lib.mkOption {
      type = with lib.types; attrsOf (submodule dataFileModule);
      default = { };
      description = ''
        A set of data files to be exported to the package.
      '';
      example = lib.literalExpression ''
        {
          "share/lazygit/config.yml" = {
            variant = "yaml";
            content = lib.mkMerge [
              {
                gui = {
                  expandFocusedSidePanel = true;
                  showBottomLine = false;
                  skipRewordInEditorWarning = true;
                  theme = {
                    selectedLineBgColor = [ "reverse" ];
                    selectedRangeBgColor = [ "reverse" ];
                  };
                };
                notARepository = "skip";
              }

              {
                gui.expandFocusedSidePanel = lib.mkForce false;
              }
            ];
          };

          "/etc/hello/config.json" = {
            variant = "json";
            content = {
              locale = "FR";
              defaultName = "Gretchen";
              defaultFormat = "long";
            };
          };
        }
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enableCommonFormats {
      dataFormats.formats = {
        json = pkgs.formats.json { };
        toml = pkgs.formats.toml { };
        yaml = pkgs.formats.yaml { };
        ini = pkgs.formats.ini { };
      };
    })

    (lib.mkIf (cfg.files != { }) {
      files =
        let
          generateFile = n: v:
            lib.nameValuePair n {
              inherit (v) mode;
              source = cfg.formats.${v.variant}.generate "wrapper-manager-data-file-${builtins.baseNameOf n}" v.content;
            };
        in
        lib.mapAttrs' generateFile cfg.files;
    })
  ];
}
