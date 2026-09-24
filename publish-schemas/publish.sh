#!/usr/bin/env bash
#
# Publish JSON schemas by their `$id`.
#
# Usage:
#   publish.sh <bucket> <tarball> <schema>...
#
#   bucket   - where schemas are published, as gs://<bucket>
#   tarball  - path of the .tar.gz to write, laid out as the published paths, for sync-docs
#   schema   - one or more schema files, each declaring its canonical URL in `$id`
#
# Environment:
#   ID_PREFIX      - what every `$id` starts with, e.g. https://schemas.example.com/
#   GITHUB_OUTPUT  - when set, `urls` (the `$id`s, one per line) is written to it
#
# A schema's `$id` is <ID_PREFIX>schemas/<name>-<major>.<minor>.schema.json and its file
# is <name>.schema.json. What follows the prefix is the object's path in the bucket and its path
# in the tarball, so the URL, the bucket and the tarball agree by construction. A version is
# immutable: an object that already exists with the same content is left alone, one with
# different content fails the run, and only a missing one is uploaded.

set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: $(basename "$0") <bucket> <tarball> <schema>..." >&2
  exit 1
fi
: "${ID_PREFIX:?ID_PREFIX must be set to what every \$id starts with}"

bucket="${1%/}"
tarball="$2"
shift 2

stage=$(mktemp -d)
trap 'rm -rf "${stage}"' EXIT
urls=()

md5_of_file() { gsutil hash -m "$1" 2>/dev/null | awk '/Hash \(md5\)/ { print $NF }'; }
md5_of_object() { gsutil stat "$1" | awk '/Hash \(md5\)/ { print $NF }'; }

for path in "$@"; do
  [ -f "${path}" ] || { echo "${path}: no such file" >&2; exit 1; }

  id=$(jq -r '."$id" // empty' "${path}")
  [ -n "${id}" ] || { echo "${path}: declares no \$id" >&2; exit 1; }

  relative="${id#"${ID_PREFIX}"}"
  if [ "${relative}" = "${id}" ]; then
    echo "${path}: \$id '${id}' does not start with '${ID_PREFIX}'" >&2
    exit 1
  fi
  if [[ ! "${relative}" =~ ^schemas/([A-Za-z0-9._-]+)-([0-9]+\.[0-9]+)\.schema\.json$ ]]; then
    echo "${path}: \$id '${id}' is not <prefix>schemas/<name>-<major>.<minor>.schema.json" >&2
    exit 1
  fi
  name="${BASH_REMATCH[1]}"
  if [ "$(basename "${path}")" != "${name}.schema.json" ]; then
    echo "${path}: a schema whose \$id names '${name}' is kept as ${name}.schema.json" >&2
    exit 1
  fi

  destination="${bucket}/${relative}"
  if gsutil -q stat "${destination}"; then
    local_md5=$(md5_of_file "${path}")
    remote_md5=$(md5_of_object "${destination}")
    if [ "${local_md5}" != "${remote_md5}" ]; then
      echo "${path}: ${destination} exists with different content; a changed schema needs a new version in its \$id" >&2
      exit 1
    fi
    echo "unchanged ${id}"
  else
    gsutil cp "${path}" "${destination}"
    echo "published ${id}"
  fi

  mkdir -p "${stage}/$(dirname "${relative}")"
  cp "${path}" "${stage}/${relative}"
  urls+=("${id}")
done

tar czf "${tarball}" -C "${stage}" .
echo "staged ${#urls[@]} schema(s) in ${tarball}"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "urls<<URLS"
    printf '%s\n' "${urls[@]}"
    echo "URLS"
  } >> "${GITHUB_OUTPUT}"
fi
