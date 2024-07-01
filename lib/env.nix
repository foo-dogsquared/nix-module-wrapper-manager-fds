{ pkgs, lib, self }:

rec {
  /* Given the attrset for evaluating a wrapper-manager module, return a
     derivation containing the wrapper.
  */
  build = args:
    (eval args).config.build.toplevel;

  /* Evaluate a wrapper-manager configuration. */
  eval = {
    pkgs,
    modules ? [ ],
    specialArgs ? { },
  }:
    pkgs.lib.evalModules {
      modules = [ ../modules/wrapper-manager ] ++ modules;
      specialArgs = specialArgs // {
        modulesPath = builtins.toString ../modules/wrapper-manager;
      };
    };
}
