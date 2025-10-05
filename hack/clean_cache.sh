#!/bin/bash

set -e

cd "$(dirname "$(realpath "$0")")"/..

repo="${1:-quay.io/solacelost/bootc-image/cache}"

tags=$(skopeo list-tags --authfile tmp/auth.json docker://$repo | jq -r .Tags[])
now=$(date +%s)
for tag in $tags; do
  created=$(skopeo inspect --authfile tmp/auth.json docker://$repo:$tag | jq -r .Created)
  created_seconds=$(date -d "$created" +%s)
  age_days=$(( (now - created_seconds) / (60 * 60 * 24) ))
  if (( age_days > 1 )); then
    echo "Deleting $tag, created $created"
    set -x
    skopeo delete --authfile tmp/auth.json docker://$repo:$tag
    { set +x ; } 2>/dev/null
  else
    echo "Not deleting $tag, created $created"
  fi
done
