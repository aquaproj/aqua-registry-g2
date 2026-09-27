---
name: add-package
description: Add a package to aqua-registry-g2 that aqua-registry (v1) doesn't have, which is what an issue asking for a new package needs. Use when asked to add, register or support a package the registry doesn't hold yet, and to check what a request for one needs. Not for generating a version of a package the registry already has.
---

# Add a package to the registry

A package aqua-registry doesn't have has no way into this registry on its own: the order a
run works through is built from aqua-registry's list. This is the way in.

A request for a package aqua-registry already has needs none of this. The order reaches it,
and the answer to the issue is that it hasn't had its turn yet -- which `ar2 state <package>`
says in as many words.

## What to run

```sh
gh workflow run add_package.yaml -f name=<package name> -f commands="<command>..."
```

`commands` is worth giving when the package installs something other than the last part of
its name, or more than one thing. `repo` is for a package whose name isn't its repository,
such as `kubernetes/kubernetes/kubectl`. `dry_run` renders the definition and writes nothing,
which is the way to look before dispatching for real:

```sh
gh workflow run add_package.yaml -f name=<package name> -f repo=<owner>/<name> -f dry_run=true
```

It is a workflow rather than `ar2 add` run here, because it commits: the signing ruleset
covers every branch and GitHub signs a commit made through its API only for an App
installation or Actions.

## What it writes

Two things, and neither follows from the other: the definition, as a pull request into the
package's branch, and the package's place in the order. Nothing is generated here -- the
package joins at the current lap, so the next run of the ar2 workflow reaches it and opens
the pull requests for its versions.

Either half may be there already, so it is dispatched again after a failure rather than
unpicked. A branch that has a definition keeps it, and a package that is in the order keeps
its turns.

## What to read on the pull request

The repository and the commands, and nothing else. Everything about a package that a release
can be read for -- what the assets are called, which environment each is for, the format,
what is inside the archive -- is read from the release when a version is generated, so the
definition says only what a release can't say.

The pull request carries no generated file, so CI has nothing to check on it and it is never
set to auto-merge.
