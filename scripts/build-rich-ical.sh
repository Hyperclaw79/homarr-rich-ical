#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
registry="ghcr.io"
registry_owner="hyperclaw79"
image_name="homarr"
tag_suffix="rich-ical"
platform="linux/amd64"
homarr_version=""
work_root="$repo_root/work"
output_mode="load"

usage() {
  cat <<'EOF'
Usage: scripts/build-rich-ical.sh --homarr-version VERSION [options]
  --registry HOST          Registry host (default: ghcr.io)
  --registry-owner OWNER   Registry package owner (default: hyperclaw79)
  --image-name NAME        Image package name (default: homarr)
  --tag-suffix SUFFIX      Image tag suffix (default: rich-ical)
  --platform PLATFORM      Build platform (default: linux/amd64)
  --workdir DIR            Disposable work root (default: ./work)
  --push                    Push the exact version tag
  --load                    Load the exact version tag locally (default)
EOF
}

while (($#)); do
  case "$1" in
    --homarr-version) homarr_version="${2:?Missing value for --homarr-version}"; shift 2 ;;
    --registry) registry="${2:?Missing value for --registry}"; shift 2 ;;
    --registry-owner) registry_owner="${2:?Missing value for --registry-owner}"; shift 2 ;;
    --image-name) image_name="${2:?Missing value for --image-name}"; shift 2 ;;
    --tag-suffix) tag_suffix="${2:?Missing value for --tag-suffix}"; shift 2 ;;
    --platform) platform="${2:?Missing value for --platform}"; shift 2 ;;
    --workdir) work_root="${2:?Missing value for --workdir}"; shift 2 ;;
    --push) output_mode="push"; shift ;;
    --load) output_mode="load"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

for command in git docker; do
  command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 1; }
done

clean_version="${homarr_version#v}"
if [[ ! "$clean_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][A-Za-z0-9._-]+)?$ ]]; then
  echo "--homarr-version must be a valid version (for example 1.71.0 or v1.71.0)." >&2
  exit 2
fi

if [[ ! "$tag_suffix" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "--tag-suffix contains invalid characters." >&2
  exit 2
fi

if [[ "${REQUIRE_SEANIME_ICON_URL:-false}" == "true" && -z "${SEANIME_ICON_URL:-}" ]]; then
  echo "SEANIME_ICON_URL is required for a published build." >&2
  exit 1
fi
icon_url="${SEANIME_ICON_URL:-https://example.invalid/seanime-icon}"
if [[ ! "$icon_url" =~ ^https?://[^[:space:]\"]+$ ]]; then
  echo "SEANIME_ICON_URL must be an HTTP(S) URL without whitespace or quotes." >&2
  exit 1
fi

upstream_tag="v$clean_version"
image_base="$registry/$registry_owner/$image_name"
image_ref="$image_base:$clean_version-$tag_suffix"
moving_tag="$image_base:$tag_suffix"
source_dir="$work_root/homarr-$clean_version"
upstream_file="$source_dir/packages/integrations/src/ical/ical-integration.ts"
patch_source="$repo_root/patches/ical-integration.rich.ts"
artifact_dir="$repo_root/artifacts"
patch_diff="$artifact_dir/homarr-rich-ical.patch.diff"

[[ -f "$patch_source" ]] || { echo "Patch source not found: $patch_source" >&2; exit 1; }
placeholder_count="$(grep -Foc -- '__SEANIME_ICON_URL__' "$patch_source" || true)"
[[ "$placeholder_count" == "1" ]] || {
  echo "Patch source must contain exactly one icon URL placeholder; found $placeholder_count." >&2
  exit 1
}

mkdir -p "$work_root" "$artifact_dir"
rm -rf -- "$source_dir"

echo "Cloning Homarr $upstream_tag"
git clone --depth 1 --branch "$upstream_tag" https://github.com/homarr-labs/homarr.git "$source_dir"
[[ -f "$upstream_file" ]] || {
  echo "Upstream iCal adapter path changed or is missing: $upstream_file" >&2
  exit 1
}

cp -- "$patch_source" "$upstream_file"

# Preserve a public, redacted build artifact before injecting the secret URL.
git -C "$source_dir" diff --stat
git -C "$source_dir" diff > "$patch_diff"
[[ -s "$patch_diff" ]] || { echo "Patch produced no diff; refusing an ambiguous build." >&2; exit 1; }

temporary_file="$(mktemp "${upstream_file}.XXXXXX")"
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" == *'__SEANIME_ICON_URL__'* ]]; then
    printf '%s\n' "${line/__SEANIME_ICON_URL__/$icon_url}"
  else
    printf '%s\n' "$line"
  fi
done < "$upstream_file" > "$temporary_file"
chmod --reference="$upstream_file" "$temporary_file"
mv -- "$temporary_file" "$upstream_file"

echo "Patched: packages/integrations/src/ical/ical-integration.ts"
echo "Redacted diff: $patch_diff"
echo "Building: $image_ref"

build_args=(
  --platform "$platform"
  --pull
  --tag "$image_ref"
)

if [[ -n "${BUILDX_CACHE_FROM:-}" ]]; then
  build_args+=(--cache-from "$BUILDX_CACHE_FROM")
fi
if [[ -n "${BUILDX_CACHE_TO:-}" ]]; then
  build_args+=(--cache-to "$BUILDX_CACHE_TO")
fi

build_args+=("--$output_mode")
docker buildx build "${build_args[@]}" "$source_dir"

printf 'IMAGE_REF=%s\n' "$image_ref"
printf 'UPSTREAM_TAG=%s\n' "$upstream_tag"
printf 'CLEAN_VERSION=%s\n' "$clean_version"
printf 'MOVING_TAG=%s\n' "$moving_tag"

