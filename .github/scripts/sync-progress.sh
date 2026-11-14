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
digest=$(curl -sSf -H "Authorization: Bearer $token" \
	-H "Accept: application/vnd.oci.image.manifest.v1+json" \
	"https://$registry/v2/$repository/manifests/latest" |
	jq -r '.layers[] | select(.mediaType == "application/vnd.ar2.state.v1+json") | .digest')
curl -sSfL -H "Authorization: Bearer $token" "https://$registry/v2/$repository/blobs/$digest" -o state.json

read -r total walked complete updated < <(jq -r '[
	(.packages | length),
	([.packages[] | select(.last_deep_check != null)] | length),
	([.packages[] | select(.last_deep_check != null and .caught_up == true)] | length),
	.updated_at
] | @tsv' state.json)

published=$(git ls-tree -r --name-only HEAD pkgs | grep -c '/versions\.json$')
versions=$(git ls-tree -r --name-only HEAD pkgs | grep -c '/registry-[0-9]*\.json$')

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

$versions versions published. State written at $updated, main at $(git rev-parse --short HEAD).
BODY
)

gh issue comment "$ISSUE" --repo "$GH_REPO" --body "$body"
