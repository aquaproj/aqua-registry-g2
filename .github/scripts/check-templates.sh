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
# - a new package directory whose id, name or alias the registry already holds. aqua would
#   go on reading the package it already had, and the new template would never be read.
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

is_template() {
	grep -q '^template:' "$1"
}

# The package's name and aliases as the definition writes them: top-level name, and the
# name of each entry under aliases.
names_of() {
	awk '
		/^name:/ { sub(/^name:[ \t]*/, ""); gsub(/["\047]/, ""); print; next }
		/^aliases:/ { in_aliases = 1; next }
		/^[^ \t-]/ { in_aliases = 0 }
		in_aliases && /name:/ { sub(/.*name:[ \t]*/, ""); gsub(/["\047]/, ""); print }
	' "$1"
}

: > template_defs.txt
for dir in $PACKAGES; do
	def="$dir/registry.yaml"
	if [ ! -f "$def" ]; then
		continue
	fi
	base=$(gh api "repos/$GITHUB_REPOSITORY/contents/$def?ref=$BASE_SHA" -H "Accept: application/vnd.github.raw" 2>/dev/null || true)

	if [ -n "$base" ] && grep -q '^template:' <<<"$base" && ! is_template "$def"; then
		fail "$def stops being a template, which isn't supported: its template-1.json would be removed before any version is generated"
	fi

	if is_template "$def"; then
		if [ -e "$dir/versions" ] || [ -e "$dir/versions.json" ]; then
			fail "$def is a template, but the package has versions: a package is served either as a template or as generated versions"
		fi
		echo "$def" >> template_defs.txt
	fi

	if [ -z "$base" ]; then
		# A package directory the base doesn't have.
		id=$(basename "$dir")
		if jq -e --arg id "$id" '.ids | to_entries | any(.value == $id)' names.json >/dev/null; then
			fail "$dir: the id $id is already a package's"
		fi
		while read -r name; do
			if [ -z "$name" ]; then
				continue
			fi
			if jq -e --arg name "$name" '(.ids | has($name)) or ((.aliases // {}) | has($name))' names.json >/dev/null; then
				fail "$def: the registry already holds $name, so aqua would go on reading that package rather than this one"
			fi
		done < <(names_of "$def")
	fi
done

echo "template_defs=$(tr '\n' ' ' < template_defs.txt)" >> "$GITHUB_OUTPUT"
echo "template definitions:"
cat template_defs.txt
exit "$failed"
