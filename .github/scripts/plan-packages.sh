#!/usr/bin/env bash
# Work out which packages a pull request touches, and refuse what no pull request may do.
#
# Every package is a directory, pkgs/<last two digits of id>/<id>/, on the default branch.
# When each had a branch of its own, a pull request into it couldn't reach another package;
# here that is a check rather than a fact, and this is the check:
#
# - a path under pkgs/ is in the directory its id says;
# - a pull request ar2 opened for a package touches that package's directory and nothing
#   else, and one ar2 opened for anything else touches no package;
# - a registry-*.json already published is changed or removed only by a pull request a
#   person has labelled replaces-published, because a version the registry serves is
#   meant to stay what it was.
#
# It writes what the jobs after it need to $GITHUB_OUTPUT: the package directories, and the
# registry files to check.
set -euo pipefail

readonly REQUIRED_LABEL=replaces-published

failed=0
fail() {
	echo "::error::$1"
	failed=1
}

# The package an ar2 head branch is for: ar2_<id> or ar2_<id>_<version>. Any other ar2_
# branch -- the catalogue's, a removal's first half -- is for no package.
head_id=""
ar2_head=false
if [[ $HEAD_REF == ar2_* ]]; then
	ar2_head=true
	if [[ $HEAD_REF =~ ^ar2_([0-9]+)(_.*)?$ ]]; then
		head_id=${BASH_REMATCH[1]}
	fi
fi

# Whether a person labelled the pull request as replacing what is published. The label is
# read from who put it there, not only from its being there: ar2 labels its own pull
# requests, and a label it could put on itself would decide nothing.
replaces=false
labeller=$(gh api "repos/$GITHUB_REPOSITORY/issues/$NUMBER/events" --paginate \
	--jq ".[] | select(.event == \"labeled\" and .label.name == \"$REQUIRED_LABEL\") | .actor.type" | tail -n 1)
if [ "$labeller" = User ] && jq -e --arg l "$REQUIRED_LABEL" 'index($l)' <<< "$LABELS" > /dev/null; then
	replaces=true
fi

# The pull request rewriting every published file in the form a generation writes now is
# checked by deriving it again from its base (ar2 rewrite --verify, in wc_packages.yaml),
# rather than by downloading every asset a second time. Nothing about a release changes in
# it, so there is nothing for these checks to add.
#
# It replaces every published file all the same, so it waits for the label like any other.
if [ "$HEAD_REF" = ar2_rewrite ]; then
	if ! $replaces; then
		fail "this pull request rewrites every published file. A person labels it $REQUIRED_LABEL to allow that."
	fi
	echo "The pull request that rewrites the published files is checked by ar2 rewrite --verify." >> "$GITHUB_STEP_SUMMARY"
	{
		echo "packages="
		echo "files="
		echo "count=0"
	} >> "$GITHUB_OUTPUT"
	exit "$failed"
fi

gh api "repos/$GITHUB_REPOSITORY/pulls/$NUMBER/files" --paginate \
	--jq '.[] | [.status, .filename, (.previous_filename // "")] | @tsv' > changes.tsv

: > packages.txt
: > files.txt
while IFS=$'\t' read -r status file previous; do
	for path in "$file" ${previous:+"$previous"}; do
		if [[ $path != pkgs/* ]]; then
			if [ -n "$head_id" ]; then
				fail "$path is outside the directory of the package this pull request is for"
			fi
			continue
		fi
		if [[ ! $path =~ ^pkgs/([0-9]{2})/([0-9]+)/ ]]; then
			fail "$path is under pkgs/ but not in a package's directory"
			continue
		fi
		shard=${BASH_REMATCH[1]}
		id=${BASH_REMATCH[2]}
		if [ "${id: -2}" != "$shard" ]; then
			fail "$path is in shard $shard, but the id $id belongs in ${id: -2}"
			continue
		fi
		if $ar2_head && [ "$id" != "$head_id" ]; then
			fail "$path belongs to a package this pull request isn't for"
		fi
		echo "pkgs/$shard/$id" >> packages.txt
	done
	if [[ $file =~ ^pkgs/[0-9]{2}/[0-9]+/versions/[^/]+/registry-[0-9]+\.json$ ]]; then
		case $status in
		added)
			echo "$file" >> files.txt
			;;
		*)
			if ! $replaces; then
				fail "$file is published and this pull request would change it ($status). A person labels the pull request $REQUIRED_LABEL to allow that."
			fi
			if [ "$status" != removed ]; then
				echo "$file" >> files.txt
			fi
			;;
		esac
	fi
done < changes.tsv

sort -u -o packages.txt packages.txt
{
	echo "packages=$(tr '\n' ' ' < packages.txt)"
	echo "files=$(tr '\n' ' ' < files.txt)"
	echo "count=$(wc -l < files.txt | tr -d ' ')"
} >> "$GITHUB_OUTPUT"
echo "packages:"
cat packages.txt
echo "files:"
cat files.txt
exit "$failed"
