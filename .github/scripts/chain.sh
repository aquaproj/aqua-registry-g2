#!/usr/bin/env bash
# Dispatch the next run of the ar2 workflow, unless the chain has to stop.
#
# Called at the end of a run whatever the run did. What it decides is only whether
# there is a next run: a chain that keeps failing has to end, or a permanent breakage
# -- a pin that doesn't install, a token that isn't there -- becomes a failing run
# every couple of minutes for as long as nobody looks.
set -euo pipefail

# The floor on how often a run may follow a run. Generating takes minutes, so this
# never touches a run that did anything; what it slows down is the run that failed in
# seconds, which is the one that could otherwise spin.
readonly FLOOR=180
# How many runs in a row that didn't succeed end the chain. The run that has just failed
# is one of them, so four more are read from the history.
readonly RECENT=4

# next is what the successor is told to chain in turn.
next() {
	if [ "$CHAIN" = forever ]; then
		echo forever
		return
	fi
	echo $((CHAIN - 1))
}

# streak, shared with keep-chain.sh so both count a run that didn't succeed the same way.
# shellcheck source=.github/scripts/streak.sh
source "$(dirname "$0")/streak.sh"

# wait_out_the_floor sleeps until the run is old enough for another to follow it.
wait_out_the_floor() {
	local elapsed
	elapsed=$(($(date +%s) - STARTED_AT))
	if [ "$elapsed" -lt "$FLOOR" ]; then
		sleep $((FLOOR - elapsed))
	fi
}

# give_up says on the monitoring issue that nothing is generating any more.
give_up() {
	echo "::warning::five runs in a row failed or were cancelled; the chain stops here"
	gh issue comment "$ISSUE" \
		--repo "$GITHUB_REPOSITORY" \
		--body "The chain of ar2 runs stopped: five runs in a row failed or were cancelled. keep-ar2-going.yaml tries again every hour. $RUN_URL"
}

main() {
	# Disabling the workflow is how the chain is stopped, and the run that was going when it
	# was disabled shouldn't fail for it.
	if [ "$(gh api "repos/$GITHUB_REPOSITORY/actions/workflows/ar2.yaml" --jq .state)" != active ]; then
		echo "the ar2 workflow is disabled; the chain stops here" >&2
		return
	fi
	if [ "$OUTCOME" != success ] && streak "$RECENT"; then
		give_up
		return
	fi
	wait_out_the_floor
	gh workflow run ar2.yaml \
		--repo "$GITHUB_REPOSITORY" \
		--field limit="$LIMIT" \
		--field log_level="$LOG_LEVEL" \
		--field chain="$(next)"
}

main
