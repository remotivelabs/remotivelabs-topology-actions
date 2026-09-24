#!/usr/bin/env bash
#
# Exercises publish.sh against a stubbed gsutil whose bucket is a directory.
#
#   bash publish-schemas/test.sh

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

# A gsutil that keeps gs://<bucket>/<path> at $FAKE_BUCKET_DIR/<path>, answering only what
# publish.sh asks: `hash -m <file>`, `[-q] stat <object>` and `cp <file> <object>`.
mkdir -p "${work}/bin" "${work}/bucket"
cat > "${work}/bin/gsutil" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
md5() { openssl dgst -md5 -binary "$1" | base64; }
object_path() { local object="${1#gs://}"; echo "${FAKE_BUCKET_DIR}/${object#*/}"; }
quiet=false
[ "$1" = "-q" ] && { quiet=true; shift; }
case "$1" in
  hash) printf 'Hashes [base64] for %s:\n\tHash (md5):\t\t%s\n' "$3" "$(md5 "$3")" ;;
  stat) file=$(object_path "$2"); [ -f "${file}" ] || exit 1
        ${quiet} || printf '%s:\n    Hash (md5):\t\t%s\n' "$2" "$(md5 "${file}")" ;;
  cp)   file=$(object_path "$3"); mkdir -p "$(dirname "${file}")"; cp "$2" "${file}" ;;
  *)    echo "stub gsutil: unexpected $*" >&2; exit 2 ;;
esac
STUB
chmod +x "${work}/bin/gsutil"
export PATH="${work}/bin:${PATH}" FAKE_BUCKET_DIR="${work}/bucket" ID_PREFIX="https://schemas.example.com/"

schema() { # schema <name> <version> <marker>  -> writes <work>/<name>.schema.json
  printf '{"$schema":"http://json-schema.org/draft-07/schema#","$id":"https://schemas.example.com/schemas/%s-%s.schema.json","title":"%s","type":"object"}\n' \
    "$1" "$2" "$3" > "${work}/$1.schema.json"
}
publish() { GITHUB_OUTPUT="${work}/output" bash "${here}/publish.sh" gs://example-bucket "${work}/out.tar.gz" "$@" > "${work}/stdout"; }
assert_stdout() { grep -q -- "$1" "${work}/stdout" || { echo "FAIL: stdout lacks '$1':"; cat "${work}/stdout"; exit 1; }; }
tarball_lists() { tar tzf "${work}/out.tar.gz" > "${work}/tarball"; grep -q -- "$1" "${work}/tarball" || { echo "FAIL: tarball lacks '$1':"; cat "${work}/tarball"; exit 1; }; }
expect_failure() { if "$@" 2>"${work}/stderr"; then echo "FAIL: expected a failure: $*"; exit 1; fi; }
assert_stderr() { grep -q -- "$1" "${work}/stderr" || { echo "FAIL: stderr lacks '$1':"; cat "${work}/stderr"; exit 1; }; }

echo "== a new version is uploaded and staged"
schema example-format 0.1 "first"
: > "${work}/output"
publish "${work}/example-format.schema.json"
assert_stdout "^published https://schemas.example.com/schemas/example-format-0.1.schema.json$"
test -f "${work}/bucket/schemas/example-format-0.1.schema.json"
tarball_lists "^./schemas/example-format-0.1.schema.json$"
grep -q "^https://schemas.example.com/schemas/example-format-0.1.schema.json$" "${work}/output"

echo "== the same version again is left alone"
publish "${work}/example-format.schema.json"
assert_stdout "^unchanged "

echo "== the same version with other content fails before anything is written"
schema example-format 0.1 "second"
expect_failure publish "${work}/example-format.schema.json"
assert_stderr "exists with different content"
[ "$(cat "${work}/bucket/schemas/example-format-0.1.schema.json" | jq -r .title)" = "first" ]

echo "== a bumped version is uploaded beside the old one"
schema example-format 0.2 "second"
publish "${work}/example-format.schema.json"
assert_stdout "^published .*example-format-0.2.schema.json$"
test -f "${work}/bucket/schemas/example-format-0.1.schema.json"
test -f "${work}/bucket/schemas/example-format-0.2.schema.json"

echo "== several schemas in one run"
schema other-format 1.0 "other"
publish "${work}/example-format.schema.json" "${work}/other-format.schema.json"
[ "$(grep -c "^\(published\|unchanged\) " "${work}/stdout")" = "2" ]
tar tzf "${work}/out.tar.gz" > "${work}/tarball"
[ "$(grep -c '\.schema\.json$' "${work}/tarball")" = "2" ]

echo "== a schema without an \$id is refused"
printf '{"title":"no id"}\n' > "${work}/no-id.schema.json"
expect_failure publish "${work}/no-id.schema.json"
assert_stderr "declares no \$id"

echo "== an \$id off the prefix is refused"
printf '{"$id":"https://elsewhere.example.com/schemas/x/x-0.1.schema.json"}\n' > "${work}/x.schema.json"
expect_failure publish "${work}/x.schema.json"
assert_stderr "does not start with"

echo "== an \$id off the convention is refused"
printf '{"$id":"https://schemas.example.com/schemas/x/x-0.1.0.schema.json"}\n' > "${work}/x.schema.json"
expect_failure publish "${work}/x.schema.json"
assert_stderr "is not <prefix>schemas/<name>-<major>.<minor>.schema.json"

echo "== a file not named after its \$id is refused"
schema example-format 0.3 "third"
cp "${work}/example-format.schema.json" "${work}/renamed.schema.json"
expect_failure publish "${work}/renamed.schema.json"
assert_stderr "is kept as example-format.schema.json"

echo "all good"
