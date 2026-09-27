# AGENTS.md

aqua-registry-g2 is a registry aqua reads as JSON rather than as YAML it has to evaluate.
Almost nothing in it is written by hand: [ar2](https://github.com/aquaproj/ar2) generates it
and opens pull requests, and CI decides what merges.

## Before writing anything

Everything that writes runs as a GitHub Actions workflow, not from a checkout. The
`require_sign` ruleset covers every branch and no actor bypasses it, and GitHub signs a commit
made through its API only when the caller is a GitHub App installation or Actions -- whose keys
are in this repository's environments. A commit made here with a user access token is refused,
however correct its contents.

So a change is `gh workflow run <workflow> -f ...`, and then reading the pull request it opens.
The `ar2` commands that only read can be run directly: `ar2 state`, `ar2 regenerate --dry-run`,
`ar2 test`, `ar2 validate-index`.

Two more rules: a pull request is required on `main` and on every `pkg_*` branch, and a package
branch cannot be deleted by anyone but an administrator.

## Where things are

- [README.md](README.md): what the repository holds and how it is laid out.
- [MAINTAINING.md](MAINTAINING.md): what a maintainer does, with the premises each procedure
  rests on.
- [skills/](skills): one procedure each, as a skill.
- [docs/review-pr.md](docs/review-pr.md): how to read a pull request ar2 opened, and what CI
  has already established about it.
- [CONTRIBUTING.md](CONTRIBUTING.md): for outside contributors. This repository takes issues
  and not pull requests.
