#!/usr/bin/env bash
# Check the pull request that moves every package from its branch onto the default branch.
#
# It is thousands of files, and every one of them was checked when it arrived on its branch.
# What has to be true is that the move changed nothing: that each package's directory holds
# the very objects its branch holds -- the same sha, so the same bytes -- and that nothing
# else changed. That is read from the trees, which costs no download of any file.
set -euo pipefail

failed=0
fail() {
	echo "::error::$1"
	failed=1
}

git init -q verify
cd verify
git remote add origin "https://github.com/$GITHUB_REPOSITORY"
# Trees only: a sha is what is compared, and a tree names the sha of everything in it.
git fetch -q --filter=blob:none origin \
	"+refs/heads/pkg_*:refs/remotes/origin/pkg_*" "$BASE_SHA" "$HEAD_SHA"

outside=$(git diff --name-only "$BASE_SHA" "$HEAD_SHA" | grep -v '^pkgs/' || true)
if [ -n "$outside" ]; then
	fail "the pull request changes files outside pkgs/: $outside"
fi

branches=0
while read -r ref; do
	id=${ref#refs/remotes/origin/pkg_}
	branches=$((branches + 1))
	dir="pkgs/${id: -2}/$id"
	for name in registry.yaml versions.json versions; do
		want=$(git rev-parse -q --verify "$ref:$name" || true)
		got=$(git rev-parse -q --verify "$HEAD_SHA:$dir/$name" || true)
		if [ "$want" != "$got" ]; then
			fail "$dir/$name is ${got:-missing} where pkg_$id holds ${want:-nothing}"
		fi
	done
done < <(git for-each-ref --format='%(refname)' 'refs/remotes/origin/pkg_*')

# Nothing under pkgs/ that no branch accounts for.
dirs=$(git ls-tree -d --name-only "$HEAD_SHA" pkgs/ | while read -r shard; do
	git ls-tree -d --name-only "$HEAD_SHA" "$shard/"
done | wc -l | tr -d ' ')
if [ "$dirs" != "$branches" ]; then
	fail "pkgs/ holds $dirs package directories for $branches package branches"
fi

echo "Compared $branches package branches with their directories." >> "$GITHUB_STEP_SUMMARY"
exit "$failed"
