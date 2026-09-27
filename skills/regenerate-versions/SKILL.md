---
name: regenerate-versions
description: Generate again the versions aqua-registry-g2 already holds, after fixing a definition that was wrong. Use when a package's generated registry.json is wrong for versions already published. It replaces what the registry serves, so it is never the first step and never automatic.
---

# Generate again what the registry already holds

Never by hand. Fix `registry.yaml` first, then run
[regenerate.yaml](../../.github/workflows/regenerate.yaml) to generate the affected versions
again:

```sh
gh workflow run regenerate.yaml -f name=<package name> -f versions="<version>..."
gh workflow run regenerate.yaml -f name=<package name> -f dry_run=true
```

Naming no version does every version the registry holds, which for a package with a long
history is a large pull request. `dry_run` says which versions would change and commits
nothing. The pull request it opens is never set to auto-merge, so it is read.

### What it does with them

Only the versions whose file actually changes are committed, so pointing it at a whole
package to find out whether anything moved comes to nothing when nothing did.

A version whose upstream release was changed after the fact is a different problem.
Regenerating it produces a different checksum for the same version, which is what a release
being rewritten looks like and what a lock file exists to catch. Decide whether to publish
the new file rather than regenerating by reflex.

`ar2 regenerate --dry-run` answers the same question locally, since it writes nothing. The run
that commits has to be the workflow, because ar2 commits through GitHub's API and what it
produces from here isn't signed --
[MAINTAINING.md](../../MAINTAINING.md#everything-that-writes-runs-in-github-actions) says the
rest of it.
