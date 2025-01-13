rec {
  /**
    Given the attrset for evaluating a wrapper-manager module, return a
    derivation containing the wrapper.

    # Arguments

    It has the same arguments as
    [`wrapperManagerLib.env.eval`](#function-library-wrapperManagerLib.env.eval).

    # Type

    ```
    build :: Attr -> Derivation
    ```

    # Example

    ```
    build {
      pkgs = import <nixpkgs> { };
      modules = [
        ./wrapper-manager-config.nix
        ./modules/wrapper-manager
      ];
    }
    =>
    <drv>
    ```
  */
  build = args: (eval args).config.build.toplevel;

  /**
    Evaluate a wrapper-manager configuration.

    # Arguments

    Its argument only expects a sole attribute set with the following
    attributes:

    pkgs
    : A nixpkgs instance.

    lib
    : The nixpkgs library subset. Defaults to `pkgs.lib` from the given nixpkgs
    instance.

    modules
    : A list of additional wrapper-manager modules to be imported (typically
    the wrapper-manager configuration and additional modules) for the final
    configuration.

    specialArgs
    : An additional set of module arguments that can be used in `imports`.

    # Type

    ```
    eval :: Attr -> Attr
    ```

    # Example

    ```
    eval {
      pkgs = import <nixpkgs> { };
      modules = [
        ./wrapper-manager-config.nix
        ./modules/wrapper-manager
      ];
    }
    =>
    {
      _module = { ... };
      _type = "configuration";
      class = null;
      config = { ... };
      options = { ... };
      extendModules = <func>;
    }
    ```
  */
  eval =
    {
      pkgs,
      lib ? pkgs.lib,
      modules ? [ ],
      specialArgs ? { },
    }:
    lib.evalModules {
      specialArgs = specialArgs // {
        modulesPath = builtins.toString ../modules/wrapper-manager;
      };
      modules = [
        ../modules/wrapper-manager

        # Setting pkgs modularly. This would make setting up wrapper-manager
        # with different nixpkgs instances possible but it isn't something that
        # is explicitly supported.
        (
          { lib, ... }:
          {
            config._module.args.pkgs = lib.mkDefault pkgs;
          }
        )
      ] ++ modules;
    };
}
