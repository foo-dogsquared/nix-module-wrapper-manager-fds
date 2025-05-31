let
  sources = import ../../npins;
in
{
  pkgs ? import sources.nixos-unstable { },
}:

let
  docs = import ../. { inherit pkgs; };
in
pkgs.mkShell {
  inputsFrom = [ docs.website ];

  packages = with pkgs; [
    importNpmLock.hooks.linkNodeModulesHook
    nodejs
    nodePackages.prettier
    vscode-langservers-extracted
    vale-ls
  ];

  npmDeps = pkgs.importNpmLock.buildNodeModules {
    npmRoot = ./.;
    inherit (pkgs) nodejs;
  };
}
