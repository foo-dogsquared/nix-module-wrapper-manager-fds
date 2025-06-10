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

  /**
    Nix-representable format for GLib keyfile INI format as described from [its
    documentation](https://docs.gtk.org/glib/struct.KeyFile.html) for the most
    part. The difference is this does not allow multiple sections with the same
    name as instead follows from possible input from `lib.generators.toDconfINI` in
    nixpkgs.

    # Arguments

    An empty attribute set. This is set for forward-compatability for
    future settings that some Nix formats already does (such as
    `pkgs.formats.ini` and `pkgs.formats.elixir`).

    It has no settings for now.

    # Example

    ```nix
    settingsFormat = glibKeyfileIni { };
    => {
      type = # Module type
      generate = # Generator function
    }
    ```
  */
  glibKeyfileIni = { }: {
    type = with lib.types;
      let
        atomUnit = oneOf [
          bool
          float
          int
          str
          (listOf atomUnit)
        ] // {
          description =
            "GLib keyfile atom (bool, int, float, string, or a list of the previous atoms)";
        };
      in attrsOf (attrsOf atomUnit);

    generate =
      name: value:
        pkgs.writeText name (lib.generators.toDconfINI value);
  };
}
