/*
  A fork of the NixOS systemd library from nixpkgs suited for wrapper-manager's
  needs. The major reason it is forked instead of using it directly is because
  a lot of the functions is centered around NixOS' need (unsurprisingly) and it
  would require a LOT of adjusting otherwise so why not just fork it directly.

  Unlike NixOS' version where it has a few design considerations such as
  dropping support for `Install` section for units because it can do
  it stateless-ly, wrapper-manager only cares about generating them unit files.
  Thus, we have dropped several module options such as
  `systemd.units.<name>.enable` and `systemd.units.<name>.overrideStrategy`.
  Furthermore, we have added support for generating drop-in unit files by
  "$UNITNAME/$OVERRIDE_NAME" where it should map to
  `$out/etc/systemd/$TYPEDIR/$UNITNAME.$UNITTYPE.d/$OVERRIDE_NAME.conf`.

  It is meant to be composed alongside other packages of other environments
  (e.g., `systemd.packages` from NixOS) after all and several environment
  implementation are already taking care of installing them properly such as
  NixOS and home-manager.
*/
{
  pkgs,
  lib,
  self,
}:


rec {
  /**
    Convert the given non-generic unit options into the generic units version.
    Basically, it converts `programs.systemd.system.services.hello` suitable for
    `programs.systemd.system.units.hello` where it will be included in the derivation.

    For third-party module authors, it is recommended to set
    `programs.systemd.{system,user}.units` with this function that is likely to use
    other unit type submodules.

    # Type

    ```
    intoUnit :: attr -> attr
    ```
  */
  intoUnit = def: {
    inherit (def)
      name
      filename
      settings
      wantedBy
      requiredBy
      upheldBy
      aliases
      ;
  };

  /**
    Given a Nix string, return a shell string value.

    # Arguments

    s
    : The Nix string value.

    # Type

    ```
    shellEscape :: String -> String
    ```

    # Examples

    ```nix
    shellEscape "\\$"
    => "\\\\$"
    ```
  */
  shellEscape = s: (lib.replaceStrings [ "\\" ] [ "\\\\" ] s);

  /**
    Given a Nix string, return a path-safe name typically used as part of a
    filename itself.

    # Arguments

    s
    : The string value.

    # Type

    ```
    mkPathSafeName :: String -> String
    ```

    # Examples

    ```nix
    mkPathSafeName "foo@sample.service"
    => "foo-sample.service"
    ```
  */
  mkPathSafeName = lib.replaceStrings [ "@" ":" "\\" "[" "]" ] [ "-" "-" "-" "" "" ];

  /**
    Module type for matching with the systemd unit filenames.
  */
  unitNameType = lib.types.strMatching "[a-zA-Z0-9@%:_.\\-]+[.](service|socket|device|mount|automount|swap|target|path|timer|scope|slice)";

  /**
    Given a string, split the unit name into the unit name and its drop-in, if
    there's one.

    # Arguments

    s
    : The string value.

    # Type

    ```
    splitUnitFilename :: str -> str
    ```

    # Example

    ```nix
    splitUnitFilename "hello-there.service"
    => [ "hello-there.service" ]

    splitUnitFilename "hello-there.service.d/10-overrides.conf"
    => [ "hello-there.service.d" "10-overrides.conf" ]
    ```
  */
  splitUnitFilename = s: self.utils.splitStringOnce "/" s;

  /**
    Naively get the unit name of the given string.

    # Arguments

    Same as
    [`wrapperManagerLib.systemd.splitUnitFilename`](#function-library-wrapperManagerLib.systemd.splitUnitFilename).

    # Type

    ```
    getUnitName :: str -> str
    ```

    # Examples

    ```nix
    getUnitName "hello.service.d/10-override.conf"
    => hello.service.d
    ```
  */
  getUnitName = s: lib.head (splitUnitFilename s);

  /**
    Given a name and an extension, create the unit filename. Typically used for
    properly setting the `filename` option from `programs.systemd.units` and the
    like.

    # Arguments

    unitType
    : The unit type associated (e.g., `service`, `slice`).

    s
    : String value.

    # Type

    ```
    mkUnitFileName :: str -> str -> str
    ```

    # Example

    ```nix
    mkUnitFileName "service" "hello-there"1
    => "hello-there.service"

    mkUnitFileName "service" "hello-there/10-override"
    => "hello-there.service.d/10-override.conf"
    ```
  */
  mkUnitFileName = suffix: s:
    let
      unitName' = splitUnitFilename s;
      unitName = lib.head unitName';
      overrideName = lib.last unitName';
    in
      if unitName == overrideName then
        "${unitName}.${suffix}"
      else
        "${unitName}.${suffix}.d/${overrideName}.conf";

  makeUnit =
    name: unit:
      pkgs.runCommand "unit-${mkPathSafeName name}"
        {
          preferLocalBuild = true;
          allowSubstitutes = false;
          # unit.text can be null. But variables that are null listed in
          # passAsFile are ignored by nix, resulting in no file being created,
          # making the mv operation fail.
          text = unit.text;
          passAsFile = [ "text" ];
        }
        ''
          name=${shellEscape name}
          mkdir -p "$out/$(dirname -- "$name")"
          mv "$textPath" "$out/$name"
        '';

  boolValues = [
    true
    false
    "yes"
    "no"
  ];

  digits = map toString (lib.range 0 9);

  isByteFormat =
    s:
    let
      l = lib.reverseList (lib.stringToCharacters s);
      suffix = lib.head l;
      nums = lib.tail l;
    in
    builtins.isInt s
    || (
      lib.elem suffix (
        [
          "K"
          "M"
          "G"
          "T"
        ]
        ++ digits
      )
      && lib.all (num: lib.elem num digits) nums
    );

  assertByteFormat =
    name: group: attr:
    lib.optional (
      attr ? ${name} && !isByteFormat attr.${name}
    ) "Systemd ${group} field `${name}' must be in byte format [0-9]+[KMGT].";

  toIntBaseDetected =
    value:
    assert (lib.match "[0-9]+|0x[0-9a-fA-F]+" value) != null;
    (builtins.fromTOML "v=${value}").v;

  hexChars = lib.stringToCharacters "0123456789abcdefABCDEF";

  isNumberOrRangeOf =
    check: v:
    if lib.isInt v then
      check v
    else
      let
        parts = lib.splitString "-" v;
        lower = lib.toIntBase10 (lib.head parts);
        upper = if lib.tail parts != [ ] then lib.toIntBase10 (lib.head (lib.tail parts)) else lower;
      in
      lib.length parts <= 2 && lower <= upper && check lower && check upper;
  isPort = i: i >= 0 && i <= 65535;
  isPortOrPortRange = isNumberOrRangeOf isPort;

  assertValueOneOf =
    name: values: group: attr:
    lib.optional (
      attr ? ${name} && !lib.elem attr.${name} values
    ) "Systemd ${group} field `${name}' cannot have value `${toString attr.${name}}'.";

  assertValuesSomeOfOr =
    name: values: default: group: attr:
    lib.optional (
      attr ? ${name}
      && !(lib.all (x: lib.elem x values) (lib.splitString " " attr.${name}) || attr.${name} == default)
    ) "Systemd ${group} field `${name}' cannot have value `${toString attr.${name}}'.";

  assertHasField =
    name: group: attr:
    lib.optional (!(attr ? ${name})) "Systemd ${group} field `${name}' must exist.";

  assertMinimum =
    name: min: group: attr:
    lib.optional (
      attr ? ${name} && attr.${name} < min
    ) "Systemd ${group} field `${name}' must be greater than or equal to ${toString min}";

  checkUnitConfig =
    group: checks: attrs:
    let
      # We're applied at the top-level type (attrsOf unitOption), so the actual
      # unit options might contain attributes from mkOverride and mkIf that we need to
      # convert into single values before checking them.
      defs = lib.mapAttrs (lib.const (
        v:
        if v._type or "" == "override" then
          v.content
        else if v._type or "" == "if" then
          v.content
        else
          v
      )) attrs;
      errors = lib.concatMap (c: c group defs) checks;
    in
    if errors == [ ] then true else lib.trace (lib.concatStringsSep "\n" errors) false;

  toOption =
    x:
    if x == true then
      "true"
    else if x == false then
      "false"
    else
      toString x;

  attrsToSection =
    as:
    lib.concatStrings (
      lib.concatLists (
        lib.mapAttrsToList (
          name: value:
          map (x: ''
            ${name}=${toOption x}
          '') (if lib.isList value then value else [ value ])
        ) as
      )
    );

  makeJobScript =
    {
      name,
      text,
      enableStrictShellChecks,
    }:
    let
      scriptName = lib.replaceStrings [ "\\" "@" ] [ "-" "_" ] (shellEscape name);
      out =
        (
          if !enableStrictShellChecks then
            pkgs.writeShellScriptBin scriptName ''
              set -e

              ${text}
            ''
          else
            pkgs.writeShellApplication {
              name = scriptName;
              inherit text;
            }
        ).overrideAttrs
          (_: {
            # The derivation name is different from the script file name
            # to keep the script file name short to avoid cluttering logs.
            name = "unit-script-${scriptName}";
          });
    in
    lib.getExe out;

  # Create a directory that contains systemd definition files from an attrset
  # that contains the file names as keys and the content as values. The values
  # in that attrset are determined by the supplied format.
  definitions =
    directoryName: format: definitionAttrs:
    let
      listOfDefinitions = lib.mapAttrsToList (name: format.generate "${name}.conf") definitionAttrs;
    in
    pkgs.runCommand directoryName { } ''
      mkdir -p $out
      ${(lib.concatStringsSep "\n" (map (pkg: "cp ${pkg} $out/${pkg.name}") listOfDefinitions))}
    '';

  # Escape a path according to the systemd rules. FIXME: slow
  # The rules are described in systemd.unit(5) as follows:
  # The escaping algorithm operates as follows: given a string, any "/" character is replaced by "-", and all other characters which are not ASCII alphanumerics, ":", "_" or "." are replaced by C-style "\x2d" escapes. In addition, "." is replaced with such a C-style escape when it would appear as the first character in the escaped string.
  # When the input qualifies as absolute file system path, this algorithm is extended slightly: the path to the root directory "/" is encoded as single dash "-". In addition, any leading, trailing or duplicate "/" characters are removed from the string before transformation. Example: /foo//bar/baz/ becomes "foo-bar-baz".
  escapeSystemdPath =
    s:
    let
      replacePrefix =
        p: r: s:
        (if (lib.hasPrefix p s) then r + (lib.removePrefix p s) else s);
      trim = s: lib.removeSuffix "/" (lib.removePrefix "/" s);
      normalizedPath = lib.strings.normalizePath s;
    in
    lib.replaceStrings [ "/" ] [ "-" ] (
      replacePrefix "." (lib.strings.escapeC [ "." ] ".") (
        lib.strings.escapeC (lib.stringToCharacters " !\"#$%&'()*+,;<=>=@[\\]^`{|}~-") (
          if normalizedPath == "/" then normalizedPath else trim normalizedPath
        )
      )
    );

  # Quotes an argument for use in Exec* service lines.
  # systemd accepts "-quoted strings with escape sequences, toJSON produces
  # a subset of these.
  # Additionally we escape % to disallow expansion of % specifiers. Any lone ;
  # in the input will be turned it ";" and thus lose its special meaning.
  # Every $ is escaped to $$, this makes it unnecessary to disable environment
  # substitution for the directive.
  escapeSystemdExecArg =
    arg:
    let
      s =
        if lib.isPath arg then
          "${arg}"
        else if lib.isString arg then
          arg
        else if lib.isInt arg || lib.isFloat arg || lib.isDerivation arg then
          toString arg
        else
          throw "escapeSystemdExecArg only allows strings, paths, numbers and derivations";
    in
    lib.replaceStrings [ "%" "$" ] [ "%%" "$$" ] (lib.strings.toJSON s);

  # Quotes a list of arguments into a single string for use in a Exec*
  # line.
  escapeSystemdExecArgs = lib.concatMapStringsSep " " escapeSystemdExecArg;

  options = import ./options.nix { inherit pkgs lib self; };
  submodules = import ./submodules.nix { inherit pkgs lib self; };
}
