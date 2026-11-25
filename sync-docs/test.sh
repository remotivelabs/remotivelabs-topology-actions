#!/usr/bin/env bash
#
# Exercises sync.sh against a local target repo and a stubbed gh that records what it is asked.
#
#   bash sync-docs/test.sh

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

# The target repo: a bare origin with a main branch, and a clone of it to run sync.sh in
git init -q --bare -b main "${work}/origin.git"
git clone -q "${work}/origin.git" "${work}/seed" 2>/dev/null
git -C "${work}/seed" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
git -C "${work}/seed" push -q origin main

# A gh that answers what sync.sh asks, from $FAKE_OPEN_PR (an open PR's number, or empty),
# and logs every call to $GH_LOG
mkdir -p "${work}/bin"
cat > "${work}/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${GH_LOG}"
case "$1 $2" in
  "pr list")   echo "${FAKE_OPEN_PR}" ;;
  "pr create") echo "https://github.com/example/target/pull/7" ;;
  "pr checks") if [[ " $* " == *" --json "* ]]; then echo 1; fi ;;
  "pr merge")  ;;
  *)           echo "stub gh: unexpected $*" >&2; exit 2 ;;
esac
STUB
chmod +x "${work}/bin/gh"
export PATH="${work}/bin:${PATH}" GH_LOG="${work}/gh.log"
export SOURCE_REPO=source SOURCE_SHA=0123456789abcdef SOURCE_COMPONENT=docs TARGET_SUBPATH=apis-static/source
export LABELS=$'docs-sync\n\nextra'

docs() { # docs <content> -> a tarball holding index.html with that content
  mkdir -p "${work}/content" && echo "$1" > "${work}/content/index.html"
  tar czf "${work}/docs.tar.gz" -C "${work}/content" .
}
sync() { # sync <open PR or empty>: sync.sh in a fresh clone of the target
  rm -rf "${work}/target" && : > "${GH_LOG}"
  git clone -q "${work}/origin.git" "${work}/target" 2>/dev/null
  (cd "${work}/target" && FAKE_OPEN_PR="$1" TARBALL_PATH="${work}/docs.tar.gz" bash "${here}/sync.sh") > "${work}/stdout"
}
fail() { echo "FAIL: $1"; echo "--- stdout"; cat "${work}/stdout"; echo "--- gh"; cat "${GH_LOG}"; exit 1; }
asked() { grep -qF -- "$1" "${GH_LOG}" || fail "gh was not asked '$1'"; }
not_asked() { ! grep -qF -- "$1" "${GH_LOG}" || fail "gh was asked '$1'"; }
branch_has() { # branch_has <content>
  [ "$(git -C "${work}/origin.git" show "docs-sync/source-docs:apis-static/source/index.html")" = "$1" ] || fail "the branch does not hold '$1'"
}

# New docs: pushed to the sync branch, a PR opened with the labels and the source label, merged
docs v1
sync ""
branch_has v1
asked "pr create --base main --head docs-sync/source-docs --title docs(source): publish docs (0123456)"
asked "--label docs-sync --label extra --label source:source"
asked "pr checks 7 --watch"
asked "pr merge 7 --rebase"

# The same docs again, the branch merged into main: nothing to publish, so no PR and no push
git -C "${work}/origin.git" update-ref refs/heads/main "$(git -C "${work}/origin.git" rev-parse docs-sync/source-docs)"
sync ""
grep -q "No docs changes to publish" "${work}/stdout" || fail "it published unchanged docs"
[ ! -s "${GH_LOG}" ] || fail "gh was asked anything"

# New docs while the PR of the last ones is open: the PR is updated, not opened again
docs v2
sync 12
branch_has v2
not_asked "pr create"
asked "pr checks 12 --watch"
asked "pr merge 12 --rebase"

echo "sync-docs: all cases pass"
