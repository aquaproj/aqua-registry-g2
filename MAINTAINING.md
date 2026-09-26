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

```sh
gh workflow run add_package.yaml -f name=<package name>
```

Not there yet. It goes in before the registry is used in production, along with the ar2
command behind it: the state is built from aqua-registry's package list and a run works
through that order, so a package aqua-registry doesn't have has no way in today.

What it will do is scaffold the definition and put the package into the state. Generating
it is then the ordinary path rather than part of adding it, because a package new to the
state joins the order at the current lap rather than behind everything, so the next run
reaches it.

A request for a package aqua-registry already has needs none of this. The order reaches
it.

## How To Support a new version

`ar2 run` generates the versions the registry is missing, most starred package first and
newest version first, and opens one pull request per package. Dispatch it:

```sh
gh workflow run ar2.yaml -f limit=<how many package versions>
```

There is no schedule yet. One goes on before the registry is used in production; until
then the backfill advances when somebody dispatches it, which is deliberate while ar2 is
still changing. `--limit` bounds the versions attempted, not the versions generated, so a
package that fails every time can't spend a whole run.

What to read afterwards: the job summary lists what was generated and what wasn't, and
the pull requests it opened either merge themselves or are waiting for a reason. See
[Reviewing pull requests](#reviewing-pull-requests).

## How To Fix registry.yaml

By hand, as a pull request into the package's branch.

The branch name is the package name escaped, which
[README.md](README.md#the-branch-name) gives the rule for: `cli/cli` is on
`pkg_cli_2fcli`.

```sh
git fetch origin pkg_cli_2fcli
git switch pkg_cli_2fcli
```

Fixing the definition doesn't change anything already generated from it. Two things
usually follow:

- [How To Fix registry.json](#how-to-fix-registryjson), for the versions generated under
  the old definition.
- [How To Fix index.json](#how-to-fix-indexjson), when the change touched what the
  catalogue holds: the description, the link, the search words, the aliases.

## How To Fix registry.json

Never by hand. Fix `registry.yaml` first, then generate the affected versions again.

```sh
ar2 regenerate <package name> [<version>...]   # naming none does every version held
ar2 regenerate <package name> --dry-run        # which versions would change
```

Only the versions whose file actually changes are committed, so pointing it at a whole
package to find out whether anything moved comes to nothing when nothing did. Auto-merge
is never turned on for what it opens: CI can say the new file describes the release it
says it does, not that replacing the old one was right.

It commits, so it is dispatched rather than run by hand:

```sh
gh workflow run regenerate.yaml -f name=<package name> -f versions=<versions>
```

That workflow isn't there yet; it goes in before the registry is used in production. Until
then `--dry-run` is what can be run locally, and it answers the question that matters
most: whether anything would change at all.

A version whose upstream release was changed after the fact is a different problem.
Regenerating it produces a different checksum for the same version, which is what a
release being rewritten looks like and what a lock file exists to catch. Decide whether
to publish the new file rather than regenerating by reflex.

## How To Fix index.json

`ar2 index` lists every package branch and adds whatever the catalogue is missing. It
runs on a schedule, twice an hour, so a package whose pull request merged arrives without
anybody doing anything.

What it does not notice is an entry that is out of date: it asks which packages are
missing, and a package whose description or aliases changed isn't missing. After editing
a definition, name the package:

```sh
ar2 index <package name>
```

`ar2 validate-index` checks that a name isn't both a package and another package's alias,
and runs on every pull request into `main`.

## How To Fix aliases.json

Not directly: it is rendered from the entries in `index.json`, in the commit that writes
them. A missing alias is a missing `aliases` entry in the package's `registry.yaml`, so
fix that and then run `ar2 index <package name>`.

- [.github/workflows/index.yaml](.github/workflows/index.yaml): writes `index.json` and
  `aliases.json` together, on a schedule.

A transfer GitHub reports needs none of this. See below.

## Renaming a package

A rename moves everything: the branch the generated versions live on, the path aqua
fetches them from, the entry the catalogue lists the package under. The old name stays as
an alias, which is how a configuration still asking for it resolves.

A repository that was renamed or transferred is noticed by the run itself. The sweep asks
GitHub for each package's versions and gets the name the repository has now, so the move
costs no extra request, and the run makes it before generating anything. The job summary
reports it under Renamed.

A rename GitHub can't see is the other case: one repository that starts publishing
several commands, say, where the package name changes but the repository doesn't. That is
this command, and nothing else:

```sh
ar2 rename <old package name> <new package name>
```

The branch is carried over rather than the versions generated again -- each of them was
downloaded, hashed and opened on six machines to get there -- with the old commit as the
new branch's parent, so nothing is copied. The old branch is left behind: deleting it is
an administrator's decision, and nothing reads it once the catalogue names the package
under its new name.

It commits and it creates a branch, so it needs both Apps, and therefore a workflow:

```sh
gh workflow run rename.yaml -f from=<old package name> -f to=<new package name>
```

Not there yet either. It goes in with the others, before the registry is used in
production.

## Ignoring a package

`ignored_packages` in [ar2.yaml](ar2.yaml), as a pull request into `main`. Each entry
carries the reason, because the next person to wonder why a package isn't here reads that
file and nothing else.

They are dropped before anything asks GitHub about them, so a package whose repository is
gone stops costing a request every run.

## Removing a package

No path yet. The branch can't be deleted except by an administrator, and there is no
command that takes an entry out of the catalogue on its own. When a package has to stop
being served, the entry is what matters: taking it out of `index.json` stops aqua finding
the package, and the branch can stay where it is.

## Reviewing pull requests

Most of them merge themselves, and the trust in that comes from CI rather than from
anyone's judgement: it downloads every asset the generated files describe, on a machine of
the environment each entry is for, checks the checksums, opens the archives and verifies
every signature the entries claim.

So a pull request waiting for a person is one ar2 decided it could not answer for, or one
a person asked for. Its body says which, and what to do about each is in
[docs/review-pr.md](docs/review-pr.md).

## The state

The order runs work through: how many turns each package has had, its stars, and the
versions the registry was found to hold. It lives in this repository's container registry
(`ghcr.io`) rather than in a branch, so writing it isn't a commit and doesn't need review.

`ar2 init` builds it and pushes it there. A run writes it back, and adds whatever
aqua-registry has gained since, so `ar2 init` is not part of ordinary operation -- it is
for the first time, or for rebuilding one that was lost. A run that finds no state builds
it from scratch.

There is no way to read it yet, which is what "why has this package not been generated"
needs answering with.

## The package branch template

`template/` is copied when a branch is created and never again. The CI a package branch
runs is therefore the CI its branch was created with, and changing the template does not
reach the branches that already exist. Until something reconciles them, a change to the
checks has to be treated as applying to new packages only.

## Updating ar2

Renovate raises the pinned version in `aqua/aqua.yaml`, and autofix.ci records the
checksum, which is what makes such a pull request mergeable. Releasing ar2 is a signed
tag on its repository; the release workflow does the rest.

## Updating the schema of registry.json

The schema version is the file name. `registry-1.json` is the first, and a change that
old aqua can't read is `registry-2.json` written beside it rather than an edit to what is
already published, so an aqua that knows only the first keeps working. How the two are
generated and for how long both are kept is still being decided.
