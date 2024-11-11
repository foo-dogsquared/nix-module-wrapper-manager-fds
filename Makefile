BASEURL := "https://foo-dogsquared.github.io/nix-module-wrapper-manager-fds"

.PHONY: docs-serve
docs-serve:
	hugo -s docs/website serve

.PHONY: docs-build
docs-build:
	hugo -s docs/website

.PHONY: build
build:
	{ command -v nix >/dev/null && nix build -f docs/ --argstr baseUrl $(BASEURL) website; } || { nix-build docs/ -A website --argstr baseUrl $(BASEURL); }

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
