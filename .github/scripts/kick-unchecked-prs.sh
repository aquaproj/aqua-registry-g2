#!/usr/bin/env bash
# Start the checks of a pull request ar2 opened that no workflow ever ran for.
#
# GitHub now and then drops a pull request's event: #32364 was opened at 07:44 and nothing ran
# for it -- no check, no run for its head commit -- so its auto-merge waited on checks that
# were never coming, for hours. Bringing the branch up to date pushes a commit, and the push
# is a synchronize event that starts the checks again. Auto-merge stays on, which closing and
# reopening the pull request would turn off.
#
# GH_TOKEN has to be the app's: a branch updated with GITHUB_TOKEN starts no workflow, which
# is the one thing this is for.
#
# Only a pull request nothing has touched for a while is looked at. One just opened or just
# pushed to has no checks yet for a moment, and updating it would only push another commit.
set -euo pipefail

# How long a pull request has to sit untouched, with no checks, before it is updated.
readonly QUIET=${QUIET:-1800}

cutoff=$(date -u -d "@$(($(date +%s) - QUIET))" +%Y-%m-%dT%H:%M:%SZ)

prs=$(gh pr list \
	--repo "$GH_REPO" \
	--author app/aquaproj-g2-pr \
	--state open \
	--limit 1000 \
	--json number,updatedAt,statusCheckRollup \
	--jq ".[] | select(.updatedAt < \"$cutoff\") | select((.statusCheckRollup | length) == 0) | .number")
if [ -z "$prs" ]; then
	echo "every pull request of ar2's has its checks" >&2
	exit 0
fi

while read -r pr; do
	echo "#$pr has no checks; bringing its branch up to date to start them" >&2
	# A branch already up to date can't be updated, and one failure shouldn't keep the rest
	# waiting; the next run tries it again.
	gh pr update-branch "$pr" --repo "$GH_REPO" || echo "::warning::#$pr couldn't be updated"
done <<<"$prs"
