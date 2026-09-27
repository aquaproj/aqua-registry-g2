#!/usr/bin/env bash
# Check every skill in skills/ before a session has to read it.
#
# A skill whose front matter doesn't parse is not a skill that loads with a warning: it
# doesn't load at all, and nothing says so until somebody asks for it. What breaks it is
# ordinary prose -- a colon and a space inside the description reads as a mapping, so one
# sentence turns the whole block into something YAML won't have.
#
# 'claude plugin validate' is not this check. It validates a plugin, and a bare tree of
# skill directories holds no manifest for it to find, so it reports that nothing was wrong.
set -euo pipefail

# What Claude Code accepts. The name is a directory name and an identifier both, and the
# description is what a session matches a request against, so a long one is a slow one.
readonly NAME_PATTERN='^[a-z0-9-]+$'
readonly DESCRIPTION_MAX=1024

failed=0

fail() {
	echo "::error file=$1::$2"
	failed=1
}

check() {
	local file="$1" dir name description
	dir=$(basename "$(dirname "$file")")

	# yq reads the front matter as YAML and says where it stopped when it can't, which is
	# the whole of what this is for. Everything after it is about what the values say.
	if ! name=$(yq --front-matter=extract --exit-status '.name' "$file" 2>&1); then
		fail "$file" "the front matter isn't readable as YAML: $name"
		return
	fi
	if ! description=$(yq --front-matter=extract --exit-status '.description' "$file" 2>&1); then
		fail "$file" "no description: it is what a session matches a request against"
		return
	fi

	if [ "$name" != "$dir" ]; then
		fail "$file" "the name is '$name' and the directory is '$dir'; a session finds the skill by the directory"
	fi
	if ! [[ $name =~ $NAME_PATTERN ]]; then
		fail "$file" "the name '$name' has something other than lowercase letters, digits and hyphens in it"
	fi
	if [ "${#description}" -gt "$DESCRIPTION_MAX" ]; then
		fail "$file" "the description is ${#description} characters, and the limit is $DESCRIPTION_MAX"
	fi

	# The symlink is how a session finds the skill at all: the skills live here so that a
	# person can read them, and .claude/skills is what is scanned.
	if [ ! -L ".claude/skills/$dir" ]; then
		fail "$file" "there is no .claude/skills/$dir symlink, so nothing loads this skill"
	fi
}

main() {
	shopt -s nullglob
	local files=(skills/*/SKILL.md)
	if [ ${#files[@]} -eq 0 ]; then
		echo "no skills found under skills/, which is not what this repository looks like"
		exit 1
	fi
	for file in "${files[@]}"; do
		check "$file"
	done
	if [ "$failed" -ne 0 ]; then
		exit 1
	fi
	echo "${#files[@]} skills checked"
}

main
