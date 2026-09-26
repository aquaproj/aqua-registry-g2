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
gh workflow run add_package.yaml -f name=<package name> -f commands="<command>..."
gh workflow run add_package.yaml -f name=<package name> -f repo=<owner>/<name> -f dry_run=true
```

A request for a package aqua-registry already has needs none of this: the state is built
from its list, so the order reaches the package on its own. This is for a package
aqua-registry doesn't have, which otherwise has no way in at all.

It writes two things. The definition, as a pull request into the package's branch, and the
package's place in the order. Nothing is generated: the package joins at the current lap,
so the next run of the ar2 workflow reaches it and opens the pull requests for its
versions.

What to check on the definition is the repository and the commands. Everything else about
a package is read from its releases, so the definition says only what a release can't:
which of its files are the commands. `commands` defaults to the last part of the package
name, which is also what the inference guesses, so it is worth giving when the package
installs something else or more than one thing. `repo` is for a package whose name isn't
its repository, such as `kubernetes/kubernetes/kubectl`.

Either half may be there already, so this is dispatched again after a failure rather than
unpicked. A branch that has a definition keeps it, and a package that is in the order
keeps its turns.

## How To Support a new version

`ar2 run` generates the versions the registry is missing, most starred package first and
newest version first, and opens one pull request per package. Dispatch it:

```sh
gh workflow run ar2.yaml -f limit=<how many package versions>          # one run
gh workflow run ar2.yaml -f limit=<how many package versions> -f chain=forever
```

There is no schedule. A run dispatches the next one instead, which is what `chain` asks
for: `forever` keeps going, a number counts down, and `0` is a single run. The cadence is
then however long a run takes rather than whenever GitHub gets to a cron -- a workflow
asking for every ten minutes is triggered every few hours -- and the registry spends no
time idle.

To stop a chain, cancel the run that is going. Nothing is dispatched after a cancellation,
and a run that hit its timeout counts as one, so a run that got stuck ends the chain
rather than handing the same state to another run to get stuck on. A failure does not end
it, because a rate limit or a repository that didn't answer would otherwise stop the
registry until somebody noticed; five failures in a row do, with a comment on the
monitoring issue.

`limit` bounds the versions attempted, not the versions generated, so a package that fails
every time can't spend a whole run.

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
gh workflow run regenerate.yaml -f name=<package name> -f versions="<version>..."
gh workflow run regenerate.yaml -f name=<package name> -f dry_run=true
```

Naming no version does every version the registry holds, which for a package with a long
history is a large pull request. `dry_run` says which versions would change and commits
nothing, and is the same question `ar2 regenerate --dry-run` answers locally.

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

## Ignoring a package

A package the registry doesn't take on. Nothing was ever published for it, and the reason
is why: an asset whose name carries something only the installing machine knows, downloads
refused from the addresses CI runs on, a command deleted upstream.

`ignored_packages` in [ar2.yaml](ar2.yaml), as a pull request into `main`. Each entry
carries its reason, because the next person to wonder why a package isn't here reads that
file and nothing else. They are dropped before anything asks GitHub about them, so a
package whose repository is gone stops costing a request every run.

This is not a package being removed, and the two aren't degrees of the same thing. See
below.

## Removing a package

Not something this registry does. What it publishes for a version is meant to stay what it
was, and somebody's configuration may name the package. Two things override that: a
package aqua can't install whatever is generated for it, and malware, which goes without
asking.

When it is decided, it is three things at once, and the command does all of them.

```sh
gh workflow run remove_package.yaml -f name=<package name> -f reason="<why>"
```

1. The package stops being generated: it goes into `ignored_packages`, with the reason.
2. It stops being listed: its entry goes from `index.json`, and its aliases from
   `aliases.json` with it.
3. It stops being held: the files under `versions/` go off its branch.

Any one alone leaves a state nobody meant. An entry for a package that can't be fetched,
or files nothing lists that the next run adds to.

It opens two pull requests, because 1 and 2 are on `main` and 3 is on the package's
branch. Merge the one into `main` first: a package still in the order has its files
generated again by the next run, whatever the other one did. The second pull request says
so and points at the first.

The branch itself stays. A ruleset forbids deleting a package branch and no app bypasses
it, so what was published stays readable in its history.

### What removing cannot reach

A lock file that already holds the package. It carries the URL and the checksum of every
file it needs, which is the point of it, and nothing here takes that away. What step 3
stops is `aqua lock update` resolving those versions, so nobody new installs the package.

Steps 1 and 2 don't stop an install either, which is worth being clear about: nothing
resolves a package through `index.json`. A name in `aqua.yaml` is turned into
`pkg_<encoded>/versions/<version>/registry-1.json` and fetched directly, so a package with
no entry is one nothing can search for and anything already naming it still installs. Only
step 3 changes that.

Where the difference matters -- malware -- saying so where people will read it reaches
them and a registry change doesn't. That is the part to do first.

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
