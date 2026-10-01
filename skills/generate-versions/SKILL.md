---
name: generate-versions
description: Generate the versions aqua-registry-g2 is missing, which is how a package gets a new release, for a named package or for whatever the order reaches, and start or stop the chain of runs that does it. Use when a version is missing from the registry, when asked to generate a particular package now, when asked to run the backfill, or when asked how often the registry updates itself.
---

# Generate the versions the registry is missing

Wait, or run [ar2.yaml](../../.github/workflows/ar2.yaml):

```sh
gh workflow run ar2.yaml -f limit=<how many package versions>                 # one run
gh workflow run ar2.yaml -f limit=<how many package versions> -f chain=forever
```

A run generates the versions the registry is missing, most starred package first and newest
version first, and opens one pull request per package. Most of them merge themselves; what to
do about one that doesn't is [reviewing it](../review-pull-request/SKILL.md). The job
summary says what was generated, what wasn't, and how far the registry has got.

To stop a chain, cancel the run that is going.

### Generating one package now

Name it, and the run works through the named packages instead of the order:

```sh
gh workflow run ar2.yaml -f packages="ko-build/ko"
gh workflow run ar2.yaml -f packages="ko-build/ko sigstore/cosign" -f limit=20
```

Nothing else changes: each one is taken over, generated and put to a pull request the way the
order would have, whenever its turn came. Which is what makes it worth naming one -- a package
the order reaches in a week, because something was fixed and it is the package that was
waiting for it, or one an issue is asking about.

A package aqua-registry doesn't have isn't in the order to be named, and the run says so
rather than doing nothing quietly. [Adding it](../add-package/SKILL.md) is what puts it there.

### How the cadence works

There is no schedule. A run dispatches the next one, which is what `chain` asks for:
`forever` keeps going, a number counts down, and `0` is a single run. The cadence is then
however long a run takes rather than whenever GitHub gets to a cron -- a workflow asking for
every ten minutes is triggered every few hours -- and the registry spends no time idle.

Nothing is dispatched after a cancellation, and a run that hit its timeout counts as one, so
a run that got stuck ends the chain rather than handing the same state to another run to get
stuck on. A failure does not end it, because a rate limit or a repository that didn't answer
would otherwise stop the registry until somebody noticed; five failures in a row do, with a
comment on the monitoring issue.

`limit` bounds the versions attempted, not the versions generated, so a package that fails
every time can't spend a whole run.
