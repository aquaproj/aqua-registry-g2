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
# How the run this was triggered by ended; empty on the schedule.
readonly TRIGGER_CONCLUSION=${CONCLUSION:-}

# shellcheck source=.github/scripts/chain-common.sh
source "$(dirname "$0")/chain-common.sh"

if disabled; then
	echo "the ar2 workflow is disabled; leaving it alone" >&2
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

if [ "$EVENT" = workflow_run ] && streak "$STREAK"; then
	echo "the last $STREAK runs didn't succeed; the schedule restarts the chain" >&2
	# chain.sh says so on the monitoring issue when the run that made the streak failed,
	# since it ran. A run that was cancelled by the job's timeout, or never started, ran no
	# chain.sh, and nobody would hear of a chain that stalls every time.
	if [ "$TRIGGER_CONCLUSION" != failure ] && new_streak "$STREAK"; then
		gh issue comment "$ISSUE" \
			--repo "$GITHUB_REPOSITORY" \
			--body "The chain of ar2 runs stopped: five runs in a row failed or were cancelled, the last one $TRIGGER_CONCLUSION. keep-ar2-going.yaml tries again every hour, and this isn't said again until a run succeeds. $RUN_URL"
	fi
	exit 0
fi

# Again, since it may have been disabled while this waited, and dispatching to a disabled
# workflow fails.
if disabled; then
	echo "the ar2 workflow is disabled; leaving it alone" >&2
	exit 0
fi

echo "no ar2 run is going; starting a chain" >&2
gh workflow run ar2.yaml --repo "$GITHUB_REPOSITORY" \
	--field limit="$LIMIT" \
	--field log_level=info \
	--field chain=forever
