let
  sources = import ./npins;
in
{
  pkgs ? import sources.nixos-unstable { },
}:

let
  docs = import ./docs { inherit pkgs; };
  website = docs.website { };
in
pkgs.mkShell {
  inputsFrom = [ website ];

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
