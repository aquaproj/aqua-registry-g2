#!/usr/bin/env bash
# Comment on the progress issue how far the registry has got in taking over aqua-registry.
#
# - Packages: of the packages in ar2's order, how many have a version published here, which
#   is a pkgs/<shard>/<id>/versions.json on main.
# - Backfill: how many have had their whole history walked (last_deep_check), since a sweep
#   only sees the newest releases; and of those, how many also hold every version the last
#   sweep saw (caught_up).
#
# The state is the JSON layer of the artifact ar2 keeps in the container registry, read
# with the registry's own API rather than GitHub's.
set -euo pipefail

registry=ghcr.io
repository=$GH_REPO

token=$(curl -sSf -u "x:$GH_TOKEN" "https://$registry/token?scope=repository:$repository:pull" | jq -r .token)
manifest=$(curl -sSf -H "Authorization: Bearer $token" \
	-H "Accept: application/vnd.oci.image.manifest.v1+json" \
	"https://$registry/v2/$repository/manifests/latest")
digest=$(jq -r '.layers[] | select(.mediaType == "application/vnd.ar2.state.v1+json") | .digest' <<<"$manifest")
# When the state was last pushed. The state's own updated_at changes only when ar2 adds the
# packages aqua-registry gained, so it said a state pushed by every run was a day old.
saved=$(jq -r '.annotations["org.opencontainers.image.created"] // "unknown"' <<<"$manifest")
curl -sSfL -H "Authorization: Bearer $token" "https://$registry/v2/$repository/blobs/$digest" -o state.json

# A package served as a template has no version to generate, so it is in none of the rows
# but its own: counted among the packages, it would keep every share short of 100%.
read -r total walked complete templates < <(jq -r '
	[.packages[] | select(.template != true)] as $generated | [
	($generated | length),
	([$generated[] | select(.last_deep_check != null)] | length),
	([$generated[] | select(.last_deep_check != null and .caught_up == true)] | length),
	([.packages[] | select(.template == true)] | length)
] | @tsv' state.json)

published=$(git ls-tree -r --name-only HEAD pkgs | grep -c '/versions\.json$')
versions=$(git ls-tree -r --name-only HEAD pkgs | grep -c '/registry-[0-9]*\.json$')

# The last report's counts, so that this one can say how far the registry got since: the
# share of packages moves slowly while a lap is spent on history, and the versions are where
# the progress shows.
last=$(gh api --paginate "repos/$GH_REPO/issues/$ISSUE/comments?per_page=100" --jq '.[].body' |
	grep -E '^[0-9]+ versions published' | tail -n 1 || true)
last_versions=$(sed -E 's/^([0-9]+) versions published.*/\1/' <<<"$last")

since() {
	if [ -z "$2" ]; then
		return
	fi
	printf ' (%+d since the last report)' "$(($1 - $2))"
}

percent() {
	awk -v n="$1" -v d="$2" 'BEGIN { if (d == 0) print "0.0"; else printf "%.1f", 100 * n / d }'
}

body=$(cat <<BODY
## $(date -u +%Y-%m-%d)

| | | |
|---|---:|---:|
| Packages with a version published | $published / $total | $(percent "$published" "$total")% |
| Packages whose history was walked | $walked / $total | $(percent "$walked" "$total")% |
| Walked and holding every version swept | $complete / $total | $(percent "$complete" "$total")% |
| Packages served as templates | $templates | |

$versions versions published$(since "$versions" "$last_versions"). State saved at $saved, main at $(git rev-parse --short HEAD).
BODY
)

gh issue comment "$ISSUE" --repo "$GH_REPO" --body "$body"
