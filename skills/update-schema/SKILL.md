---
name: update-schema
description: Roll out a new major version of the registry.json schema across aqua-registry-g2, which spans aqua, ar2 and this repository. Use when a field has to be added that an older aqua can't read, when asked how a schema change reaches the registry, and before designing one, since the first question decides whether it can be rolled out at all.
---

# Update the schema of registry.json

The schema's major version is the file name. `registry-1.json` is the first, and a change an
older aqua can't read arrives as `registry-2.json` written beside it, so an aqua that knows
only the first keeps working. A change an older aqua can read -- a field it ignores -- adds no
file; `schema_version` inside the file carries the full version.

Nothing here has been done yet. There is one schema, no migration in ar2 and no fallback in
aqua, so the steps below are what to build the first time rather than commands to run.

## First, whether it can be rolled out at all

Can the old file still be produced from what is known after the change?

The registry has to keep writing `registry-1.json` for versions published during the
migration, or an aqua that knows only schema 1 stops getting new releases the day the
migration starts. That is possible as long as the old file is derivable. A change that stops
recording something the old schema requires is a hard break, and then the support window has
to close at the same moment as the migration, which is a different plan from this one.

## In aqua

- The reader for the new schema, and the old reader kept. aqua reads what the registry has
  published, and it published the old one.
- The probe: an aqua that knows M asks for `registry-M.json` and steps down to `M-1` and so
  on. Majors are rare, so this is at most a couple of requests, and a version's file is
  cached forever once fetched. The fallback is also what makes a partly migrated package
  legitimate.

## In ar2

- Generate the newest schema, and write the old one from it by a one-way conversion. Not the
  other way round: a new schema exists to hold what the old one can't express, so deriving it
  from the old is deriving what isn't there.
- The old schema's type comes from aqua, which keeps it for reading, so nothing is maintained
  twice.
- A golden test per schema still being written: the same resolved version, the same bytes. A
  change to the internal form that would alter the old file then fails in ar2 rather than in
  the registry.
- The migration itself is a fourth kind of work in a run, at strictly lower priority than the
  sweep: the registry reflecting the present matters more than its files being uniform. It is
  bounded by the same `limit` and breadth as the backfill, so it is one pull request per
  package and the newest versions of every package are migrated before any package's history
  is completed.
- The state records, per package, the oldest schema last observed and when -- not what a run
  tried to do. A migration pull request that fails CI is then retried, because the next
  observation still sees the old schema.

## In this repository

- Raise the pin to the ar2 that knows the new schema.
- Let the chain run. Progress is `ar2 state`, which says how much of the registry is still on
  the old schema.
- Read the migration pull requests differently from generated ones. They assert nothing new
  about a release -- the same asset, the same checksum, rearranged -- so what to check is the
  diff, and the checks don't download anything. A field derived from the asset itself is the
  exception, and there the download is unavoidable.

## When the window closes

A change in ar2 stops writing the old schema, and new versions get only the new one. That is
an aqua release decision -- whether the aqua versions that know only the old schema are still
supported -- rather than anything this repository decides.

Published files are never deleted. Removing one is the only thing that breaks somebody who
hasn't updated, and what the registry would gain is a few kilobytes per version.
