let
  sources = import ../npins;
in
{
  pkgs ? import sources.nixos-unstable { },
  extraModules ? [ ],
}:

let
  inherit (pkgs) nixosOptionsDoc lib;

  src = builtins.toString ../.;

  # Pretty much inspired from home-manager's documentation build process.
  evalDoc =
    args@{
      modules,
      includeModuleSystemOptions ? false,
      ...
    }:
    let
      options =
        (pkgs.lib.evalModules {
          modules = modules ++ [
            {
              _module.check = false;
              _module.args.pkgs = pkgs;
            }
          ];
          class = "wrapperManager";
        }).options;

      # Based from nixpkgs' and home-manager's code.
      gitHubDeclaration = user: repo: subpath: {
        url = "https://github.com/${user}/${repo}/blob/master/${subpath}";
        name = "<${repo}/${subpath}>";
      };

    in
    nixosOptionsDoc (
      {
        options =
          if includeModuleSystemOptions then options else builtins.removeAttrs options [ "_module" ];
        transformOptions =
          opt:
          opt
          // {
            declarations = map (
              decl:
              if lib.hasPrefix src (toString decl) then
                gitHubDeclaration "foo-dogsquared" "nix-module-wrapper-manager-fds" (
                  lib.removePrefix "/" (lib.removePrefix src (toString decl))
                )
              else if decl == "lib/modules.nix" then
                gitHubDeclaration "NixOS" "nixpkgs" decl
              else
                decl
            ) opt.declarations;
          };
      }
      // builtins.removeAttrs args [
        "modules"
        "includeModuleSystemOptions"
      ]
    );
  releaseConfig = lib.importJSON ../release.json;

  wrapperManagerLib = (import ../. { }).lib;
  wmOptionsDoc = evalDoc {
    modules = [ ../modules/wrapper-manager ] ++ extraModules;
    includeModuleSystemOptions = true;
  };
  wmNixosDoc = evalDoc { modules = [ ../modules/env/nixos ]; };
  wmHmDoc = evalDoc { modules = [ ../modules/env/home-manager ]; };
  wmLibNixdocs =
    pkgs.runCommand "wrapper-manager-lib-nixdoc"
      {
        buildInputs = with pkgs; [ nixdoc ];
      }
      ''
        mkdir -p $out
        for nixfile in ${../lib}/*.nix; do
          name=$(basename --suffix=".nix" "$nixfile")
          [ "$name" = "default" ] && continue

          filename="''${out}/''${name}.md"
          title="wrapperManagerLib.''${name}"

          cat > "$filename" << EOF
        ---
        title: "$title"
        ---
        EOF

          nixdoc --file "$nixfile" --description "$title" --category "$name" --prefix "wrapperManagerLib" >> "$filename"
        done
      '';

  gems = pkgs.bundlerEnv {
    name = "wrapper-manager-fds-gem-env";
    ruby = pkgs.ruby_3_1;
    gemdir = ./.;
  };
in
{
  website =
    let
      buildHugoSite = pkgs.callPackage ./hugo-build-module.nix { };

      # Now this is some dogfooding.
      asciidoctorWrapped = wrapperManagerLib.build {
        inherit pkgs;
        modules = [
          (
            { lib, ... }:
            {
              wrappers.asciidoctor = {
                arg0 = lib.getExe' gems "asciidoctor";
                appendArgs = [
                  "-T"
                  "${sources.website}/templates"
                ];
              };
            }
          )
        ];
      };
    in
    {
      baseUrl ? "https://foo-dogsquared.github.io/nix-module-wrapper-manager-fds",
    }:

    buildHugoSite {
      pname = "wrapper-manager-docs";
      version = "2024-11-21";

      src = lib.fileset.toSource {
        root = ./website;
        fileset = lib.fileset.unions [
          ./website/assets
          ./website/config
          ./website/content
          ./website/layouts
          ./website/go.mod
          ./website/go.sum
        ];
      };

      vendorHash = "sha256-UDDCYQB/kdYT63vRlRzL6lOePl9F7j3eUIHX/m6rwEs=";

      buildFlags = [
        "--baseURL"
        baseUrl
      ];

      nativeBuildInputs = [
        asciidoctorWrapped
        gems
        gems.wrappedRuby
      ];

      preBuild = ''
        install -Dm0644 ${wmOptionsDoc.optionsAsciiDoc} ./content/en/wrapper-manager-env-options.adoc
        install -Dm0644 ${wmNixosDoc.optionsAsciiDoc} ./content/en/wrapper-manager-nixos-module.adoc
        install -Dm0644 ${wmHmDoc.optionsAsciiDoc} ./content/en/wrapper-manager-home-manager-module.adoc

        wmLibDir="./content/en/wrapper-manager-lib"
        mkdir -p "$wmLibDir" && install -Dm0644 ${wmLibNixdocs}/*.md -t "$wmLibDir"

        cat > "$wmLibDir/_index.md" <<EOF
        ---
        title: "wrapper-manager library"
        ---

        # wrapper-manager library set

        EOF

        for i in ${wmLibNixdocs}/*.md; do
          filename="$(basename "$i")"
          echo "- [''${filename}](./''${i})" >> "$wmLibDir/_index.md"
        done
      '';

      meta = with lib; {
        description = "wrapper-manager-fds documentation";
        homepage = "https://github.com/foo-dogsquared/wrapper-manager-fds";
        license = with licenses; [
          mit
          fdl13Only
        ];
        platforms = platforms.all;
      };
    };

  inherit wmOptionsDoc wmHmDoc wmNixosDoc wmLibNixdocs;

  inherit releaseConfig;
  outputs = {
    manpage =
      pkgs.runCommand "wrapper-manager-reference-manpage"
        {
          nativeBuildInputs = with pkgs; [
            nixos-render-docs
            gems
            gems.wrappedRuby
          ];
        }
        ''
          mkdir -p $out/share/man/man5
          asciidoctor --attribute is-wider-scoped --backend manpage \
            ${./manpages/header.adoc} --out-file header.5
          nixos-render-docs options manpage --revision ${releaseConfig.version} \
            --header ./header.5 --footer ${./manpages/footer.5} \
            ${wmOptionsDoc.optionsJSON}/share/doc/nixos/options.json \
            $out/share/man/man5/wrapper-manager.nix.5
        '';

    html =
      pkgs.runCommand "wrapper-manager-reference-html"
        {
          nativeBuildInputs = [
            gems
            gems.wrappedRuby
          ];
        }
        ''
          mkdir -p $out/share/wrapper-manager
          asciidoctor --backend html ${wmOptionsDoc.optionsAsciiDoc} --attribute toc --out-file $out/share/wrapper-manager/options-reference.html
        '';
  };
}
