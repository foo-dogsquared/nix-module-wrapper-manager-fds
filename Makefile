.PHONY: docs-serve
docs-serve:
	hugo -s docs/website serve

.PHONY: docs-build
docs-build:
	antora generate site.yml

.PHONY: build
build:
	{ command -v nix >/dev/null && nix build -f docs/ website; } || { nix-build docs/ -A website; }

.PHONY: check
check:
	{ command -v nix > /dev/null && nix flake check; } || { nix-build tests -A configs -A lib; }

# Ideally, this should be done only in the remote CI environment with a certain
# update cadence/rhythm.
.PHONY: update
update:
	npins update

# Ideally this should be done before committing.
.PHONY: format
format:
	treefmt
