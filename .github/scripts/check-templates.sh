#!/usr/bin/env bash
# Check what a pull request does to packages served as templates, once the directories it
# touches are checked out, and say which definitions are templates to install.
#
# A package served as a template declares `template:` in its registry.yaml, and ar2 renders
# template-1.json from it in the catalogue's pull request. aqua reads that file as it is,
# for every version, so what is refused here is what would let a version reach it that the
# registry didn't mean to serve that way:
#
# - a template package with versions/ or versions.json beside it, which would serve some
#   versions generated and the rest from the template;
# - a definition that stops being a template. Taking a package from a template to generated
#   versions isn't supported yet: its template would go before its versions arrive;
# - a template package's definition deleted. ar2 renders and removes templates from the
#   definitions it finds, so its template-1.json would stay for good. `ar2 remove` is how a
#   package stops being served;
# - a new package directory whose id, name or alias the registry already holds. aqua would
#   go on reading the package it already had, and the new template would never be read.
#   names.json is what the last catalogue's pull request wrote, so two pull requests adding
#   the same name, both merged before the catalogue catches up, aren't caught here: the
#   catalogue then lists the older directory and renders nothing for the newer.
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
		if $in_base && is_template <<<"$base"; then
			fail "$def is a template package's definition, and deleting it would leave its template-1.json served for good: stop serving the package with ar2 remove"
		fi
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
