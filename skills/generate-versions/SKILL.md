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
version first, and opens one pull request per version. Most of them merge themselves; what to
do about one that doesn't is [reviewing it](../review-pull-request/SKILL.md). The job
summary says what was generated, what wasn't, and how far the registry has got.

To stop the chain, disable the workflow, and enable it to start it again:

```sh
gh workflow disable ar2.yaml
gh workflow enable ar2.yaml
```

Enabling it doesn't start a chain at once: the hourly check does, and GitHub runs a schedule
hours late at times. Dispatch a run with `chain=forever` to start one now.

While the workflow is enabled, a chain is always going. A single run, or a chain with a
number, is generating on top of it or until it comes back: once it ends with nothing else
going, a `chain=forever` run is started again.

Cancelling a run doesn't stop it: the job that dispatches the next run runs after a cancelled
one too, and a chain that ended without being stopped is started again by
[keep-ar2-going.yaml](../../.github/workflows/keep-ar2-going.yaml).

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

A failure does not end it, because a rate limit or a repository that didn't answer would
otherwise stop the registry until somebody noticed; a run where `ar2 run` didn't finish in its
25 minutes is one of those. Five runs in a row that failed or were cancelled do end it, so a
breakage that doesn't go away can't keep a failing run going every few minutes. That is said
once on the monitoring issue, by chain.sh, which runs after a cancelled run as well; the hourly
retries that fail the same way aren't said again. A run cancelled before it started a job -- the pending run a dispatch replaced --
isn't counted.

A run that ends the chain without meaning to is the other case. The next run is dispatched
from a job of its own that runs whatever became of the run job, so a run cancelled by the job's
timeout -- run 43969374319 stalled with its runner, and nothing generated for 41 hours -- still
hands over. keep-ar2-going.yaml covers what that can't: every hour it starts a chain if no ar2
run is queued or running and the workflow is enabled, which catches a dispatch that failed, the
restart after five runs in a row that didn't succeed, and a single run or a finite chain ending.
GitHub runs it late at times. It also runs after a hand-dispatched run that ends; it can't after
the chain's own runs, since workflow_run doesn't fire for a run dispatched with GITHUB_TOKEN.

`limit` bounds the versions attempted, not the versions generated, so a package that fails
every time can't spend a whole run.
