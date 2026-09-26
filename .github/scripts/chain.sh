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
# How many failures in a row end the chain. The run that has just failed is one of
# them, so four more are read from the history.
readonly RECENT=4

# next is what the successor is told to chain in turn.
next() {
	if [ "$CHAIN" = forever ]; then
		echo forever
		return
	fi
	echo $((CHAIN - 1))
}

# failing says every one of the runs before this one failed as well.
#
# Counting the failures rather than what isn't one, so that a repository with fewer runs
# than that in its history can't reach the count and a chain is never given up on for
# want of history.
failing() {
	local failures
	failures=$(gh run list \
		--repo "$GITHUB_REPOSITORY" \
		--workflow ar2.yaml \
		--status completed \
		--limit "$RECENT" \
		--json conclusion \
		--jq '[.[] | select(.conclusion == "failure")] | length')
	[ "$failures" = "$RECENT" ]
}

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
	echo "::warning::five runs in a row failed; the chain stops here"
	gh issue comment "$ISSUE" \
		--repo "$GITHUB_REPOSITORY" \
		--body "The chain of ar2 runs stopped: five runs in a row failed. $RUN_URL"
}

main() {
	if [ "$OUTCOME" != success ] && failing; then
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
