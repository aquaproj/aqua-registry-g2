---
name: rename-package
description: Move a package in aqua-registry-g2 to the name it has now, keeping the old name as an alias. Use for a rename GitHub can't see, such as one repository that starts publishing several commands. A repository that was renamed or transferred needs nothing: a run notices and moves it.
---

# Move a package to the name it has now

Usually nothing. A repository that was renamed or transferred is noticed by the run itself:
the sweep asks GitHub for each package's versions and gets the name the repository answers
to, so the move costs no extra request, and the run makes it before generating anything. The
job summary reports it under Renamed.

A rename GitHub can't see is the other case -- one repository that starts publishing several
commands, say, where the package's name changes and the repository's doesn't. That is
[rename.yaml](../../.github/workflows/rename.yaml) and nothing else:

```sh
gh workflow run rename.yaml -f from=<old package name> -f to=<new package name>
```

### What a rename moves

Everything: the branch the generated versions live on, the path aqua fetches them from, the
entry the catalogue lists the package under. The old name stays as an alias, which is how a
configuration still asking for it resolves.

The branch is carried over rather than the versions generated again -- each of them was
downloaded, hashed and opened on six machines to get there -- with the old commit as the new
branch's parent, so nothing is copied. The old branch is left behind: deleting it is an
administrator's decision, and nothing reads it once the catalogue names the package under its
new name.
