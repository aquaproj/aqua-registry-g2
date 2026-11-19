#!/usr/bin/env bash
# Start a chain of ar2 runs when none is going.
#
# A chain ends from inside only when something inside could decide to end it, and the runs
# that have ended it lately couldn't: run 43969374319 stalled with the runner itself, hit
# the job's timeout without leaving a log, and was counted as a cancellation, so nothing
# was dispatched and nothing generated for 41 hours. This looks from outside instead, after
# a run that didn't succeed and on a schedule, and dispatches a chain if nothing is queued
# or running.
#
# The way to stop the chain is to disable the ar2 workflow; a disabled workflow is left
# alone here. Cancelling a run no longer stops it.
set -euo pipefail

# How many runs in a row that didn't succeed leave the restart to the schedule. chain.sh
# gives up after five failures, and a restart straight after that would spin on a breakage
# that doesn't go away; the schedule retries it at its own pace instead.
readonly STREAK=5

state=$(gh api "repos/$GITHUB_REPOSITORY/actions/workflows/ar2.yaml" --jq .state)
if [ "$state" != active ]; then
	echo "the ar2 workflow is $state; leaving it alone" >&2
	exit 0
fi

# A run dispatched a moment ago can take a moment to be listed: the successor a run
# dispatches is created before the run completes, but give it time to show up.
sleep "${SETTLE:-60}"

going=$(gh run list --repo "$GITHUB_REPOSITORY" --workflow ar2.yaml --limit 20 \
	--json status --jq '[.[] | select(.status != "completed")] | length')
if [ "$going" != 0 ]; then
	echo "an ar2 run is already queued or running" >&2
	exit 0
fi

# shellcheck source=.github/scripts/streak.sh
source "$(dirname "$0")/streak.sh"
if [ "$EVENT" = workflow_run ] && streak "$STREAK"; then
	echo "the last $STREAK runs didn't succeed; the schedule restarts the chain" >&2
	exit 0
fi

echo "no ar2 run is going; starting a chain" >&2
gh workflow run ar2.yaml --repo "$GITHUB_REPOSITORY" \
	--field limit="$LIMIT" \
	--field log_level=info \
	--field chain=forever
