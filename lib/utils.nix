{
  pkgs,
  lib,
  self,
}:

rec {
  /**
    Given a list of derivations, return a list of the store path with the `bin`
    output (or at least with "/bin" in each of the paths).

    # Arguments

    drvs
    : A list of derivations.

    # Type

    ```
    getBin :: [ Derivation ] -> [ Path ]
    ```

    # Examples

    ```
    getBin (with pkgs; [ hello coreutils ])
    =>
    [
      "/nix/store/HASH-hello/bin"
      "/nix/store/HASH-coreutils/bin"
    ]
    ```
  */
  getBin = drvs: builtins.map (v: lib.getBin v) drvs;

  /**
    Given a list of derivations, return a list of the store paths with the
    `libexec` appended.

    # Arguments

    drvs
    : A list of derivations.

    # Type

    ```
    getLibexec :: [ Derivation ] -> [ Path ]
    ```

    # Examples

    ```
    getLibexec (with pkgs; [ hello coreutils ])
    =>
    [
      "/nix/store/HASH-hello/libexec"
      "/nix/store/HASH-coreutils/libexec"
    ]
    ```
  */
  getLibexec = drvs: builtins.map (v: "${v}/libexec") drvs;

  /**
    Given a list of derivations, return a list of the store paths appended with
    `/etc/xdg` suitable as part of the XDG_CONFIG_DIRS environment variable.

    # Arguments

    drvs
    : A list of derivations.

    # Type

    ```
    getXdgConfigDirs :: [ Derivation ] -> [ Path ]
    ```

    # Examples

    ```
    getXdgConfigDirs (with pkgs; [ hello coreutils ])
    =>
    [
      "/nix/store/HASH-hello/etc/xdg"
      "/nix/store/HASH-coreutils/etc/xdg"
    ]
    ```
  */
  getXdgConfigDirs = drvs: builtins.map (v: "${v}/etc/xdg") drvs;

  /**
    Given a list of derivations, return a list of store paths appended with
    `/share` suitable as part of the XDG_DATA_DIRS environment variable.

    # Arguments

    drvs
    : A list of derivations.

    # Type

    ```
    getXdgDataDirs :: [ Derivation ] -> [ Path ]
    ```

    # Examples

    ```
    getXdgDataDirs (with pkgs; [ hello coreutils ])
    =>
    [
      "/nix/store/HASH-hello/share"
      "/nix/store/HASH-coreutils/share"
    ]
    ```
  */
  getXdgDataDirs = drvs: builtins.map (v: "${v}/share") drvs;

  /**
    Split a string only once with the rest of the string intact.

    # Arguments

    Same as `lib.splitString` from nixpkgs.

    # Type

    ```
    splitStringOnce :: str -> str -> [ str str ]
    ```

    # Example

    ```nix
    splitStringOnce "/" "foodogsquared@.d/custom-settings"
    => [ "foodogsquared@.d" "custom-settings" ]

    splitStringOnce "/" "hello/there/world"
    => [ "hello" "there/world" ]

    splitStringOnce ":" "HELLO/THERE/DOGGO"
    => [ "HELLO/THERE/DOGGO" ]
    ```
  */
  splitStringOnce =
    sep: s:
      let
        s' = lib.splitString sep s;
      in
      if lib.length s' == 1 then
        s'
      else
        [ (lib.head s') ] ++ [ (lib.concatStringsSep sep (lib.drop 1 s')) ];
}
