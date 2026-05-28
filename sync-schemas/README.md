# sync-schemas

Publish a set of JSON schemas owned by one component of a source repo into the central API repo (e.g. `remotivelabs/remotivelabs-apis`).

The action:

1. Mints a short-lived [GitHub App](https://docs.github.com/en/apps/creating-github-apps) installation token scoped to the target repo.
2. Checks out the target repo and resets a long-lived branch `schemas-sync/<source-repo>-<component>` from `origin/main`.
3. Copies each listed schema to `schemas/<name>.json` in the target.
4. Commits, force-pushes the branch with `--force-with-lease`, opens (or reuses) a PR with labels `schemas-sync` and `source:<source-repo>`.
5. Waits for the PR's checks to pass via `gh pr checks --watch`.
6. Rebase-merges the PR.

If any of the PR's checks fail, the action fails before merging.

Each source component publishes its own schemas from its release workflow — schema lifecycle = component lifecycle. The per-component branch name keeps concurrent component releases isolated.

## Prerequisites

- A GitHub App installed on the target repo with **Contents: read/write**, **Pull requests: read/write**, **Checks: read**, and **Actions: read** permissions.
- The App's ID and private key stored as secrets in the source repo (e.g. `DOCS_PUSH_APP_ID`, `DOCS_PUSH_PRIVATE_KEY`).
- The target repo must allow rebase merges (the action uses `gh pr merge --rebase`).
- A PR check workflow in the target repo (e.g. a `build-on-pull-request.yaml`) — the action waits for it before merging.
- Labels `schemas-sync` and `source:<source-repo>` exist on the target repo.

## Usage

```yaml
- uses: remotivelabs/remotivelabs-topology-actions/sync-schemas@v1
  with:
    # GitHub App ID for the docs-sync App.
    # Required
    app-id: ""
    # GitHub App private key (.pem contents).
    # Required
    private-key: ""
    # Name of the central API repo. Assumed to be in the same org as the calling repo.
    # Required
    target-repo: ""
    # Slug identifying the source component owning these schemas (e.g. topology, broker).
    # Used in the sync branch name (schemas-sync/<source-repo>-<component>) so concurrent
    # component releases stay isolated, and in the PR title/commit message.
    # Required
    source-component: ""
    # Multi-line YAML list of schemas to publish. Each entry is {name, path}
    # where `path` is the source-schema location relative to the calling repo's
    # checkout.
    # Required
    schemas: ""
```

## Example

Publish the topology schema from the RemotiveTopology release workflow:

```yaml
publish-schemas:
  needs: [get-version]
  runs-on: ubuntu-latest
  concurrency:
    group: publish-schemas-topology
    cancel-in-progress: false
  steps:
    - uses: actions/checkout@v4

    - uses: remotivelabs/remotivelabs-topology-actions/sync-schemas@v1
      with:
        app-id: ${{ secrets.DOCS_PUSH_APP_ID }}
        private-key: ${{ secrets.DOCS_PUSH_PRIVATE_KEY }}
        target-repo: remotivelabs-apis
        source-component: topology
        schemas: |
          - name: topology
            path: apps/topology/schemas/topology.schema.json
```

Publish multiple schemas owned by the broker backend in one invocation:

```yaml
- uses: remotivelabs/remotivelabs-topology-actions/sync-schemas@v1
  with:
    app-id: ${{ secrets.DOCS_PUSH_APP_ID }}
    private-key: ${{ secrets.DOCS_PUSH_PRIVATE_KEY }}
    target-repo: remotivelabs-apis
    source-component: broker
    schemas: |
      - name: recording
        path: apps/recording/schemas/recording.schema.json
      - name: interfaces
        path: apps/util/schemas/interfaces.schema.json
      - name: distributed-interfaces
        path: apps/util/schemas/distributed-interfaces.schema.json
      - name: metadb
        path: apps/codec/schemas/metadb.schema.json
      - name: scripted-db
        path: apps/scripted/schemas/scripted-db.schema.json
```

## Output layout in the target repo

After a successful run, the target repo contains:

```
schemas/
├── topology.json
├── recording.json
├── interfaces.json
├── distributed-interfaces.json
├── metadb.json
└── scripted-db.json
```

The flat layout matches today's `remotivelabs-apis/schemas/` structure — this action replaces the manual `release-schema.sh` scripts that previously copied schemas into apis by hand. Per-version storage will be layered on in a follow-up.
