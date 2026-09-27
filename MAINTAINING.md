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
ar2 validate-index                        # check index.json and aliases.json agree
```

Two more rules shape the rest. A pull request is required on `main` and on every
`pkg_*` branch. A package branch cannot be deleted, by anyone but an administrator:
the ruleset forbids it and has no bypass actor.

Two Apps, because two of the things a run does are things `GITHUB_TOKEN` can't.
`AR2_BRANCH_*` creates package branches, which has to get past the ruleset requiring
status checks that a brand new branch can't have; it holds no pull-requests permission,
so the bypass can't become a way to merge something unchecked. `AR2_PR_*` commits to the
head branches and opens the pull requests, because a pull request opened with
`GITHUB_TOKEN` gets its checks in an approval-required state and would never auto-merge.

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

## How To Fix index.json

[skills/refresh-index](skills/refresh-index/SKILL.md).

The schedule reconciles the catalogue twice an hour. What it can't notice is an entry that is
out of date, which is why a definition edited by hand needs its package named.

## How To Fix aliases.json

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

Usually nothing: a run notices a repository that answers to another name and moves the package
itself. The other case is a rename GitHub can't see.

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

## The package branch template

`template/` is copied when a branch is created and never again. Whatever it holds is
therefore frozen on every branch that exists, and changing it later is a commit to each of
them, one pull request each. There are dozens of branches now and there will be thousands,
so the rule is to copy as little as can be copied and to read the rest from `main`.

The CI is where that is possible, and it is worth seeing why. A `pull_request` workflow is
read from the branch the pull request targets, so it cannot live on `main` -- but it can be
a caller that does nothing except invoke a reusable workflow there, which is what the
template's one file is: it calls `wc_test.yaml@main` and holds no checks of its own. The
checks are therefore on `main`, where changing them reaches every package at once, and what
is frozen is only the caller -- its trigger, the ref it calls, the permissions it passes,
and the `status-check` job the ruleset requires. Nothing has needed to change there.

Anything else that wants to be in the template deserves the same question first: what about
this will have to change, and can that part be read from `main` instead of copied? A file
that genuinely has to be copied is a file to be sure about before thousands of branches
carry it.

Whether the branches are still in step can be read without cloning them, since the file is
identical everywhere when it is:

```sh
git hash-object template/.github/workflows/test.yaml
gh api "repos/aquaproj/aqua-registry-g2/contents/.github/workflows/test.yaml?ref=<branch>" --jq .sha
```

## How To Update ar2

[skills/update-ar2](skills/update-ar2/SKILL.md).

Renovate raises the pin and autofix.ci records the checksums. A bump by hand does both in one
commit.

## How To Update the schema of registry.json

[skills/update-schema](skills/update-schema/SKILL.md).

What the schema version promises a reader is in [README.md](README.md#schema-version).
Nothing here has been done yet: there is one schema, and the skill is what to build the first
time.
