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
cat > "${TARGET_SUBPATH}/index.html" <<EOF
<!doctype html>
<meta http-equiv="refresh" content="0; url=./${latest}/">
<link rel="canonical" href="./${latest}/">
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

# Idempotent PR open — if a PR already exists for the branch (e.g. from a
# previous failed run), reuse it instead of erroring.
if ! gh pr view "${BRANCH}" --json number >/dev/null 2>&1; then
  gh pr create \
    --base main \
    --head "${BRANCH}" \
    --title "docs(${SOURCE_REPO}): publish ${PACKAGE_NAME} ${VERSION} (${SHORT_SHA})" \
    --body "Automated docs sync from ${SOURCE_REPO}@${SOURCE_SHA}. PR build is the merge gate." \
    --label "docs-sync" \
    --label "source:${SOURCE_REPO}"
fi

# Wait for target's PR checks (build-on-pull-request.yaml) to finish.
# Non-zero exit if any check fails — that aborts the merge.
gh pr checks "${BRANCH}" --watch

# Rebase merge (target repo's policy). No --delete-branch:
# docs-sync/<source> is a persistent sync channel, force-pushed each release.
gh pr merge "${BRANCH}" --rebase
