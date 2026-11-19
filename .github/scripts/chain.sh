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

# disabled, streak and new_streak, shared with keep-chain.sh.
# shellcheck source=.github/scripts/chain-common.sh
source "$(dirname "$0")/chain-common.sh"

# wait_out_the_floor sleeps until the run is old enough for another to follow it.
#
# The run's own start rather than one its first job recorded: a job cancelled by its
# timeout leaves no outputs. A lookup that fails waits nothing, since the floor only slows
# down a chain and missing it once can't make one spin.
wait_out_the_floor() {
	local started elapsed
	started=$(gh api "repos/$GITHUB_REPOSITORY/actions/runs/$RUN_ID" --jq .run_started_at) || return 0
	elapsed=$(($(date +%s) - $(date -d "$started" +%s)))
	if [ "$elapsed" -lt "$FLOOR" ]; then
		sleep $((FLOOR - elapsed))
	fi
}

# give_up says on the monitoring issue that nothing is generating any more.
give_up() {
	echo "::warning::five runs in a row failed or were cancelled; the chain stops here"
	gh issue comment "$ISSUE" \
		--repo "$GITHUB_REPOSITORY" \
		--body "The chain of ar2 runs stopped: five runs in a row failed or were cancelled. keep-ar2-going.yaml tries again every hour, and this isn't said again until a run succeeds. $RUN_URL"
}

main() {
	# Disabling the workflow is how the chain is stopped, and the run that was going when it
	# was disabled shouldn't fail for it.
	if disabled; then
		echo "the ar2 workflow is disabled; the chain stops here" >&2
		return
	fi
	if [ "$OUTCOME" != success ] && streak "$RECENT"; then
		# Said once: a retry from keep-ar2-going.yaml that fails again finds the streak one
		# longer, and that was said already.
		if ! streak $((RECENT + 1)); then
			give_up
		fi
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
