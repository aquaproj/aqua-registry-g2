# Contributing

We don't accept pull requests from contributors.
As described in README.md, most of files are automatically maintained.
And we maintain the automation tools like GitHub Actions and [ar2](https://github.com/aquaproj/ar2).
Please create an issue if you have any problem.

This document is for outside contributors.
For maintainers, see [MAINTAINING.md](MAINTAINING.md).

## For non-aqua users

aqua-registry-g2 is a registry for aqua, not for other tools.
So we don't accept bug reports that haven't been reproduced using aqua.
If you face a problem using another tool, please ask that tool's community for help first, and confirm that you can reproduce the problem using aqua before creating an issue in this repository.
If you can, please [create an issue using the issue template](https://github.com/aquaproj/aqua-registry-g2/issues/new?template=02-bug-report.yml).

### Background

As of 2026-09-27, other tools like [mise](https://github.com/jdx/mise), [Docker Agent](https://github.com/docker/docker-agent), [Atmos](https://github.com/cloudposse/atmos), and [Dagu](https://github.com/dagucloud/dagu) use [aqua-registry](https://github.com/aquaproj/aqua-registry).

References:

- [mise](https://mise.jdx.dev/dev-tools/backends/aqua.html)
- [Inside Dagu v2.7.0: Reproducible Workflows](https://dagu.sh/blog/inside-dagu-v2-7-actions)
- [Docker Agent: Auto-Installing Tools](https://github.com/docker/docker-agent/blob/9d110ae3498808feaa4be3c85f307a6701ada2d6/docs/configuration/tools/index.md#auto-installing-tools)
- [Atmos toolchain](https://atmos.tools/cli/commands/toolchain/usage)

As a result, users of these tools sometimes report issues that can't be reproduced using aqua, and we can't address them.

## How To Add packages

Create a GitHub Issue from the [issue template](https://github.com/aquaproj/aqua-registry-g2/issues/new?template=01-new-package.yml).

## How To Support a new version

registry.json is automatically created by GitHub Actions via schedule event.
So please wait for a while.
The mutable versions like `latest`, `develop`, and `nightly` aren't supported.

## How To Fix index.json

index.json is automatically updated by GitHub Actions via schedule event.

## How To Fix aliases.json

aliases.json is automatically updated via GitHub Actions.
So we don't need to fix it manually.
It is rendered from the aliases in index.json, so a missing alias is a missing alias in the package's registry.yaml.

A repository transfer needs nothing.
We notice the repository answering to another name, move the package to that name, and keep the old one as an alias, so a configuration still asking for it keeps working.
This takes two steps that run on their own schedules, so please wait for a while.

- [.github/workflows/index.yaml](.github/workflows/index.yaml): Periodically updates index.json and aliases.json together.
- [.github/workflows/ar2.yaml](.github/workflows/ar2.yaml): Moves a package whose repository was renamed or transferred.
