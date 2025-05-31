let
  sources = import ./npins;
in
{
  pkgs ? import sources.nixos-unstable { },
}:

let
  docs = import ./docs { inherit pkgs; };
in
pkgs.mkShell {
  inputsFrom = [ docs.website ];

  packages = with pkgs; [
    npins
    treefmt
    nixfmt-rfc-style
    nixdoc

    # For easy validation of the test suite.
    yajsv
    jq
  ];
}
