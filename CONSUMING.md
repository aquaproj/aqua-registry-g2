# Using aqua-registry-g2 from other tools

aqua-registry-g2 is a registry for aqua.
See also [For non-aqua users](CONTRIBUTING.md#for-non-aqua-users).

But aqua-registry-g2 can be useful for other tools as well.
Some tools use aqua-registry and may migrate to aqua-registry-g2.

This document is for maintainers of such tools.
We don't guarantee anything, but we hope this will be helpful.

Please see also [README.md](README.md), [CONTRIBUTING.md](CONTRIBUTING.md), and [MAINTAINING.md](MAINTAINING.md).

## How To Fetch registry.json

In aqua-registry, tools could fetch registry.yaml from the repository root or `pkgs/<package name>/registry.yaml` in the main branch of aqua-registry.

e.g. [pkgs/cli/cli/registry.yaml](https://github.com/aquaproj/aqua-registry/blob/main/pkgs/cli/cli/registry.yaml)

In aqua-registry-g2, [`registry.json` can be fetched from each package branch per package version](README.md#package-branches).

e.g. [grafana/k6 v2.3.0](https://github.com/aquaproj/aqua-registry-g2/blob/pkg_grafana_2fk6/versions/v2.3.0/registry-1.json)

This is the main difference from aqua-registry.
A registry.yaml covers every version of a package, so a tool has to evaluate it for the version it installs: `version_constraint`, `version_overrides`, and templates such as `{{.Version}}` in the asset name.
A registry.json covers one version and is already resolved: the asset name, the format, the files in the archive, and the checksum are written as they are, so a tool reads it without evaluating anything.

A tool fetches it from the raw URL:

```
https://raw.githubusercontent.com/aquaproj/aqua-registry-g2/<branch>/versions/<version>/registry-1.json
```

`<branch>` is the package name encoded as [README.md](README.md#the-branch-name) describes, e.g. `grafana/k6` is on `pkg_grafana_2fk6`.

e.g. https://raw.githubusercontent.com/aquaproj/aqua-registry-g2/pkg_grafana_2fk6/versions/v2.3.0/registry-1.json

`1` of `registry-1.json` is the major version of the registry schema. See [README.md](README.md#schema-version) for what a reader should do when a new one arrives.

## How To List available packages

Fetch [index.json](index.json).

## How To List available versions

Each directory in `versions/` of a package branch is a version.

e.g. [grafana/k6](https://github.com/aquaproj/aqua-registry-g2/tree/pkg_grafana_2fk6/versions)

A tool can list them with GitHub's Git Trees API:

```sh
gh api 'repos/aquaproj/aqua-registry-g2/git/trees/pkg_grafana_2fk6:versions' \
  --jq '.tree[] | select(.type == "tree") | .path'
```

A version that isn't there hasn't been generated, usually because it hasn't been yet. Mutable versions such as `latest` are never generated.
See [CONTRIBUTING.md](CONTRIBUTING.md#how-to-support-a-new-version).

## How To Resolve package aliases

Fetch [aliases.json](aliases.json).
It maps an alias to the package's name, e.g. `stedolan/jq`, the name before the repository moved, to `jqlang/jq`.
The package branch is named after the package's name, so resolve the name before [encoding it](README.md#the-branch-name).

index.json also lists each package's aliases, but use aliases.json: the aliases in index.json may change or go away.
