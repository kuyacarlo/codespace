#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
  echo "GITHUB_REPOSITORY is required" >&2
  exit 1
fi

if [[ -z "${GITHUB_SHA:-}" ]]; then
  echo "GITHUB_SHA is required" >&2
  exit 1
fi

ref_name="${GITHUB_REF_NAME:-}"
if [[ -z "$ref_name" ]]; then
  ref_name="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
fi

sha5="$(printf '%s' "$GITHUB_SHA" | cut -c1-5)"
image="ghcr.io/${GITHUB_REPOSITORY,,}"

sanitize_branch() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's#[^a-z0-9._-]+#-#g; s#^-+##; s#-+$##'
}

if [[ "$ref_name" == "main" ]]; then
  tags=("latest" "$sha5")
else
  branch_tag="$(sanitize_branch "$ref_name")"
  if [[ -z "$branch_tag" ]]; then
    branch_tag="branch"
  fi
  tags=("$branch_tag" "$sha5")
fi

for tag in "${tags[@]}"; do
  echo "${image}:${tag}"
done
