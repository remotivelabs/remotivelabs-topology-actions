#!/usr/bin/env bash
#
# Publish a versioned API-docs tarball into the central docs repo.
#
# Run from inside a fresh checkout of the central docs repo. Reads inputs
# from env vars (set by action.yml):
#
#   SOURCE_REPO       - source repo name (e.g. remotivelabs-ecu-simulations)
#   SOURCE_SHA        - source commit SHA (for traceability in PR body)
#   VERSION           - semver being published (e.g. 0.17.0)
#   PACKAGE_NAME      - python package name (e.g. remotivelabs-topology)
#   TARBALL_PATH      - local path to the docs tarball produced by the source workflow
#   TARGET_SUBPATH    - dir under the target where the version tree lands
#                       (e.g. apis-static/python/remotivelabs/topology)
#   GH_TOKEN          - App installation token, used for git push and gh pr commands
#
# Outcome: a single commit lands on the target's main, containing the new
# <VERSION>/ dir, an updated versions.json, and a redirect index.html.

set -euo pipefail

BRANCH="docs-sync/${SOURCE_REPO}"
SHORT_SHA="${SOURCE_SHA:0:7}"

git config user.name  "remotivelabs-docs-bot[bot]"
git config user.email "remotivelabs-docs-bot[bot]@users.noreply.github.com"

# Always start from current main so the PR diff is just this release's new files.
git fetch origin main
git checkout -B "${BRANCH}" origin/main

# Stage the new version directory.
mkdir -p "${TARGET_SUBPATH}/${VERSION}"
tar xzf "${TARBALL_PATH}" -C "${TARGET_SUBPATH}/${VERSION}"

# URL prefix derived from where the tree is served (Firebase mirrors
# apis-static/* into /apis/* at deploy time).
url_prefix="/apis/${TARGET_SUBPATH#apis-static/}"

# Overwrite pdoc's auto-generated version-dir entry index.html with an
# absolute-URL redirect. pdoc's default points at `./remotivelabs/<module>.html`
# which is RELATIVE — Firebase Hosting (trailingSlash=false) strips the
# trailing slash on the served page, so the browser resolves the relative
# URL from the parent directory and 404s. Absolute URLs sidestep this.
module="${PACKAGE_NAME#remotivelabs-}"
cat > "${TARGET_SUBPATH}/${VERSION}/index.html" <<EOF
<!doctype html>
<meta http-equiv="refresh" content="0; url=${url_prefix}/${VERSION}/remotivelabs/${module}.html">
<link rel="canonical" href="${url_prefix}/${VERSION}/remotivelabs/${module}.html">
<title>${PACKAGE_NAME} ${VERSION} API docs</title>
EOF

# Recompute the version list (semver-desc) from all version dirs present
# after staging — picks the new release as latest if applicable.
versions=$(find "${TARGET_SUBPATH}" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' \
           | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
           | sort -Vr)
latest=$(echo "${versions}" | head -n1)

# versions.json — read by the in-page version-switcher JS.
LATEST="${latest}" VERSIONS="${versions}" python3 - <<'PY'
import json, os, pathlib
target = pathlib.Path(os.environ["TARGET_SUBPATH"]) / "versions.json"
latest = os.environ["LATEST"]
versions = os.environ["VERSIONS"].strip().splitlines()
target.write_text(json.dumps({"latest": latest, "versions": versions}, indent=2) + "\n")
PY

# Unversioned redirect — visiting the bare URL bounces to latest.
# Absolute URL for the same reason as above.
cat > "${TARGET_SUBPATH}/index.html" <<EOF
<!doctype html>
<meta http-equiv="refresh" content="0; url=${url_prefix}/${latest}/">
<link rel="canonical" href="${url_prefix}/${latest}/">
<title>${PACKAGE_NAME} API docs</title>
EOF

# No-diff early exit — avoids empty commits and noise.
git add "${TARGET_SUBPATH}"
if git diff --cached --quiet; then
  echo "No docs changes to publish; skipping push/PR/merge."
  exit 0
fi

git commit -m "docs(${SOURCE_REPO}): publish ${PACKAGE_NAME} ${VERSION}"
git push --force-with-lease origin "${BRANCH}"

# Idempotent PR open — only consider OPEN PRs as "already exists". The branch
# is long-lived (no --delete-branch on merge), so prior releases leave merged
# PRs attached to it; `gh pr view BRANCH` returns those by default and would
# falsely report the PR as existing, skipping creation for the new commit.
pr_number=$(gh pr list --head "${BRANCH}" --state open --json number --jq '.[0].number')
if [ -z "${pr_number}" ]; then
  pr_url=$(gh pr create \
    --base main \
    --head "${BRANCH}" \
    --title "docs(${SOURCE_REPO}): publish ${PACKAGE_NAME} ${VERSION} (${SHORT_SHA})" \
    --body "Automated docs sync from ${SOURCE_REPO}@${SOURCE_SHA}. PR build is the merge gate." \
    --label "docs-sync" \
    --label "source:${SOURCE_REPO}")
  pr_number="${pr_url##*/}"
fi

# After force-pushing the branch, GitHub takes a few seconds to enqueue the
# workflow run and register check runs against the new commit. `gh pr checks
# --watch` treats "no checks reported" as an error and exits non-zero — so
# poll until at least one check is visible before watching. Target by PR
# number to avoid any chance of resolving to a stale merged PR.
echo "Waiting for PR checks to be registered..."
attempts=0
until [ "$(gh pr checks "${pr_number}" --json state --jq 'length' 2>/dev/null || echo 0)" -gt 0 ]; do
  attempts=$((attempts + 1))
  if [ "${attempts}" -gt 30 ]; then
    echo "No checks registered after 5 minutes; proceeding to merge anyway." >&2
    break
  fi
  sleep 10
done

# Wait for target's PR checks (build-on-pull-request.yaml) to finish.
# Non-zero exit if any check fails — that aborts the merge.
gh pr checks "${pr_number}" --watch

# Rebase merge (target repo's policy). No --delete-branch:
# docs-sync/<source> is a persistent sync channel, force-pushed each release.
gh pr merge "${pr_number}" --rebase
