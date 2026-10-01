# Using aqua-registry-g2 from other tools

aqua-registry-g2 is a registry for aqua.
See also [For non-aqua users](CONTRIBUTING.md#for-non-aqua-users).

But aqua-registry-g2 can be useful for other tools as well.
Some tools use aqua-registry and may migrate to aqua-registry-g2.

This document is for maintainers of such tools.
We write it in the hope that it helps, but we don't support other tools.
aqua-registry-g2 changes for what aqua needs, and what this document describes may change without regard to other tools.

Please see also [README.md](README.md), [CONTRIBUTING.md](CONTRIBUTING.md), and [MAINTAINING.md](MAINTAINING.md).

## How To Fetch registry.json

In aqua-registry, tools could fetch registry.yaml from the repository root or `pkgs/<package name>/registry.yaml` in the main branch of aqua-registry.

e.g. [pkgs/cli/cli/registry.yaml](https://github.com/aquaproj/aqua-registry/blob/main/pkgs/cli/cli/registry.yaml)

In aqua-registry-g2, [`registry.json` can be fetched from each package branch per package version](README.md#package-branches).

e.g. [grafana/k6 v2.3.0](https://github.com/aquaproj/aqua-registry-g2/blob/pkg_1790772860/versions/v2.3.0/registry-1.json)

This is the main difference from aqua-registry.
A registry.yaml covers every version of a package, so a tool has to evaluate it for the version it installs: `version_constraint`, `version_overrides`, and templates such as `{{.Version}}` in the asset name.
A registry.json covers one version and is already resolved: the asset name, the format, the files in the archive, and the checksum are written as they are, so a tool reads it without evaluating anything.

A tool fetches it from the raw URL:

```
https://raw.githubusercontent.com/aquaproj/aqua-registry-g2/pkg_<id>/versions/<escaped version>/registry-1.json
```

`<id>` is the id of the branch holding the package, which [names.json](#how-to-resolve-a-package-name) gives for a name. The package's name is not in the branch name: a name changes, and an id doesn't.

`<escaped version>` is the version escaped as [README.md](README.md#escaping-a-version) describes. Nearly every version is written as it is; one that holds a slash isn't, e.g. `kustomize/v5.8.1` is `kustomize_2fv5.8.1`.

e.g. https://raw.githubusercontent.com/aquaproj/aqua-registry-g2/pkg_1790772860/versions/v2.3.0/registry-1.json

`1` of `registry-1.json` is the major version of the registry schema. See [README.md](README.md#schema-version) for what a reader should do when a new one arrives.

## How To List available packages

Fetch [index.json](index.json).

## How To List available versions

Fetch `versions.json` from the package branch.

```sh
gh api 'repos/aquaproj/aqua-registry-g2/contents/versions.json?ref=pkg_1790772860' \
  --jq '.content' | base64 -d
```

```json
{
  "source": "3c910ec7e3f6eff4cfe2a4bd8528cc4b54e71715",
  "versions": [
    {
      "version": "v1.3.0",
      "published_at": "2026-09-15T14:24:34Z",
      "digest": "sha256:1b4f0e9851971998e732078544c96b36c3d01cedf7caa332359d6f1d83567014"
    }
  ]
}
```

- `version` is the release's tag, as upstream writes it rather than as the branch escapes it.
- `published_at` is when the release was published, RFC 3339 in UTC. It is what a cooldown
  asks about -- don't take a release until it has stood for some days -- and the only thing
  that orders the versions of a package whose tags aren't semver. It is empty where there is
  no release to ask, which is a package whose versions are tags.
- `digest` is the SHA-256 of the `registry-1.json` the registry serves for that version, so
  a reader that has the file can tell whether it is still the one the registry holds.
- `source` is the sha of the `versions` tree the list was made from. It is what says whether
  the list is still the branch's: compare it with that tree, which is one request.

The newest release comes first, and a version with no date comes after every version that
has one.

The list is derived, and `versions/` is what decides what the registry holds. A list that
hasn't caught up is possible -- it is written within the half hour -- and the tree is right
when they disagree.

### From the tree

Each directory in `versions/` of a package branch is a version, [escaped](README.md#escaping-a-version).

e.g. [grafana/k6](https://github.com/aquaproj/aqua-registry-g2/tree/pkg_1790772860/versions)

A tool can list them with GitHub's Git Trees API:

```sh
gh api 'repos/aquaproj/aqua-registry-g2/git/trees/pkg_1790772860:versions' \
  --jq '.tree[] | select(.type == "tree") | .path'
```

The Trees API rather than the Contents API: the Contents API stops at 1,000 entries in a directory and says so only by returning fewer, which would look like a package whose newest versions aren't there. The Trees API answers up to 100,000 and says when it truncated.

A version that isn't there hasn't been generated, usually because it hasn't been yet. Mutable versions such as `latest` are never generated.
See [CONTRIBUTING.md](CONTRIBUTING.md#how-to-support-a-new-version).

## How To Resolve a package name

Fetch [names.json](names.json). It holds two tables.

```json
{
  "ids": {
    "grafana/k6": "1790772860",
    "jqlang/jq": "1790772893"
  },
  "aliases": {
    "stedolan/jq": "jqlang/jq"
  }
}
```

- `ids`: the package's name to the id of the branch holding it. This is what a tool resolves a name with before fetching anything.
- `aliases`: a name a package used to have to the name it has now, e.g. `stedolan/jq`, the name before the repository moved, to `jqlang/jq`. `ids` answers for the name it has, so resolve through `aliases` first when a name isn't in `ids`.

One table for every name rather than a file per name, because a tool usually resolves many packages at once.

A cached copy can be used until a name isn't in it: a name it holds is a name it holds, whenever it was written, so a miss is what says the copy is older than the registry. Fetch it again then, which is also how a package added since is found.

index.json lists each package's name, id and aliases as well, but use names.json: it is the same information in the shape a name is looked up in, and it is an order of magnitude smaller.
