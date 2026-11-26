---
name: check-pull-requests
description: Go over the open pull requests of aqua-registry-g2 that need a person or have stopped -- waiting for review or a definition, failing CI, or not merging though nothing says why -- and say what each needs. Use when asked to check the registry's pull requests, to check needs-review, or to keep watching them, which is this run on an interval with /loop.
---

# Check the open pull requests

Almost every pull request ar2 opens merges itself, and three workflows pick up most of what
stops one: [rerun-transient-failures.yaml](../../.github/workflows/rerun-transient-failures.yaml)
re-runs a check that failed for a reason it recognises,
[re-enable-auto-merge.yaml](../../.github/workflows/re-enable-auto-merge.yaml) turns auto-merge
back on when GitHub turns it off, and the hourly
[kick-unchecked-prs.sh](../../.github/scripts/kick-unchecked-prs.sh) starts the checks of a
pull request no workflow ran for. This is the pass over what is left after them, in three
parts.

To keep watching rather than look once, run it on an interval: `/loop 30m /check-pull-requests`.

It only reads and re-runs checks. Merging and closing are a person's decision; what this
pass produces is, for each pull request, what it is waiting on and what would move it.

## Waiting for a person

```sh
gh pr list --label needs-review
gh pr list --label needs-definition
gh pr list --label replaces-published
```

Each is one of the cases [review-pull-request](../review-pull-request/SKILL.md) describes,
and that skill is how to read it. Two things find most answers quickly:

- The release's assets beside the previous version's: `gh release view <tag> -R <repo>
  --json assets`. An environment lost is usually the release not building it.
- Generating the version again with the debug log, which says why an environment went --
  a binary built for another arch than its name says, an archive named for a format its
  content isn't:

  ```sh
  GITHUB_TOKEN=$(gh auth token) ar2 run <package>@<version> --skip-pr --output <file> --log-level debug
  ```

  It writes nothing to the repository. It reads the definition from GitHub, not from the
  working tree, so it can't try a definition that hasn't been pushed.

## Failing CI

```sh
gh pr list --author app/aquaproj-g2-pr --json number,title,statusCheckRollup \
  --jq '.[] | select(any(.statusCheckRollup[]; .conclusion == "FAILURE")) | "\(.number) \(.title)"'
```

Read the failed job's log: `gh run view --job <id> --log`, or the check run's annotations
when the log is empty because the job failed in its first step.

- The network or a server, and rerun-transient-failures didn't re-run it -- a wording its
  TRANSIENT pattern doesn't have yet, such as Windows' `connectex: A connection attempt
  failed`: re-run it with `gh run rerun <run id> --failed`, and add the wording to
  [rerun-transient-failures.sh](../../.github/scripts/rerun-transient-failures.sh) so the
  next one is re-run without anybody.
- Anything else is the release or the definition, and is read like a pull request waiting
  for a person, above.

## Not merging, and nothing says why

A pull request of ar2's without a label is one that should have merged. One that is still
open half an hour after it was last touched has stopped:

- No checks at all: GitHub dropped its event. `gh pr update-branch <number>` pushes a
  commit, which starts them, and keeps auto-merge on, which closing and reopening would turn
  off.
- Checks passed and auto-merge is off: re-enable-auto-merge gave up. Its run's log says why
  -- `gh run list --workflow re-enable-auto-merge.yaml` -- and the pull request can merge as
  it is.
