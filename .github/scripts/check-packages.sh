#!/usr/bin/env bash
# Check what a pull request does to the package directories it touches, once they are
# checked out, and say which definitions are templates to install.
#
# For every package:
#
# - a definition deleted while what it served is left beside it: versions/, versions.json
#   or template-1.json. aqua reaches those by the package's id whatever the definition
#   says, and nothing would take them away once it is gone, since ar2 works from the
#   definitions it finds. `ar2 remove` takes them away first; the definition can go after;
# - a new package directory whose id, name or alias the registry already holds. aqua would
#   go on reading the package it already had, and the catalogue would list the older
#   directory and nothing from the new one. names.json is what the last catalogue's pull
#   request wrote, so two pull requests adding the same name, both merged before the
#   catalogue catches up, aren't caught here.
#
# For a package served as a template, which declares `template:` in its registry.yaml and
# has template-1.json rendered from it in the catalogue's pull request. aqua reads that
# file as it is, for every version, so what is refused is what would let a version reach it
# that the registry didn't mean to serve that way:
#
# - a template package with versions/ or versions.json beside it, which would serve some
#   versions generated and the rest from the template;
# - a definition that stops being a template. Taking a package from a template to generated
#   versions isn't supported yet: its template would go before its versions arrive.
#
# Which packages are templates is read from the pull request's registry.yaml, not from
# whether template-1.json exists: that file arrives only after the definition merges.
#
# It writes the definitions to install to $GITHUB_OUTPUT as template_defs.
set -euo pipefail

failed=0
fail() {
	echo "::error::$1"
	failed=1
}

# Whether the definition on stdin declares a template, read as ar2 reads it.
is_template() {
	[ "$(yq '.template != null' -)" = true ]
}

# The package's name and the names of its aliases, from the definition on stdin.
names_of() {
	yq '.name, (.aliases // [] | .[].name) | select(. != null)' -
}

# The definition as the base branch has it, in $base, and whether the base has it at all.
# A request that fails for any other reason than the file not being there stops the check:
# taking it for a new package would pass a definition that stops being a template.
read_base() {
	local err
	err=$(mktemp)
	if base=$(gh api "repos/$GITHUB_REPOSITORY/contents/$1?ref=$BASE_SHA" -H "Accept: application/vnd.github.raw" 2>"$err"); then
		rm -f "$err"
		return 0
	fi
	if grep -q 'HTTP 404' "$err"; then
		rm -f "$err"
		base=
		return 1
	fi
	cat "$err" >&2
	rm -f "$err"
	echo "::error::couldn't read $1 as the base branch has it"
	exit 1
}

: > template_defs.txt
for dir in $PACKAGES; do
	def="$dir/registry.yaml"
	in_base=true
	read_base "$def" || in_base=false

	if [ ! -f "$def" ]; then
		for left in "$dir/versions" "$dir/versions.json" "$dir/template-1.json"; do
			if [ -e "$left" ]; then
				fail "$def is deleted, but $left is left and would go on being served: stop serving the package with ar2 remove first"
			fi
		done
		continue
	fi

	if $in_base && is_template <<<"$base" && ! is_template < "$def"; then
		fail "$def stops being a template, which isn't supported: its template-1.json would be removed before any version is generated"
	fi

	if is_template < "$def"; then
		if [ -e "$dir/versions" ] || [ -e "$dir/versions.json" ]; then
			fail "$def is a template, but the package has versions: a package is served either as a template or as generated versions"
		fi
		echo "$def" >> template_defs.txt
	fi

	if ! $in_base; then
		# A package directory the base doesn't have.
		id=$(basename "$dir")
		if jq -e --arg id "$id" '.ids | to_entries | any(.value == $id)' names.json >/dev/null; then
			fail "$dir: the id $id is already a package's"
		fi
		while read -r name; do
			if jq -e --arg name "$name" '(.ids | has($name)) or ((.aliases // {}) | has($name))' names.json >/dev/null; then
				fail "$def: the registry already holds $name, so aqua would go on reading that package rather than this one"
			fi
		done < <(names_of < "$def")
	fi
done

echo "template_defs=$(tr '\n' ' ' < template_defs.txt)" >> "$GITHUB_OUTPUT"
echo "template definitions:"
cat template_defs.txt
exit "$failed"
