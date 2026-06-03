#!/usr/bin/env bash
#
# Publish a pre-packaged docs tarball into the central docs repo.
#
# Run from inside a fresh checkout of the central docs repo. Reads inputs
# from env vars (set by action.yml):
#
#   SOURCE_REPO       - source repo name (e.g. signalbroker-server)
#   SOURCE_SHA        - source commit SHA (for traceability in PR body)
#   SOURCE_COMPONENT  - component slug owning these docs (e.g. topology, broker)
#   TARBALL_PATH      - local path to the docs tarball produced by the source workflow
#   TARGET_SUBPATH    - dir under the target where the tarball contents land
#                       (e.g. apis-static/python/remotivelabs/topology)
#   LABELS            - newline-separated list of labels for the PR (in addition
#                       to the auto-added `source:<source-repo>` label)
#   GH_TOKEN          - App installation token, used for git push and gh pr commands
#
# Contract: the tarball is the final on-disk layout the source workflow wants
# under TARGET_SUBPATH. This action is pure transport — it does not write any
# version dirs, redirects, versions.json, or any other format-specific content.
# Anything like that belongs in the source workflow's packaging step.

set -euo pipefail

BRANCH="docs-sync/${SOURCE_REPO}-${SOURCE_COMPONENT}"
SHORT_SHA="${SOURCE_SHA:0:7}"

git config user.name  "remotivelabs-docs-bot[bot]"
git config user.email "remotivelabs-docs-bot[bot]@users.noreply.github.com"

# Always start from current main so the PR diff is just this release's content.
git fetch origin main
git checkout -B "${BRANCH}" origin/main

# Extract the source-prepared tarball directly into the target subpath.
mkdir -p "${TARGET_SUBPATH}"
tar xzf "${TARBALL_PATH}" -C "${TARGET_SUBPATH}"

# No-diff early exit — avoids empty commits and noise.
git add "${TARGET_SUBPATH}"
if git diff --cached --quiet; then
  echo "No docs changes to publish; skipping push/PR/merge."
  exit 0
fi

git commit -m "docs(${SOURCE_REPO}): publish ${SOURCE_COMPONENT}"
git push --force-with-lease origin "${BRANCH}"

# Idempotent PR open — only consider OPEN PRs as "already exists". The branch
# is long-lived (no --delete-branch on merge), so prior releases leave merged
# PRs attached to it; `gh pr view BRANCH` returns those by default and would
# falsely report the PR as existing, skipping creation for the new commit.
pr_number=$(gh pr list --head "${BRANCH}" --state open --json number --jq '.[0].number')
if [ -z "${pr_number}" ]; then
  # Collect label flags: caller-supplied (newline-separated) + auto-added source label.
  label_args=()
  while IFS= read -r label; do
    [ -z "${label}" ] && continue
    label_args+=(--label "${label}")
  done <<< "${LABELS}"
  label_args+=(--label "source:${SOURCE_REPO}")

  pr_url=$(gh pr create \
    --base main \
    --head "${BRANCH}" \
    --title "docs(${SOURCE_REPO}): publish ${SOURCE_COMPONENT} (${SHORT_SHA})" \
    --body "Automated docs sync from ${SOURCE_REPO}@${SOURCE_SHA}. PR build is the merge gate." \
    "${label_args[@]}")
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
# docs-sync/<source>-<component> is a persistent sync channel, force-pushed
# each release.
gh pr merge "${pr_number}" --rebase
