#!/usr/bin/env bash
set -euo pipefail

repo=pingdotgg/t3code
sources=sources.json

declare -A assets=(
  [x86_64-linux]=x86_64.AppImage
)

changes=()

update_channel() {
  channel=$1
  release=$2

  if ! version=$(jq -er '.tag_name | ltrimstr("v")' <<<"$release"); then
    echo "No $channel release found" >&2
    exit 1
  fi
  echo "$channel: $version"

  for system in "${!assets[@]}"; do
    name="T3-Code-$version-${assets[$system]}"
    filter='.assets[] | select(.name == $name and .digest != null) | {version: $version, url: .browser_download_url, hash: .digest}'
    if ! source=$(jq -ec --arg name "$name" --arg version "$version" "$filter" <<<"$release"); then
      if jq -e 'now - (.published_at | fromdateiso8601) < 3600' <<<"$release" >/dev/null; then
        echo "$name is not uploaded yet, skipping $channel"
        return
      fi
      echo "No $name asset with a digest in the $channel release" >&2
      exit 1
    fi

    if [ "$(jq -c --arg c "$channel" --arg s "$system" '.[$c][$s]' "$sources")" = "$source" ]; then
      continue
    fi

    jq --arg c "$channel" --arg s "$system" --argjson source "$source" '.[$c][$s] = $source' "$sources" >"$sources.tmp"
    mv "$sources.tmp" "$sources"
    changes+=("$channel to $version")
  done
}

cd "$(dirname "$0")/.."

stable=$(gh api "repos/$repo/releases/latest")
nightly=$(gh api "repos/$repo/releases?per_page=30" --jq 'first(.[] | select(.prerelease and (.tag_name | contains("-nightly."))))')

update_channel stable "$stable"
update_channel nightly "$nightly"

if [ ${#changes[@]} -eq 0 ]; then
  echo "Up to date"
  exit 0
fi

message="update: t3code $(printf '%s\n' "${changes[@]}" | awk '!seen[$0]++' | paste -sd, - | sed 's/,/, /g')"
echo "$message"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "commit_message=$message" >>"$GITHUB_OUTPUT"
fi
