let
  sources = import ../../npins;
in
{
  pkgs ? import sources.nixos-unstable { },
}:

let
  wmLib = (import ../../. { }).lib;
  build = args: wmLib.build (args // { inherit pkgs; });
in
{
  fastfetch = build { modules = [ ./wrapper-fastfetch.nix ]; };
  neofetch = build {
    modules = [ ./wrapper-neofetch.nix ];
    specialArgs.yourMomName = "Yor mom";
  };
  xdg-desktop-entry = build { modules = [ ./xdg-desktop-entry.nix ]; };
  xdg-basedirs = build { modules = [ ./xdg-basedirs.nix ]; };
  single-basepackage = build { modules = [ ./single-basepackage.nix ]; };
  neofetch-with-additional-files = build { modules = [ ./neofetch-with-additional-files.nix ]; };
  lib-modules-make-wraparound = build { modules = [ ./lib-modules-subset/make-wraparound.nix ]; };
  systemd-units = build { modules = [ ./systemd-units.nix ]; };
  wrappers-with-systemd-units = build { modules = [ ./wrappers-with-systemd-enabled.nix ]; };
  data-format-files = build { modules = [ ./data-format-files.nix ]; };
  systemd-lib-module-test = build { modules = [ ./systemd-lib-module-test.nix ]; };
  gnome-session-basic-example = build { modules = [ ./gnome-session-basic-example.nix ]; };
}
