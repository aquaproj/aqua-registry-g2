---
name: remove-package
description: Stop aqua-registry-g2 serving a package it has published, which is for malware and for a package aqua can't install whatever is generated for it. Use only for those, confirm before dispatching, and never as a way to fix a package that is merely wrong.
---

# Stop the registry serving a package

Not something this registry does. What it publishes for a version is meant to stay what it
was, and somebody's configuration may name the package. Two things override that: a
package aqua can't install whatever is generated for it, and malware, which goes without
asking.

When it is decided, it is three things at once, and the command does all of them.

```sh
gh workflow run remove_package.yaml -f name=<package name> -f reason="<why>"
```

1. The package stops being generated: it goes into `ignored_packages`, with the reason.
2. It stops being listed: its entry goes from `index.json`, and its names from
   `names.json` with it.
3. It stops being held: the files under its `versions/` go, and its `versions.json` with them.

Any one alone leaves a state nobody meant. An entry for a package that can't be fetched,
or files nothing lists that the next run adds to.

It opens two pull requests into `main`, one for 1 and 2 and one for 3. Merge the first one
first: a package still in the order has its files generated again by the next run, whatever
the other one did. The second pull request says so and points at the first.

The second takes away published files, which the checks refuse unless a person labels the
pull request `replaces-published`. That is the decision being made, so it is a person's.

The definition stays, and what was published stays readable in the history of `main`, which a
ruleset forbids rewriting.

### What removing cannot reach

A lock file that already holds the package. It carries the URL and the checksum of every
file it needs, which is the point of it, and nothing here takes that away. What step 3
stops is `aqua lock update` resolving those versions, so nobody new installs the package.

Step 1 doesn't stop an install either, which is worth being clear about: nothing resolves a
package through `index.json`. A name in `aqua.yaml` is resolved through `names.json` and the
file fetched from `pkgs/<shard>/<id>/versions/<escaped version>/registry-1.json`, so a package still
in that table installs whatever the catalogue says. Step 2 takes it out of both, which is
what stops a name resolving at all, and step 3 takes away what it resolved to.

Where the difference matters -- malware -- saying so where people will read it reaches
them and a registry change doesn't. That is the part to do first.
