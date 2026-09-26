# Reviewing a pull request from ar2

Most of them merge themselves. A run generates `versions/<version>/registry-1.json` for
each version a package is missing, opens one pull request per package, and turns on
auto-merge; CI downloads every asset the files describe, on a machine of the
environment each entry is for, and opens it. A pull request that merges without anyone
reading it is the normal case, and the trust in it comes from that check rather than
from anyone's judgement.

So a pull request waiting for a human is a pull request ar2 decided it could not answer
for -- or one a person asked for, which `ar2 regenerate` opens and never auto-merges. Its
body says which case it is. This is what to do about each.

## What not to check

CI has already established, for every entry in the pull request:

- the asset exists, downloads, and its checksum is the one recorded
- the archive opens, and `files[].src` names something inside it
- every signature the entry claims has been verified with the tool the entry names
- an entry for `linux/amd64` was checked on a Linux amd64 machine, and so on for the
  six environments

None of that needs reading again. The generated files are one line each and nothing is
learned by looking at them.

## The version is verifiable with less than the one before it

> These versions can be verified with less than the version before them

The release stopped carrying a signature that the previous version had. That is also
what an attacker publishing a release would look like from here, which is why it stops.

Check upstream: a project that moved from cosign to attestations, or retired a key, says
so in its release notes or its workflow. A project that says nothing about it is the
case this exists for.

## `files[].src` didn't match the archive

The path the definition gives isn't in the archive. ar2 looked for a file of the right
name anywhere inside and used that, which is a guess, or found nothing at all.

What is usually true is that upstream changed the layout, and the definition needs
updating. What is sometimes true is that the wrong asset was chosen — see below — and
the file is missing because the archive is a different program's.

## The archive couldn't be opened

No machine in the matrix has a tool for the format. The checksum is still recorded, so
the entry is complete; what is missing is the confirmation that the files are where the
entry says. Rare, and a reason to look at the format rather than the package.

## A version_constraint couldn't be turned into a boundary

> These version_constraints of the definition couldn't be turned into boundaries, so
> the overrides are carried over in the order aqua-registry had them

This is the common one, and the only one where the thing to check is the definition
rather than the release.

aqua-registry lists its overrides oldest first, each bounded above, and reads them top
down. This registry reads them the other way: the conversion reverses the list and
gives each entry the lower bound of the range it covers, so that an entry means the same
thing read from either end. A constraint that names versions rather than bounding them
— `Version in ["v0.3.6", "v0.4.0"]`, or `semver("<= 0.1.7") or Version == "v0.2.1"` —
can't give the entry above it a bound, so nothing can be derived and the list is carried
over in the order it had.

Carried over, the order still resolves the same way, because both registries read their
overrides in order and take the first match. The pull request is asking for that to be
confirmed rather than reporting a problem.

Four steps:

1. Read the constraints the body names.
2. Open `registry.yaml` on the package's branch and check its overrides are
   aqua-registry's, in aqua-registry's order. The top-level `version_constraint` is
   gone, which is expected: there is none here, and it was `"false"` there.
3. For each version the body lists, work out which override matches first in that
   order, and confirm aqua-registry picks the same one.
4. Check the last override is a catch-all — `version_constraint: "true"`.

### Why the last entry matters

A version matching no override takes `version_overrides[0]`.

When the conversion succeeded that is the newest definition, which is the sensible
answer for a tag that isn't a version at all. When it didn't, the list is in
aqua-registry's order, so the first entry is the *oldest* definition — and a version
falling through to it would be resolved by a definition written for releases years
older.

It is unreachable as long as the list ends in a catch-all, which aqua-registry's lists
do. Step 4 is checking that it does.

## The pull request replaces what the registry already serves

> Generated again by `ar2 regenerate`, from the definition on the package's branch

Not a version being added: a version being replaced. Somebody found a definition wrong
and fixed it, and these are the files that were generated under the old one.

Auto-merge is never on for these, whatever the files look like, because what CI
establishes is the same as always — the assets download, the checksums match, the
archives open, the signatures verify — and none of that says replacing the old file was
right. Only the versions whose file actually changed are in it.

What to check is the definition rather than the release: read the change that prompted
it on the package's branch, and confirm the new files are what that change should
produce. `git diff` between the pull request and the package branch shows what moved in
each version; the old file stays in the branch's history either way.

If that definition change also touched what the catalogue holds -- the description, the
link, the search words, the aliases -- `ar2 index <package>` brings the entry along.
Nothing else notices: the reconciliation asks which packages the catalogue is missing,
and a package whose description changed isn't missing.

## What CI cannot catch

The asset names are not read from the definition. aqua-registry's `asset` is dropped
and the naming is inferred from the release's own asset list, so that an upstream
renaming doesn't have to be chased in a template. The inference can choose wrongly when
a release carries more than one program.

`openai/codex` publishes about 180 assets for a dozen programs in one release, and the
inference chose `bwrap-x86_64-unknown-linux-musl.tar.gz` for Linux — bubblewrap, which
that release also ships. The check caught it, but through its consequence: the archive
held no `codex`, so `files[].src` didn't resolve. An asset that is the wrong build of
the right program would pass everything.

`all_assets_filter` in the package's `registry.yaml` is what narrows the list the
inference sees, and `asset_filters` says it per version, for a package where which asset
is the command changed over its history -- `codex` was `codex-<triple>` until 0.133 and
`codex-package-<triple>` after it, which one filter can't say. Neither is read from the
release, so both are written by hand.

So when a pull request is waiting on `files[].src`, and the asset it names belongs to
something other than the package, the filter is what to fix. It is in the definition, and
the fix is [How To Fix registry.yaml](../MAINTAINING.md#how-to-fix-registryyaml) followed
by generating the versions again. A package the registry hasn't taken over yet has its
definition in the pull request itself, converted from aqua-registry, where the filter came
from that repository's `scaffold.yaml`; there it is the pull request that is wrong and
fixing it is a commit onto the same branch.
