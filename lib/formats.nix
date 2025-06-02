{ pkgs, lib, self }:

rec {
  /**
    Nix-representable data format for systemd INI format as described from
    {manpage}`systemd.syntax(5)`.

    # Arguments

    An empty attribute set. This is set for forward-compatability for
    future settings that some Nix formats already does (such as
    `pkgs.formats.ini` and `pkgs.formats.elixir`).

    It has no settings for now.

    # Example

    ```nix
    settingsFormat = systemdIni { };
    => {
      type = # Module type
      generate = # Generator function
    }
    ```
  */
  systemdIni = { }: {
    type =
      with lib.types;
      let
        atomUnit = oneOf [
          bool
          int
          path
          str
        ];

        atomUnit' = either atomUnit (listOf atomUnit);

        sectionUnit = (attrsOf atomUnit');
      in
        attrsOf (either sectionUnit (listOf sectionUnit));

    generate =
      name: value:
        pkgs.writeText name (self.generators.toSystemdINI value);
  };
}
