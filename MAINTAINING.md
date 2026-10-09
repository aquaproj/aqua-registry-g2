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

Two more rules shape the rest. A pull request is required on `main` and on every
`pkg_*` branch. A package branch cannot be deleted or rewritten, by anyone but an
administrator: that ruleset forbids both and has no bypass actor.

The two requirements are separate rulesets on purpose. `AR2_BRANCH_*` bypasses the one
asking for a pull request and its checks, so it can push onto a package branch; it does
not bypass the one forbidding deletion and a force push, so what it can do to a branch is
add to it. What that is for is a file the review has nothing to say about, which so far is
one thing: [filling in the dates](#how-to-fill-in-when-a-release-was-published) of the
versions generated before registry.json recorded them.

Two Apps, because two of the things a run does are things `GITHUB_TOKEN` can't.
`AR2_BRANCH_*` creates package branches, which has to get past the ruleset requiring
status checks that a brand new branch can't have; it holds no pull-requests permission,
so the bypass can't become a way to merge something unchecked. `AR2_PR_*` commits to the
head branches and opens the pull requests, because a pull request opened with
`GITHUB_TOKEN` gets its checks in an approval-required state and would never auto-merge.

## The checks on a pull request into main

[test.yaml](.github/workflows/test.yaml) calls [wc_main.yaml](.github/workflows/wc_main.yaml)
and one job decides the merge: `status-check-main` fails when the call didn't pass, so jobs
can be added to the reusable workflow without touching the ruleset.

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

## How To Fill in when a release was published

Dispatch [dates.yaml](.github/workflows/dates.yaml).

```sh
gh workflow run dates.yaml -f dry_run=true          # what it would write
gh workflow run dates.yaml
gh workflow run dates.yaml -f packages="cli/cli"
```

`registry.json` says when the release it was generated from was published, from ar2 v0.5.0
on. The files written before that don't, and nothing can work it out from them: the version
string doesn't say it, and a package whose tags aren't semver has nothing else to order its
releases by.

Nothing is generated again. The date is read off the release, the one field is added, and
the file is rendered the way a generation renders it, so the same version generated again
comes out the same bytes. That is why it is pushed onto the package branches rather than
opened as a pull request each: hundreds of pull requests, every one asserting what its own
diff proves.

It has an end. Once every package is filled in, a run reads the registry, finds nothing to
do and writes nothing, so there is no schedule for it. A package whose versions are its
tags is skipped, having no release list to read a date from.

## How To Fix versions.json

A version merging writes its branch's list by itself, so normally there is nothing to do.
The list is derived from `versions/`, so there is nothing to fix by hand either: what a run
writes is what the branch holds.

Dispatch [versions.yaml](.github/workflows/versions.yaml) to sweep every branch, which it
also asks to do twice an hour.

```sh
gh workflow run versions.yaml -f dry_run=true
gh workflow run versions.yaml -f packages="cli/cli"
```

A scheduled workflow runs when GitHub gets to it, and in this repository that has been a few
hours, so the sweep is what catches a list a merge didn't write rather than what keeps them
current. A list is left alone when it names the current `versions` tree, which is what makes
a sweep over the whole registry two requests a package.

### How a merge writes the list

A package branch can't write its own list: the app that may push onto one keeps its key in
the `ar2` environment, only main may deploy to that, and a push workflow runs on the branch
that was pushed. Three files carry the news across that line without carrying the key back.

| where | what |
| --- | --- |
| the package branch | [`versions.yaml`](template/.github/workflows/versions.yaml), on `versions/**`, calling main |
| main | [`wc_versions.yaml`](.github/workflows/wc_versions.yaml), which raises a `repository_dispatch` naming the branch |
| main | [`versions_update.yaml`](.github/workflows/versions_update.yaml), triggered by it, which writes the list |

What makes it work is that `repository_dispatch` is one of the two events GitHub raises even
when `GITHUB_TOKEN` sends them, and that a workflow it triggers is read from the default
branch. So the branch's own workflow needs no secret, and the one with the key never runs
anywhere but main.

The caller on the branch is copied from the template when the branch is created and never
updated afterwards, like the test one, so it holds nothing but the call. A branch that
predates a template file doesn't have it, and what puts it there is
[the template](#how-to-change-what-a-package-branch-holds).

## How To Change what a package branch holds

Dispatch [template.yaml](.github/workflows/template.yaml) after changing `template/`.

```sh
gh workflow run template.yaml -f dry_run=true
gh workflow run template.yaml -f dry_run=false
gh workflow run template.yaml -f branches="pkg_1790772767" -f dry_run=false
```

A package branch is created holding the files in `template/`, because a workflow for a
branch is read from that branch rather than from main. They are copied once and never
updated, so a file added to the template isn't on the branches made before it, and a call
that has to change doesn't change on them by itself.

It writes one way and deletes nothing: what the template names is written where a branch
holds something else, and what a branch holds and the template doesn't -- the definition,
the versions, the list of them -- is left alone. So a file taken out of the template stays
where it was copied, and taking it off the branches is not this.

## How To Fix index.json

[skills/refresh-index](skills/refresh-index/SKILL.md).

The schedule reconciles the catalogue twice an hour. What it can't notice is an entry that is
out of date, which is why a definition edited by hand needs its package named.

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

The branch doesn't move, because it is named after the package's id rather than after the
package. What moves is the definition on it, which is the only thing that says which package
the branch holds, and the entry the catalogue lists it under.

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
