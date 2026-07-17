#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
version="${1:-}"

if [[ "$version" == "--latest" ]]; then
  version=""
  prefer_file="false"
else
  prefer_file="true"
fi

if [[ -z "$version" && "$prefer_file" == "true" && -f "$repo_root/HOMARR_VERSION" ]]; then
  version="$(tr -d '[:space:]' < "$repo_root/HOMARR_VERSION")"
fi

if [[ -z "$version" ]]; then
  version="$({
    curl --fail --silent --show-error --location \
      --header 'Accept: application/vnd.github+json' \
      --header 'User-Agent: homarr-rich-ical-version-resolver' \
      https://api.github.com/repos/homarr-labs/homarr/releases/latest
  } | sed -nE 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/p' | head -n1)"
fi

version="${version#v}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][A-Za-z0-9._-]+)?$ ]]; then
  echo "Could not resolve a valid Homarr version (got: ${version:-empty})." >&2
  exit 1
fi

printf '%s\n' "$version"

