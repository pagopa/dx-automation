#!/usr/bin/env bash

set -euo pipefail

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "::error::Missing required command: ${command_name}" >&2
    exit 1
  fi
}

validate_positive_integer() {
  local value="$1"
  local name="$2"

  if ! [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "::error::${name} must be a positive integer. Received: ${value}" >&2
    exit 1
  fi
}

require_command base64
require_command gh
require_command git

: "${APP_SLUG:?APP_SLUG is required}"
: "${FIXED_TAG_NAME:?FIXED_TAG_NAME is required}"
: "${FIXED_TAG_POSITION:?FIXED_TAG_POSITION is required}"
: "${GITHUB_APP_TOKEN:?GITHUB_APP_TOKEN is required}"
: "${TAG_COUNT:?TAG_COUNT is required}"
: "${TARGET_REF:?TARGET_REF is required}"

validate_positive_integer "$TAG_COUNT" "tag-count"
validate_positive_integer "$FIXED_TAG_POSITION" "fixed-tag-position"

if (( FIXED_TAG_POSITION > TAG_COUNT )); then
  echo "::error::fixed-tag-position must be between 1 and tag-count." >&2
  exit 1
fi

if [[ "$FIXED_TAG_NAME" =~ [[:space:]] ]]; then
  echo "::error::fixed-tag-name cannot contain whitespace." >&2
  exit 1
fi

target_commit="$(git rev-parse "${TARGET_REF}^{commit}")"
bot_login="${APP_SLUG}[bot]"
bot_user_id="$(gh api "/users/${bot_login}" --jq .id)"
server_host="${GITHUB_SERVER_URL#https://}"
basic_auth="$(printf 'x-access-token:%s' "$GITHUB_APP_TOKEN" | base64 | tr -d '\n')"
version_minor="${GITHUB_RUN_NUMBER:-0}"
version_patch_base="$(( (${GITHUB_RUN_ATTEMPT:-1} * 1000) + 100 ))"

git config user.name "$bot_login"
git config user.email "${bot_user_id}+${bot_login}@users.noreply.github.com"

random_prefix() {
  tr -dc 'a-z0-9' </dev/urandom | head -c 10
}

tag_exists_locally() {
  local tag="$1"
  git rev-parse -q --verify "refs/tags/${tag}" >/dev/null 2>&1
}

tag_exists_on_remote() {
  local tag="$1"
  git ls-remote --exit-code --tags origin "refs/tags/${tag}" >/dev/null 2>&1
}

push_tag() {
  local tag="$1"

  git -c "http.https://${server_host}/.extraheader=AUTHORIZATION: basic ${basic_auth}" \
    push origin "refs/tags/${tag}"
}

declare -a generated_tags=()
declare -A used_prefixes=()

for (( index = 1; index <= TAG_COUNT; index += 1 )); do
  version_patch="$((version_patch_base + index))"

  if (( index == FIXED_TAG_POSITION )); then
    tag_prefix="$FIXED_TAG_NAME"
  else
    while :; do
      candidate="gh-app-test-$(random_prefix)"

      if [[ "$candidate" != "$FIXED_TAG_NAME" && -z "${used_prefixes[$candidate]+x}" ]]; then
        tag_prefix="$candidate"
        break
      fi
    done
  fi

  used_prefixes["$tag_prefix"]=1
  generated_tags+=("${tag_prefix}@0.${version_minor}.${version_patch}")
done

for tag in "${generated_tags[@]}"; do
  if tag_exists_locally "$tag"; then
    echo "::error::Local tag already exists: ${tag}" >&2
    exit 1
  fi

  if tag_exists_on_remote "$tag"; then
    echo "::error::Remote tag already exists: ${tag}" >&2
    exit 1
  fi
done

for tag in "${generated_tags[@]}"; do
  git tag -a "$tag" -m "Release ${tag}" "$target_commit"
  push_tag "$tag"
  echo "Pushed tag via GitHub App: ${tag}"
done

{
  echo "generated-tags<<EOF"
  printf '%s\n' "${generated_tags[@]}"
  echo "EOF"
} >> "$GITHUB_OUTPUT"

{
  echo "### Created Test Tags"
  echo
  echo "- target ref: ${TARGET_REF}"
  echo "- target commit: ${target_commit}"
  echo "- fixed tag prefix: ${FIXED_TAG_NAME}"
  echo "- fixed tag position: ${FIXED_TAG_POSITION}/${TAG_COUNT}"
  echo
  for tag in "${generated_tags[@]}"; do
    echo "- ${tag}"
  done
} >> "$GITHUB_STEP_SUMMARY"