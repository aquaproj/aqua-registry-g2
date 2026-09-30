---
name: refresh-index
description: Bring index.json and names.json up to what the package branches say, for one package or all of them. Use when a package is missing from the catalogue or from search, when an alias a repository rename left behind isn't resolving, or after editing a definition's description, link, search words or aliases.
---

# Bring the catalogue up to the definitions

After editing a definition, run [index.yaml](../../.github/workflows/index.yaml) and name the
package:

```sh
gh workflow run index.yaml -f packages="<package name>..."
```

Naming none reconciles the whole catalogue, which is what the schedule does twice an hour: it
reads the definition on every package branch and adds whatever the catalogue is missing, so a
package whose pull request merged is listed without anybody doing anything. A branch holding
nothing but its claim to a package -- which is what a branch is created with -- is waiting for
the pull request that brings its definition, and there is nothing to describe the package with
until then.

The entry's id is the branch the definition was read from. Nothing is minted there: the branch
exists, so where the package is has an answer already.

### What the reconciliation doesn't notice

An entry that is out of date. It asks which packages are missing, and a package whose
description or aliases changed isn't missing -- which is why a definition edited by hand needs
the package named.

`ar2 validate-index` checks that a name isn't both a package and another package's alias, and
that no two packages claim one id. It runs on every pull request into `main`.
