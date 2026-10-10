---
name: fix-definition
description: Edit a package's definition, registry.yaml in its own directory, which is the one file in this registry a person writes. Use when a package resolves wrongly, when an asset filter or a file's name has to change, or when an alias has to be added.
---

# Fix a package's definition

By hand, as a pull request into `main`.

The package's directory is named after its id rather than after the package, so it has to be
looked up. `ar2 show` says which it is:

```sh
ar2 show cli/cli    # package, id, dir, description, aliases
$EDITOR pkgs/67/1790772767/registry.yaml
```

The definition names its own package, which is how the directory says which one it holds.
Leave that line alone unless the package is being [renamed](../rename-package/SKILL.md): a
directory naming another package is one nothing can find.

A pull request from a branch of your own may touch any package; the check that keeps a pull
request to its own package's directory is for the ones ar2 opens from `ar2_<id>`.

A definition also goes on the head branch of a pull request whose versions are
[waiting for one](../review-pull-request/SKILL.md#the-pull-request-is-versions-waiting-for-a-definition).
Those versions aren't in the registry, so the definition that describes them has nowhere else
to be, and putting it there is what lets them and it merge together.

Fixing the definition doesn't change anything already generated from it. Two things
usually follow:

- [generating them again](../regenerate-versions/SKILL.md), for the versions generated under
  the old definition.
- [bringing the catalogue up to it](../refresh-index/SKILL.md), when the change touched what the
  catalogue holds: the description, the link, the search words, the aliases.
