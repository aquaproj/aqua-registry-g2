---
name: refresh-index
description: Bring index.json and aliases.json up to what the package branches say, for one package or all of them. Use when a package is missing from the catalogue or from search, when an alias a repository rename left behind isn't resolving, or after editing a definition's description, link, search words or aliases.
---

# Bring the catalogue up to the definitions

After editing a definition, run [index.yaml](../../.github/workflows/index.yaml) and name the
package:

```sh
gh workflow run index.yaml -f packages="<package name>..."
```

Naming none reconciles the whole catalogue, which is what the schedule does twice an hour: it
lists every package branch and adds whatever the catalogue is missing, so a package whose
pull request merged is listed without anybody doing anything.

### What the reconciliation doesn't notice

An entry that is out of date. It asks which packages are missing, and a package whose
description or aliases changed isn't missing -- which is why a definition edited by hand needs
the package named.

`ar2 validate-index` checks that a name isn't both a package and another package's alias, and
runs on every pull request into `main`.
