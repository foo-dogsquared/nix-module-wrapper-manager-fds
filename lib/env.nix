/**
  The VERY VERY root of wrapper-manager. This is the subset involving
  wrapper-manager environments. So far, you can evaluate and build a
  wrapper-manager configuration.

  This means in theory, you could build wrapper-manager packages inside of a
  wrapper-manager configuration. (But I don't encourage it.)
*/
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
      class = "wrapperManager";
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

        # But we're also relying on the initial nixpkgs version to have the
        # similar implementation for these modules. It's not great but it
        # should be fine for 95% of the time.
        #
        # !!! This is not viable to placed modularly since `pkgs` is also set
        # the same way so the infamous infinite recursion is inbound if you do
        # this.
        "${pkgs.path}/nixos/modules/misc/assertions.nix"
        "${pkgs.path}/nixos/modules/misc/meta.nix"
      ] ++ modules;
    };
}
