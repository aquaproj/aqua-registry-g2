#!/usr/bin/env bash
# Re-run the failed jobs of a check run whose every failure was the network's or the machine's,
# not the code's.
#
# A failed job is read as transient when its log has one of the patterns below: a 5xx from
# a server, or a connection that broke or timed out. Run 42568811742 is the kind meant -- aqua-installer
# got a 504 from github.com six times running, and the same run passed when re-run. Run
# 45168555588's darwin job is the timed-out kind: "read: operation timed out" downloading
# deno's asset, the error macOS gives where Linux says "i/o timeout". Run 45356310767 is the
# slow kind: archive.apache.org took longer than ar2's five minutes to send apache/jena's
# asset. Run 45328924364 is Sigstore's kind: gh couldn't initialise the public-good verifier
# for wasm-tools' attestation, which says nothing about the attestation. Run 45538066425's
# darwin job is the unreachable kind: git fetch gave up on github.com after 75 seconds with
# "Couldn't connect to server". Run 45746973671's windows/amd64 job is the same kind on Windows:
# connecting to archive.apache.org for apache/ant timed out, which Windows words as "connectex:
# A connection attempt failed" and Linux as "connection timed out", while the run's other
# jobs downloaded the same asset. Run 45789813302's darwin job is the DNS kind: checkout
# failed with "Could not resolve host: github.com" while every other job of the run passed.
#
# A 403 is read as transient only where aqua-installer got it downloading aqua's own release
# asset, which is public: run 45144881274's skills job got it six times over 31 seconds while
# the run's other jobs downloaded the same asset, so it is GitHub refusing that machine for a
# while rather than anything the job did. A 403 anywhere else may well be a permission the job
# lacks, and is left alone. aqua-installer says "returned error: 403" where curl gives the
# error, and actionlint-action's installer says "Unexpected HTTP response: 403" (run
# 45529748432), so both spellings count.
#
# A cancelled job is read as transient when GitHub cancelled it for the machine rather than
# for the job: it hit timeout-minutes, or no runner took it. Run 44711883319's darwin job is
# the first kind -- one step recorded and nothing logged after it for thirty minutes, the
# runner gone quiet. A job a person cancelled says so instead, and is left alone.
#
# Every failed or cancelled job has to look transient, or nothing is re-run: a run with one
# real failure would fail again anyway. status-check-* jobs are left out, since they fail
# only because a job they need did.
set -euo pipefail

# What GitHub annotates a job with when it cancels it for the machine.
readonly MACHINE='exceeded the maximum execution time|not acquired by Runner'
readonly TRANSIENT='returned error: 5[0-9]{2}|HTTP[/ 0-9.]* 5[0-9]{2}|status code:? 5[0-9]{2}|50[234] (Bad Gateway|Service Unavailable|Gateway Time-?out)|connection reset by peer|TLS handshake timeout|i/o timeout|operation timed out|the download took longer than|public good verifier is not available|Couldn.t connect to server|connectex: A connection attempt failed|connection timed out|Could not resolve host'
readonly AQUA_DOWNLOAD='Downloading https://github\.com/aquaproj/aqua/releases/download/'
readonly FORBIDDEN='returned error: 403|Unexpected HTTP response: 403'

jobs=$(gh run view "$RUN_ID" --attempt "$RUN_ATTEMPT" --json jobs \
	--jq '.jobs[] | select(.conclusion == "failure" or .conclusion == "cancelled") | select(.name | startswith("status-check") | not) | "\(.databaseId) \(.conclusion)"')
if [ -z "$jobs" ]; then
	echo "run $RUN_ID has no failed or cancelled job to look at" >&2
	exit 0
fi

while read -r job conclusion; do
	if [ "$conclusion" = cancelled ]; then
		annotations=$(gh api "repos/$GH_REPO/check-runs/$job/annotations" --jq '.[].message')
		if ! grep -Eiq -- "$MACHINE" <<<"$annotations"; then
			echo "job $job of run $RUN_ID was cancelled, not by a timeout or for want of a runner; not re-running" >&2
			exit 0
		fi
		continue
	fi
	log=$(gh run view "$RUN_ID" --job "$job" --log-failed)
	if grep -Eiq -- "$TRANSIENT" <<<"$log"; then
		continue
	fi
	if grep -Eq -- "$AQUA_DOWNLOAD" <<<"$log" && grep -Eq -- "$FORBIDDEN" <<<"$log"; then
		continue
	fi
	echo "job $job of run $RUN_ID failed for a reason that doesn't look transient; not re-running" >&2
	exit 0
done <<<"$jobs"

# A moment's wait, so a server that was down a moment ago has had the moment.
sleep 60
echo "re-running the failed jobs of run $RUN_ID (attempt $RUN_ATTEMPT)" >&2
gh run rerun "$RUN_ID" --failed
