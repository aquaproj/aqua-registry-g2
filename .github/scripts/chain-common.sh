#!/usr/bin/env bash
# Sourced by chain.sh and keep-chain.sh, so that both read the chain's state the same way.

# disabled says the ar2 workflow has been disabled, which is how the chain is stopped.
#
# A lookup that fails answers no. Dispatching to a disabled workflow fails harmlessly,
# while reading a failed lookup as disabled stops the chain without a word.
disabled() {
	local state
	state=$(gh api "repos/$GITHUB_REPOSITORY/actions/workflows/ar2.yaml" --jq .state) || return 1
	[[ $state == disabled* ]]
}

# streak says the last $1 ar2 runs that ran all ended without succeeding: failure, timed_out,
# startup_failure, or cancelled after a job had started (the job's timeout, or a person).
#
# Other runs are passed over rather than counted either way. A run cancelled before any job
# started is one the concurrency group replaced -- ar2 keeps one run pending, and dispatching
# another cancels it -- which is the chain being handed over, not failing. skipped, neutral
# and action_required aren't the chain failing either.
#
# Fewer runs than that in the history are no streak, so a chain is never given up on for
# want of history. A gh call that fails answers no as well: streak runs where errexit
# doesn't, and a chain given up on wrongly is worse than one that goes on a run longer.
streak() {
	local want=$1 seen=0 unsuccessful=0 id conclusion started runs
	runs=$(gh run list \
		--repo "$GITHUB_REPOSITORY" \
		--workflow ar2.yaml \
		--status completed \
		--limit $((want * 3)) \
		--json databaseId,conclusion \
		--jq '.[] | "\(.databaseId) \(.conclusion)"') || return 1
	while read -r id conclusion; do
		case $conclusion in
		success) ;;
		failure | timed_out | startup_failure)
			unsuccessful=$((unsuccessful + 1))
			;;
		cancelled)
			started=$(gh api "repos/$GITHUB_REPOSITORY/actions/runs/$id/jobs" \
				--jq '[.jobs[] | select((.steps | length) > 0)] | length') || return 1
			if [ "$started" = 0 ]; then
				continue
			fi
			unsuccessful=$((unsuccessful + 1))
			;;
		*)
			continue
			;;
		esac
		seen=$((seen + 1))
		if [ "$seen" = "$want" ]; then
			break
		fi
	done <<<"$runs"
	[ "$seen" = "$want" ] && [ "$unsuccessful" = "$want" ]
}

# new_streak says the streak of $1 has just been reached: one run longer was not a streak.
# What is said on the monitoring issue is said once for an outage, not again for each
# hourly retry that fails the same way.
new_streak() {
	streak "$1" && ! streak $(($1 + 1))
}
