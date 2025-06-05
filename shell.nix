let
  sources = import ./npins;
in
{
  pkgs ? import sources.nixos-unstable { },
}:

let
  docs = import ./docs { inherit pkgs; };
  docsDevshell = import ./docs/website/shell.nix { inherit pkgs; };
in
pkgs.mkShell {
  inputsFrom = [ docs.website ];

  npmDeps = pkgs.importNpmLock.buildNodeModules {
    npmRoot = ./docs/website;
    inherit (pkgs) nodejs;
  };

  packages = with pkgs; [
    importNpmLock.hooks.linkNodeModulesHook
    nodejs
    nodePackages.prettier
    vscode-langservers-extracted
    vale-ls

    npins
    treefmt
    nixfmt-rfc-style
    nixdoc

    # For easy validation of the test suite.
    yajsv
    jq
  ];
}
