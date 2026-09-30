---
name: rename-package
description: Rename a package in aqua-registry-g2 to the name it has now, keeping the old name as an alias. Use for a rename GitHub can't see, such as one repository that starts publishing several commands. A repository that was renamed or transferred needs nothing, since a run notices and renames it.
---

# Rename a package to the name it has now

Usually nothing. A repository that was renamed or transferred is noticed by the run itself:
the sweep asks GitHub for each package's versions and gets the name the repository answers
to, so the rename costs no extra request, and the run makes it before generating anything. The
job summary reports it under Renamed.

A rename GitHub can't see is the other case -- one repository that starts publishing several
commands, say, where the package's name changes and the repository's doesn't. That is
[rename.yaml](../../.github/workflows/rename.yaml) and nothing else:

```sh
gh workflow run rename.yaml -f from=<old package name> -f to=<new package name>
```

### What a rename moves

Not the branch, which is named after the package's id. That is what an id is for: nothing that
wrote it down is left pointing at nothing, and the versions -- each downloaded, hashed and
opened on six machines to get there -- stay where they are.

Two things move. The definition on the branch, because it is the only thing that says which
package the branch holds, and a branch naming the old one would be found under a name nobody
uses. And the entry the catalogue lists the package under, which is what a name is resolved
through. The old name stays as an alias, so a configuration still asking for it resolves.

The definition goes through a pull request, since committing onto a package branch takes one.
The catalogue is brought to the new name straight away, ahead of it: both names are the same
branch, so a reader resolves either of them to it. What the pull request settles is which name
the registry answers for when a run next asks -- until it merges, a run asking for the new name
finds no branch and would take the package over as a new one.
