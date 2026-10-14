#!/usr/bin/env bash
# Work out which packages a pull request touches, and refuse what no pull request may do.
#
# Every package is a directory, pkgs/<last two digits of id>/<id>/, on the default branch.
# When each had a branch of its own, a pull request into it couldn't reach another package;
# here that is a check rather than a fact, and this is the check:
#
# - a path under pkgs/ is in the directory its id says;
# - a pull request ar2 opened for a package touches that package's directory and nothing
#   else, the one bringing the lists of versions up to date touches nothing but those lists,
#   and one ar2 opened for anything else touches no package;
# - a registry-*.json already published is changed or removed only by a pull request that
#   isn't set to merge itself, because a version the registry serves is meant to stay what
#   it was, and a person merging the pull request is what says the change was read and is
#   meant. ar2 labels such a pull request replaces-published for whoever reads the list.
#
# It writes what the jobs after it need to $GITHUB_OUTPUT: the package directories, and the
# registry files to check.
set -euo pipefail


failed=0
fail() {
	echo "::error::$1"
	failed=1
}

# The package an ar2 head branch is for: ar2_<id>, ar2_<id>_<version>, or
# ar2_<id>__needs-definition. Any other ar2_ branch -- the catalogue's, a removal's first
# half -- is for no package, except ar2_versions, which brings the lists of versions of any
# package up to date (ar2 update-versions) and may touch those lists and nothing else.
head_id=""
ar2_head=false
lists_only=false
if [[ $HEAD_REF == ar2_* ]]; then
	ar2_head=true
	if [[ $HEAD_REF =~ ^ar2_([0-9]+)(_.*)?$ ]]; then
		head_id=${BASH_REMATCH[1]}
	fi
fi
if [ "$HEAD_REF" = ar2_versions ]; then
	ar2_head=false
	lists_only=true
fi

# Whether the pull request is set to merge itself. One that replaces what is published may
# not be: merging it is a person's decision. test.yaml runs again when auto-merge is turned on
# or off, so turning it on after the checks passed fails them again.
auto_merge=$(gh api "repos/$GITHUB_REPOSITORY/pulls/$NUMBER" --jq '.auto_merge != null')

# The pull request rewriting every published file in the form a generation writes now is
# checked by deriving it again from its base (ar2 rewrite --verify, in wc_packages.yaml),
# rather than by downloading every asset a second time. Nothing about a release changes in
# it, so there is nothing for these checks to add.
#
# It replaces every published file all the same, so a person merges it like any other.
if [ "$HEAD_REF" = ar2_rewrite ]; then
	if $auto_merge; then
		fail "this pull request rewrites every published file, so it may not merge itself. Turn auto-merge off, read it, and merge it."
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
		if $lists_only && [[ ! $path =~ ^pkgs/[0-9]{2}/[0-9]+/versions\.json$ ]]; then
			fail "$path isn't a list of versions, which is all this pull request may touch"
			continue
		fi
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
			if $auto_merge; then
				fail "$file is published and this pull request would change it ($status), so it may not merge itself. Turn auto-merge off, read it, and merge it."
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
