# Maintainer Guide

For outside contributors, see [CONTRIBUTING.md](CONTRIBUTING.md).

Almost nothing here is written by hand. [ar2](https://github.com/aquaproj/ar2) generates
it and opens pull requests, and CI decides what merges. So the work is running the right
tool and reading what it produced, and this document is which tool and what to read. What
the repository holds and how it is laid out is in [README.md](README.md).

## Everything that writes runs in GitHub Actions

The `require_sign` ruleset covers every branch and no actor bypasses it. ar2 commits
through the Git Data API, and GitHub signs such a commit only when the caller is a GitHub
App installation or GitHub Actions. The App keys are in the `ar2` and `index`
environments, so a laptop can't produce a commit this repository accepts.

Every ar2 command that writes is therefore run by dispatching a workflow. What is worth
running locally is the part that only reads:

```sh
ar2 regenerate <package name> --dry-run   # which versions would change
ar2 test                                  # check generated files against the releases
ar2 validate-index                        # check index.json says what aqua reads it for
```

One more rule shapes the rest. A pull request and its checks are required on `main`, which
holds every package, and nothing bypasses that. `main` cannot be deleted or rewritten either.

One App, because one of the things a run does is something `GITHUB_TOKEN` can't.
`AR2_PR_*` commits to the head branches and opens the pull requests, because a pull request
opened with `GITHUB_TOKEN` gets its checks in an approval-required state and would never
auto-merge. It is a bypass actor for nothing, so the checks still decide what merges.

Until 2026-10 each package was kept on an orphan branch of its own, `pkg_<id>`, and a second
App, `AR2_BRANCH_*`, created them past the rulesets guarding them. The branches are still
there, frozen, and nothing writes to them
([#695](https://github.com/aquaproj/aqua-registry-g2/issues/695)).

## The checks on a pull request into main

[test.yaml](.github/workflows/test.yaml) calls [wc_main.yaml](.github/workflows/wc_main.yaml)
and one job decides the merge: `status-check-main` fails when the call didn't pass, so jobs
can be added to the reusable workflow without touching the ruleset.

What a pull request does to the packages is [wc_packages.yaml](.github/workflows/wc_packages.yaml),
called from there:

- [plan-packages.sh](.github/scripts/plan-packages.sh) works out which packages the pull
  request touches, and refuses what no pull request may do. A package's pull request from
  `ar2_<id>` touches that package's directory and nothing else, and one from any other
  `ar2_` branch touches no package. A `registry-*.json` already published is changed or
  removed only once a person has labelled the pull request `replaces-published` -- the
  label's event is read for who put it there, because ar2 labels its own pull requests. When
  every package had a branch of its own, a pull request couldn't reach another package; on
  `main` that is this check.
- Each package's definition is validated, and every `registry-*.json` added or changed is
  checked with `ar2 test` on a machine of each environment it describes.

Everything checks out only what it reads. `pkgs/` is most of the repository and none of
what the other checks look at.

[actionlint.yaml](.github/workflows/actionlint.yaml) is apart from it on purpose. What it
reads is the workflows themselves, so it has to answer when they are what is broken -- a
reusable workflow that won't parse takes every job calling it with it. It holds one job,
which is therefore the check the ruleset requires, and it installs no aqua: the action
carries actionlint.

## How To Add packages

[skills/add-package](skills/add-package/SKILL.md).

For a package aqua-registry doesn't have, which otherwise has no way into the order at all. A
request for one aqua-registry already has needs nothing: the order reaches it.

## How To Support a new version

[skills/generate-versions](skills/generate-versions/SKILL.md).

Or wait: a run dispatches the next one, so the registry generates what it is missing without
anybody asking.

## How To Fix registry.yaml

[skills/fix-definition](skills/fix-definition/SKILL.md).

A package's definition is the one file in this registry a person writes. Everything generated
from it follows, so two things usually follow an edit as well.

## How To Fix registry.json

[skills/regenerate-versions](skills/regenerate-versions/SKILL.md).

Never by hand: fix the definition, then generate the affected versions again. It replaces what
the registry already serves, so nothing about it is automatic.

The same skill finishes a pull request of versions waiting for a definition, which is the other
way round: those versions aren't in the registry at all, and what generates them is the
definition written on that pull request's own branch.

## How To Fix versions.json

A pull request changing a package's versions writes its list in the same commit, so normally
there is nothing to do. The list is derived from `versions/`, so there is nothing to fix by
hand either: what ar2 writes is what the directory holds.

The one pull request that leaves the list alone is the one of versions waiting for a
definition. The package's other pull requests write the list in the meantime, so writing it
there too would conflict with whichever of them merged first. Once it merges the list is
behind, and the package's next pull request writes it again: the list records the sha of the
`versions` tree it was made from, and a list whose `source` isn't that tree any more is made
again from every version rather than added to.

## How To Fix index.json

[skills/refresh-index](skills/refresh-index/SKILL.md).

The schedule reconciles the catalogue twice an hour, and what it reconciles is both the
packages the catalogue is missing and the entries that are out of date: every definition is
read and every entry compared against what its definition says now. Naming a package narrows
the work rather than what is noticed.

A definition merging asks for the reconciliation itself: [index.yaml](.github/workflows/index.yaml)
runs on a push to `main` that changes a `pkgs/*/*/registry.yaml`. So the catalogue follows a
definition by about a minute, and the schedule is what catches a merge that didn't ask.

## How To Fix names.json

Not directly. It is rendered from the entries in `index.json`, in the commit that writes them
-- [index.yaml](.github/workflows/index.yaml) writes both files together -- so a missing
alias is a missing `aliases` entry in the package's `registry.yaml`:

1. [skills/fix-definition](skills/fix-definition/SKILL.md), to add the alias.
2. [skills/refresh-index](skills/refresh-index/SKILL.md), to read the entry out of the
   definition again.

A transfer GitHub reports needs none of this: see
[skills/rename-package](skills/rename-package/SKILL.md).

## How To Rename a package

[skills/rename-package](skills/rename-package/SKILL.md).

Usually nothing: a run notices a repository that answers to another name and renames the
package itself. The other case is a rename GitHub can't see.

The package's directory doesn't move, because it is named after the package's id rather than
after the package. What moves is the definition in it, which is the only thing that says which
package the directory holds, and the entry the catalogue lists it under.

## How To Ignore a package

[skills/ignore-package](skills/ignore-package/SKILL.md).

A package the registry doesn't take on, with the reason it doesn't. Not the same as removing
one, which takes away what was published.

## How To Remove a package

[skills/remove-package](skills/remove-package/SKILL.md).

Not something this registry does, beyond malware and a package aqua can't install at all. When
it is decided it is three things at once, and one command does all of them.

## How To Review pull requests

[skills/review-pull-request](skills/review-pull-request/SKILL.md).

Most merge themselves. One waiting for a person is one ar2 couldn't answer for, or one a person
asked for, and its body says which.

## The state

The order runs work through: how many turns each package has had, its stars, and the
versions the registry was found to hold. It lives in this repository's container registry
(`ghcr.io`) rather than in a branch, so writing it isn't a commit and doesn't need review.

`ar2 init` builds it and pushes it there. A run writes it back, and adds whatever
aqua-registry has gained since, so `ar2 init` is not part of ordinary operation -- it is
for the first time, or for rebuilding one that was lost. A run that finds no state builds
it from scratch.

Reading it needs no workflow, since it writes nothing:

```sh
ar2 state --repository aquaproj/aqua-registry-g2
ar2 state --repository aquaproj/aqua-registry-g2 <package name>...
```

Without a name it says how far the registry has got, which every run also writes into its
job summary. With one it answers the question an issue asks -- why has this package not
been generated -- with the things that decide it: how many turns it has had, how far behind
the order that leaves it, whether it already holds every version the last sweep saw, and
whether its history has ever been walked. A name the order doesn't hold says so, which is
itself the answer.

## How To Update ar2

[skills/update-ar2](skills/update-ar2/SKILL.md).

Renovate raises the pin and autofix.ci records the checksums. A bump by hand does both in one
commit.

## How To Update the schema of registry.json

[skills/update-schema](skills/update-schema/SKILL.md).

What the schema version promises a reader is in [README.md](README.md#schema-version).
Nothing here has been done yet: there is one schema, and the skill is what to build the first
time.
