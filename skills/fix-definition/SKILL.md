---
name: fix-definition
description: Edit a package's definition, registry.yaml on its own branch, which is the one file in this registry a person writes. Use when a package resolves wrongly, when an asset filter or a file's name has to change, or when an alias has to be added.
---

# Fix a package's definition

By hand, as a pull request into the package's branch.

The branch name is the package name escaped, which
[README.md](../../README.md#the-branch-name) gives the rule for: `cli/cli` is on
`pkg_cli_2fcli`.

```sh
git fetch origin pkg_cli_2fcli
git switch pkg_cli_2fcli
```

Fixing the definition doesn't change anything already generated from it. Two things
usually follow:

- [generating them again](../regenerate-versions/SKILL.md), for the versions generated under
  the old definition.
- [bringing the catalogue up to it](../refresh-index/SKILL.md), when the change touched what the
  catalogue holds: the description, the link, the search words, the aliases.
