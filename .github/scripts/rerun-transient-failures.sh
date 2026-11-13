#!/usr/bin/env bash
# Re-run the failed jobs of a check run whose every failure was the network's, not the code's.
#
# A failed job is read as transient when its log has one of the patterns below: a 5xx from
# a server, or a connection that broke. Run 42568811742 is the kind meant -- aqua-installer
# got a 504 from github.com six times running, and the same run passed when re-run.
#
# Every failed job has to look transient, or nothing is re-run: a run with one real failure
# would fail again anyway. status-check-* jobs are left out, since they fail only because a
# job they need did.
set -euo pipefail

readonly TRANSIENT='returned error: 5[0-9]{2}|HTTP[/ 0-9.]* 5[0-9]{2}|status code:? 5[0-9]{2}|50[234] (Bad Gateway|Service Unavailable|Gateway Time-?out)|connection reset by peer|TLS handshake timeout|i/o timeout'

jobs=$(gh run view "$RUN_ID" --attempt "$RUN_ATTEMPT" --json jobs \
	--jq '.jobs[] | select(.conclusion == "failure") | select(.name | startswith("status-check") | not) | .databaseId')
if [ -z "$jobs" ]; then
	echo "run $RUN_ID has no failed job to look at" >&2
	exit 0
fi

while read -r job; do
	if ! gh run view "$RUN_ID" --job "$job" --log-failed | grep -Eiq -- "$TRANSIENT"; then
		echo "job $job of run $RUN_ID failed for a reason that doesn't look transient; not re-running" >&2
		exit 0
	fi
done <<<"$jobs"

# A moment's wait, so a server that was down a moment ago has had the moment.
sleep 60
echo "re-running the failed jobs of run $RUN_ID (attempt $RUN_ATTEMPT)" >&2
gh run rerun "$RUN_ID" --failed
