#!/usr/bin/env bash
# Sourced by chain.sh and keep-chain.sh, so both count a streak of runs that didn't
# succeed the same way.

# streak says the last $1 ar2 runs that got as far as running a job all ended in something
# other than success: failure, a cancellation (the job's timeout, or a person), timed_out,
# startup_failure.
#
# A run that ran no job is skipped. The ar2 workflow keeps one run pending in its
# concurrency group, and dispatching another cancels the pending one before it starts; that
# is the chain being handed over, not the chain failing.
#
# Fewer runs than that in the history are no streak, so a chain is never given up on for
# want of history.
streak() {
	# A call that fails answers "no streak": streak runs where errexit doesn't, and a chain
	# given up on wrongly is worse than one that goes on a run longer.
	local want=$1 seen=0 unsuccessful=0 id conclusion jobs runs
	runs=$(gh run list \
		--repo "$GITHUB_REPOSITORY" \
		--workflow ar2.yaml \
		--status completed \
		--limit $((want * 3)) \
		--json databaseId,conclusion \
		--jq '.[] | "\(.databaseId) \(.conclusion)"') || return 1
	while read -r id conclusion; do
		if [ "$conclusion" = cancelled ]; then
			jobs=$(gh api "repos/$GITHUB_REPOSITORY/actions/runs/$id/jobs" --jq .total_count) || return 1
			if [ "$jobs" = 0 ]; then
				continue
			fi
		fi
		seen=$((seen + 1))
		if [ "$conclusion" != success ]; then
			unsuccessful=$((unsuccessful + 1))
		fi
		if [ "$seen" = "$want" ]; then
			break
		fi
	done <<<"$runs"
	[ "$seen" = "$want" ] && [ "$unsuccessful" = "$want" ]
}
