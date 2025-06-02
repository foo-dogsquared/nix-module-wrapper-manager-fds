let
  sources = import ../../npins;
in
{ pkgs ? import sources.nixos-unstable { } }:

let
  lib = import ../../lib { inherit pkgs; };
  callLib =
    file:
    import file {
      inherit (pkgs) lib;
      inherit pkgs;
      self = lib;
    };
in
{
  env = callLib ./env;
  generators = callLib ./generators;
  utils = callLib ./utils.nix;
}
