# AGENTS.md

aqua-registry-g2 is a registry aqua reads as JSON rather than as YAML it has to evaluate.
Almost nothing in it is written by hand: [ar2](https://github.com/aquaproj/ar2) generates it
and opens pull requests, and CI decides what merges.

## Before writing anything

Don't commit from a checkout. A commit made here with a user access token isn't signed, and a
ruleset covering every branch refuses it, however correct its contents. A change is
`gh workflow run <workflow> -f ...` and then reading the pull request it opens --
[MAINTAINING.md](MAINTAINING.md#everything-that-writes-runs-in-github-actions) says which
workflow, and why the rest of the repository is shaped around this.

The `ar2` commands that only read can be run directly: `ar2 state`,
`ar2 regenerate --dry-run`, `ar2 test`, `ar2 validate-index`.

## Where things are

- [README.md](README.md): what the repository holds and how it is laid out.
- [MAINTAINING.md](MAINTAINING.md): what a maintainer does, with the premises each procedure
  rests on.
- [skills/](skills): one procedure each, as a skill.
- [docs/review-pr.md](docs/review-pr.md): how to read a pull request ar2 opened, and what CI
  has already established about it.
- [CONTRIBUTING.md](CONTRIBUTING.md): for outside contributors. This repository takes issues
  and not pull requests.
