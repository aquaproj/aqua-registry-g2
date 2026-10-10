---
name: refresh-index
description: Bring index.json and names.json up to what the definitions say, for one package or all of them. Use when a package is missing from the catalogue or from search, when an alias a repository rename left behind isn't resolving, or after editing a definition's description, link, search words or aliases.
---

# Bring the catalogue up to the definitions

After editing a definition, run [index.yaml](../../.github/workflows/index.yaml) and name the
package:

```sh
gh workflow run index.yaml -f packages="<package name>..."
```

Naming none reconciles the whole catalogue, which is what the schedule does twice an hour: it
reads every package's definition and adds whatever the catalogue is missing, so a package
whose pull request merged is listed without anybody doing anything; a definition merging also
asks for it straight away. A definition holding nothing but a claim to a package is waiting
for the pull request that brings the rest of it, and there is nothing to describe the package
with until then.

The entry's id is the directory the definition was read from. Nothing is minted there: the
package has one, so where it is has an answer already.

### What the reconciliation notices

Both a package the catalogue is missing and an entry that is out of date: every definition is
read and every entry is compared against the one its definition makes now. Naming a package
narrows the work, not what is noticed.

What it doesn't do is remove. An entry with no definition behind it is either a package waiting
for the pull request that brings its definition, or an orphan -- somebody's decision rather than
a reconciliation's.

A definition merging asks for the reconciliation itself, so the catalogue follows it by about a
minute; the schedule is what catches a merge that didn't ask.

`ar2 validate-index` checks that a name isn't both a package and another package's alias, and
that no two packages claim one id. It runs on every pull request into `main`.
