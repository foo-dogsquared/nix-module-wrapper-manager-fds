# These are functions that are only meant to be invoked inside of a
# wrapper-manager environment.
#
# On a note for wrapper-manager developer(s), due to how tedious it can be to
# test library functions like that, we're putting them inside of the test
# configs instead of the typical library test suite.
{
  pkgs,
  lib,
  self,
}:

rec {
  /**
    Make a wrapper-manager wrapper config containing a sub-wrapper that wraps
    another program. Several examples of this includes sudo, Bubblewrap, and
    Gamescope.

    # Arguments

    Its arguments is a sole attribute set with the following expected
    attributes:

    arg0
    : Similar to `wrappers.<name>.arg0` from wrapper-manager module, it is a
    store path containing an executable used as the main program of the wrapper.

    under
    : Similar to `arg0` but for the wraparound (e.g., sudo, doas, Bubblewrap).

    underFlags
    : Arguments of the wraparound. Defaults to an empty list.

    underSeparator
    : An optional string acting as the separator between the wraparound's
    arguments and the arg0's arguments.

    Note that the argument attrset can contain any attribute. The attrset is
    then separated as a module and an additional module using the above
    attributes.

    # Type

    ```
    makeWraparound :: Attr -> Module
    ```

    # Example

    ```
    makeWraparound {
      arg0 = lib.getExe' pkgs.hello "hello";
      appendArgs = [ "--traditional" ];
      under = lib.getExe' pkgs.sudo "sudo";
      underFlags = [ "-u" "admin" ];
    }
    =>
    {
      _type = "merge";
      contents = [ ... ];
    }
    ```
  */
  makeWraparound =
    {
      arg0,
      under,
      underFlags ? [ ],
      underSeparator ? "",
      ...
    }@module:
    let
      # These are the attrnames that would be overtaken with the function and
      # will be merged anyways so...
      functionArgs = builtins.functionArgs makeWraparound;
      module' = lib.removeAttrs module (lib.attrNames functionArgs);
    in
    lib.mkMerge [
      {
        arg0 = under;

        # This should be the very first things to be in the arguments so
        # we're just making sure that it is the case. The priority is chosen
        # arbitrarily just in case the user already has `prependArgs` values
        # with `lib.mkBefore` for the original arg0.
        prependArgs = mkWraparoundBefore (
          underFlags ++ lib.optionals (underSeparator != "") [ underSeparator ] ++ [ arg0 ]
        );
      }

      # It's constructed like this to make it ergonomic to use. The user can
      # simply delete the makeWraparound exclusive arguments and still work
      # normally.
      module'
    ];

  /**
    Create a order priority value assigned for wraparound arguments.

    # Arguments

    Same as nixpkgs' `lib.mkBefore` and `lib.mkAfter`.

    # Examples

    ```nix
    mkWraparoundBefore wraparoundArgs ++ [ "--" ] ++ [ (lib.getExe pkgs.hello) ]
    ```
  */
  mkWraparoundBefore = lib.mkOrder 250;
}
