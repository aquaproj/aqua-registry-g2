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

# waiting says another ar2 run of the order is queued or pending: one a person dispatched
# while this run was going. A run naming its packages is in a concurrency group of its own,
# so it is passed over: it waits for nothing and nothing waits for it.
#
# The concurrency group keeps one run pending and cancels it when another is dispatched, so
# dispatching the successor here would cancel that run before it started -- run
# 45135575942, naming eight packages, went that way. Leaving it pending lets it run next.
# keep-ar2-going.yaml starts the chain again once it ends, as it does after any run dispatched
# by hand, and a run dispatched with a chain of its own carries on by itself.
#
# The run this is part of is passed over too. It hasn't completed while its chain job runs,
# and it was listed as one of those states: runs 45268034620, 45306726322 and 45405981254
# each found a run waiting when none was, dispatched nothing, and the chain stood still for
# hours until the schedule, which GitHub runs late, started it again.
#
# A lookup that fails answers no, so the chain goes on as it did before.
waiting() {
	local runs
	runs=$(gh run list \
		--repo "$GITHUB_REPOSITORY" \
		--workflow ar2.yaml \
		--json databaseId,status,displayTitle \
		--jq ".[] | select(.databaseId != $RUN_ID) | select(.displayTitle | contains(\" named \") | not) | select(.status == \"queued\" or .status == \"pending\" or .status == \"waiting\" or .status == \"requested\") | \"\\(.databaseId) \\(.status)\"") || return 1
	if [ -z "$runs" ]; then
		return 1
	fi
	echo "waiting: $runs" >&2
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
	if waiting; then
		echo "an ar2 run is already waiting to start; it goes first, and the chain is started again after it" >&2
		return
	fi
	gh workflow run ar2.yaml \
		--repo "$GITHUB_REPOSITORY" \
		--field limit="$LIMIT" \
		--field log_level="$LOG_LEVEL" \
		--field chain="$(next)"
}

main
