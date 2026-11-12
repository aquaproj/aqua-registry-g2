#!/usr/bin/env bash
# Bring the next few version pull requests of the backlog up to date with main, so their
# checks run again, and dispatch the next run of the backlog workflow.
#
# The backlog is the pull requests the chain of ar2 runs opened on 2026-10-16 and 17, whose
# checks ran out of GITHUB_TOKEN's budget and failed. Their files were never the problem:
# brought up to date with main, the checks run as they are now and the pull request merges
# itself, since auto-merge is still on. "Re-run failed jobs" would run the workflows of the
# commit the run was for, October's, so the branch is updated instead.
#
# What is taken: open pull requests of ar2's app with auto-merge on, a version branch
# (ar2_<id>_<version>, not a review), failing checks, and nothing done to them since
# BEFORE. An update counts as something done, so a pull request whose checks fail again
# after one is not taken a second time: it is a real failure, and left for a person.
#
# The runners decide the pace. macOS is what every package pull request queues for, so
# nothing is updated while the repository already has more than BUSY runs queued or
# running, and the run waits out FLOOR seconds before dispatching the next.
set -euo pipefail

readonly BUSY=30
readonly FLOOR=900

started=$(date +%s)

busy=$(GH_TOKEN=$ACTIONS_TOKEN gh run list --repo "$GH_REPO" --limit 200 --json status \
	--jq '[.[] | select(.status == "queued" or .status == "in_progress" or .status == "waiting" or .status == "pending")] | length')
echo "runs queued or running: $busy" >&2

# The pull requests to take, oldest first, written to a file. The search finds the failing
# ones; whether a branch is a version's and auto-merge is on is read from each. A hundred is
# more than a batch, so one page is read rather than every page.
# shellcheck disable=SC2016 # GraphQL variables, not shell ones
gh api graphql \
	-f q="repo:$GH_REPO is:pr is:open author:app/$APP status:failure updated:<$BEFORE sort:created-asc" \
	-f query='
query($q: String!) {
  search(query: $q, type: ISSUE, first: 100) {
    nodes { ... on PullRequest { number headRefName autoMergeRequest { enabledAt } } }
  }
}' --jq '.data.search.nodes[] | select(.autoMergeRequest != null) | select(.headRefName | test("^ar2_[0-9]+_[^_]")) | .number' > candidates.txt
left=$(wc -l < candidates.txt)
if [ "$left" -eq 0 ]; then
	echo "no pull request of the backlog is left; the chain stops here" >&2
	echo "The backlog is done: no failing version pull request untouched since $BEFORE is left." >> "$GITHUB_STEP_SUMMARY"
	exit 0
fi

if [ "$busy" -gt "$BUSY" ]; then
	echo "more than $BUSY runs are queued or running; nothing is updated this time" >&2
	echo "Skipped: $busy runs were queued or running." >> "$GITHUB_STEP_SUMMARY"
else
	updated=0
	while read -r pr; do
		if [ "$DRY_RUN" = true ]; then
			echo "would update #$pr" >&2
			continue
		fi
		if gh api --method PUT "repos/$GH_REPO/pulls/$pr/update-branch" >/dev/null; then
			updated=$((updated + 1))
		else
			echo "::warning::could not update #$pr"
		fi
	done < <(head -n "$BATCH" candidates.txt)
	echo "Updated $updated pull requests of the backlog." >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$DRY_RUN" = true ] || [ "$CHAIN" = 0 ]; then
	exit 0
fi
elapsed=$(($(date +%s) - started))
if [ "$elapsed" -lt "$FLOOR" ]; then
	sleep $((FLOOR - elapsed))
fi
next=forever
if [ "$CHAIN" != forever ]; then
	next=$((CHAIN - 1))
fi
GH_TOKEN=$ACTIONS_TOKEN gh workflow run backlog.yaml --repo "$GH_REPO" \
	--field batch="$BATCH" --field before="$BEFORE" --field chain="$next"
