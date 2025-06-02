{ pkgs, lib, self }:

{
  /**
    Render a given value to systemd INI data format.

    As an implementation detail, this only goes with the basic interpretation
    of how systemd parses its INI-like configuration files where it can do
    arbitrary things for arbitrary sections such as interpreting multiple sections
    with the same name as a list.

    # Arguments

    value
    : The data settings. It's expected to be an attrset of attrsets
    representing section groups and their settings. The section value can also
    accept a list of attrsets representing multiple sections with the same name.

    # Type

    ```
    toSystemdINI :: Attrs -> String
    ```

    # Example

    ```nix
    toSystemdINI { hello.world = "greeting"; }
    => ''
      [hello]
      world=greeting
    ''

    toSystemdINI {
      # This is supposed to represent multiple sections with the same name.
      Network = [
        { Match = "enps30"; }
        { Match = "ens0"; }
      ];
    }
    => ''
      [Network]
      Match=enps30

      [Network]
      Match=ens0
    ''
    ```
  */
  toSystemdINI = attrsOfSections:
    let
      mkSectionName = (name: lib.escape [ "[" "]" ] name);

      toKeyValue = lib.generators.toKeyValue {
        mkKeyValue = lib.generators.mkKeyValueDefault { } "=";
        listsAsDuplicateKeys = true;
      };

      # map function to string for each key val
      mapAttrsToStringsSep =
        sep: mapFn: attrs:
        lib.concatStringsSep sep (lib.mapAttrsToList mapFn attrs);

      mkSection =
        sectName: sectValues:
        if lib.isList sectValues then
          lib.concatMapStringsSep "\n"
            (v: ''
              [${mkSectionName sectName}]
            ''
            + toKeyValue v) sectValues
        else
          ''
            [${mkSectionName sectName}]
          ''
          + toKeyValue sectValues;
    in
    mapAttrsToStringsSep "\n" mkSection attrsOfSections;
}
