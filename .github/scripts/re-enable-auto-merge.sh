#!/usr/bin/env bash
# Turn auto-merge back on for a pull request GitHub turned it off for.
#
# What GitHub says, as the reason, decides what is done first:
#
# - The base branch was updated: the branch is brought up to date, and auto-merge turned on.
# - Anything else: GitHub is asked whether the pull request can be merged, once it has
#   worked that out. It usually can -- the reason was a moment after a push -- and auto-merge
#   is turned on. A catalogue that conflicts is made again by the index workflow, from
#   main, which turns auto-merge on as it opens the pull request. A version that conflicts
#   is left with a comment: its files are its package's own, so a conflict there is not a
#   moment's.
#
# A pull request GitHub keeps turning it off for is left to a person after a few tries,
# rather than turned back on for ever.
set -euo pipefail

# How many times a pull request may have auto-merge turned on, counting the time ar2 did.
readonly MAX_ENABLED=4

echo "auto-merge was turned off for #$PR: $REASON" >&2

enabled=$(gh api --paginate "repos/$GH_REPO/issues/$PR/timeline" \
	--jq '[.[] | select(.event == "auto_merge_enabled")] | length' | awk '{n += $1} END {print n + 0}')
if [ "$enabled" -ge "$MAX_ENABLED" ]; then
	gh pr comment "$PR" --body "GitHub has turned auto-merge off for this pull request $enabled times, the last time because: $REASON. It is left for a person to look at."
	exit 0
fi

enable() {
	gh pr merge "$PR" --auto --squash
}

update() {
	gh api --method PUT "repos/$GH_REPO/pulls/$PR/update-branch" >/dev/null
}

if [[ $REASON == *[Bb]ase\ branch* ]]; then
	update
	enable
	exit 0
fi

# GitHub works out whether a pull request can be merged after it is asked, and says
# "unknown" until then.
state=unknown
for _ in $(seq 12); do
	state=$(gh api "repos/$GH_REPO/pulls/$PR" --jq '.mergeable_state')
	if [ "$state" != unknown ]; then
		break
	fi
	sleep 10
done
echo "mergeable_state: $state" >&2

case "$state" in
dirty)
	if [ "$HEAD_REF" = ar2_index ]; then
		GH_TOKEN=$ACTIONS_TOKEN gh workflow run index.yaml
		exit 0
	fi
	gh pr comment "$PR" --body "GitHub turned auto-merge off for this pull request because: $REASON. It conflicts with main, so it is left for a person to look at."
	;;
behind)
	update
	enable
	;;
unknown)
	echo "GitHub didn't say whether the pull request can be merged, so nothing is done" >&2
	exit 1
	;;
*)
	enable
	;;
esac
