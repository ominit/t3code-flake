#!/bin/sh
ci=false
if echo "$@" | grep -qoE '(--ci)'; then
  ci=true
fi

only_check=false
if echo "$@" | grep -qoE '(--only-check)'; then
  only_check=true
fi

remote_latest=$(curl 'https://api.github.com/repos/pingdotgg/t3code/releases/latest' -s)

get_version() {
  echo "$remote_latest" | jq -r '.tag_name | ltrimstr("v")'
}

commit_targets=""
commit_version=""

update_version() {
  # "x86_64" or "aarch64"
  arch=$1
  # "linux" or "darwin"
  os=$2

  meta=$(jq ".[\"$arch-$os\"]" <sources.json)

  local=$(echo "$meta" | jq -r '.version')
  remote=$(get_version)

  echo "Checking t3code @ $arch... local=$local remote=$remote"

  if [ "$local" = "$remote" ]; then
    echo "Local version is up to date"
    return
  fi

  echo "Local version mismatch with remote so we* assume it's outdated"

  if $only_check; then
    echo "should_update=true" >>"$GITHUB_OUTPUT"
    exit 0
  fi

  if [ "$arch" != "x86_64" ] || [ "$os" != "linux" ]; then
    echo "Unsupported target: $arch-$os" >&2
    exit 1
  fi

  appimage_download_url=$(echo "$remote_latest" | jq -r --arg version "$remote" '.assets[] | select(.name == ("T3-Code-" + $version + "-x86_64.AppImage")) | .browser_download_url')
  if [ -z "$appimage_download_url" ] || [ "$appimage_download_url" = "null" ]; then
    echo "Unable to find Linux AppImage asset for t3code $remote" >&2
    exit 1
  fi

  prefetch_output=$(nix store prefetch-file --hash-type sha256 --json "$appimage_download_url")
  appimage_sha256=$(echo "$prefetch_output" | jq -r '.hash')

  jq ".[\"$arch-$os\"] = {\"version\":\"$remote\",\"appimage_url\":\"$appimage_download_url\",\"appimage_sha256\":\"$appimage_sha256\"}" <sources.json >sources.json.tmp
  mv sources.json.tmp sources.json

  if ! $ci; then
    return
  fi

  if [ "$commit_targets" = "" ]; then
    commit_targets="$arch"
    commit_version="$remote"
  else
    commit_targets="$commit_targets && $arch"
  fi
}

main() {
  set -e

  update_version "x86_64" "linux"

  if $only_check && $ci; then
    echo "should_update=false" >>"$GITHUB_OUTPUT"
  fi

  # Check if there are changes
  if ! git diff --exit-code >/dev/null; then
    # Prepare commit message
    init_message="update:"
    message="$init_message"

    message="$message t3code @ $commit_targets to $commit_version"

    echo "commit_message=$message" >>"$GITHUB_OUTPUT"
  fi
}

main
