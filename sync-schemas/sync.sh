#!/usr/bin/env bash
#
# Publish a set of JSON schemas into the central API repo.
#
# Run from inside a fresh checkout of the central API repo. Reads inputs
# from env vars (set by action.yml):
#
#   SOURCE_REPO       - source repo name (e.g. signalbroker-server)
#   SOURCE_SHA        - source commit SHA (for traceability in PR body)
#   SOURCE_WORKSPACE  - source repo checkout dir (schemas[].path are relative to this)
#   SOURCE_COMPONENT  - component slug owning these schemas (e.g. topology, broker)
#   SCHEMAS_YAML      - multi-line YAML list of {name, path} pairs
#   GH_TOKEN          - App installation token, used for git push and gh pr commands
#
# Outcome: a single commit lands on the target's main, containing the listed
# schemas at schemas/<name>.json (flat layout — Phase 1).

set -euo pipefail

BRANCH="schemas-sync/${SOURCE_REPO}-${SOURCE_COMPONENT}"
SHORT_SHA="${SOURCE_SHA:0:7}"

git config user.name  "remotivelabs-docs-bot[bot]"
git config user.email "remotivelabs-docs-bot[bot]@users.noreply.github.com"

# Always start from current main so the PR diff is just this release's schemas.
git fetch origin main
git checkout -B "${BRANCH}" origin/main

# Parse SCHEMAS_YAML into tab-separated (name, path) pairs.
# Minimal YAML — accepts block form and flow form:
#   - name: topology
#     path: apps/topology/schemas/topology.schema.json
#   - { name: recording, path: apps/recording/schemas/recording.schema.json }
# Avoids PyYAML so we don't need pip install on the runner.
PAIRS=$(mktemp)
trap 'rm -f "${PAIRS}"' EXIT
python3 - "${PAIRS}" <<'PY'
import os, sys

text = os.environ["SCHEMAS_YAML"]
out_path = sys.argv[1]

def strip_quote(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in ("'", '"'):
        v = v[1:-1]
    return v

entries = []
current = None
for raw in text.splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    if line.startswith("- "):
        if current is not None:
            entries.append(current)
            current = None
        rest = line[2:].strip()
        if rest.startswith("{") and rest.endswith("}"):
            entry = {}
            for part in rest[1:-1].split(","):
                if ":" not in part:
                    continue
                k, _, v = part.partition(":")
                entry[k.strip()] = strip_quote(v)
            entries.append(entry)
        else:
            current = {}
            k, _, v = rest.partition(":")
            current[k.strip()] = strip_quote(v)
    elif ":" in line and current is not None:
        k, _, v = line.partition(":")
        current[k.strip()] = strip_quote(v)
    else:
        sys.stderr.write(f"Cannot parse schemas line: {raw!r}\n")
        sys.exit(1)
if current is not None:
    entries.append(current)

if not entries:
    sys.stderr.write("schemas input parsed empty; nothing to publish\n")
    sys.exit(1)

with open(out_path, "w") as f:
    for e in entries:
        name = e.get("name", "")
        path = e.get("path", "")
        if not name or not path:
            sys.stderr.write(f"Invalid schema entry (missing name or path): {e!r}\n")
            sys.exit(1)
        f.write(f"{name}\t{path}\n")
PY

mkdir -p schemas
while IFS=$'\t' read -r NAME REL_PATH; do
  SRC="${SOURCE_WORKSPACE}/${REL_PATH}"
  if [ ! -f "${SRC}" ]; then
    echo "Source schema not found: ${SRC}" >&2
    exit 1
  fi
  cp "${SRC}" "schemas/${NAME}.json"
done < "${PAIRS}"

# No-diff early exit — avoids empty commits and noise.
git add schemas
if git diff --cached --quiet; then
  echo "No schema changes to publish; skipping push/PR/merge."
  exit 0
fi

git commit -m "schemas(${SOURCE_REPO}): publish ${SOURCE_COMPONENT} schemas"
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
    --title "schemas(${SOURCE_REPO}): publish ${SOURCE_COMPONENT} schemas (${SHORT_SHA})" \
    --body "Automated schema sync from ${SOURCE_REPO}@${SOURCE_SHA}. PR build is the merge gate." \
    --label "schemas-sync" \
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

# Wait for target's PR checks to finish. Non-zero exit if any check fails —
# that aborts the merge.
gh pr checks "${pr_number}" --watch

# Rebase merge (target repo's policy). No --delete-branch:
# schemas-sync/<source>-<component> is a persistent sync channel, force-pushed
# each release.
gh pr merge "${pr_number}" --rebase
