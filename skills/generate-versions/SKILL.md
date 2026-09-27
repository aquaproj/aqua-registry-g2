---
name: generate-versions
description: Generate the versions aqua-registry-g2 is missing, which is how a package gets a new release, and start or stop the chain of runs that does it. Use when a version is missing from the registry, when asked to run the backfill, or when asked how often the registry updates itself.
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
