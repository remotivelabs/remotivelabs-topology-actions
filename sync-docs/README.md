# sync-docs

Publish a pre-packaged content tarball from a source repo into a central target repo (e.g. `remotivelabs/remotiveplatform-docs`, `remotivelabs/remotivelabs-apis`).

The action:

1. Mints a short-lived [GitHub App](https://docs.github.com/en/apps/creating-github-apps) installation token scoped to the target repo.
2. Checks out the target repo and resets a long-lived branch `docs-sync/<source-repo>-<component>` from `origin/main`.
3. Extracts the input tarball into `<target-subpath>` in the target.
4. Commits, force-pushes the branch with `--force-with-lease`, opens (or reuses) a PR with the configured `labels` plus an auto-added `source:<source-repo>` label.
5. Waits for the PR's checks to pass via `gh pr checks --watch`.
6. Rebase-merges the PR.

If any of the PR's checks fail, the action fails before merging.

## Contract

The tarball is the final on-disk layout the source workflow wants under `<target-subpath>`. The action is pure transport — it does not write any version dirs, redirect `index.html`, `versions.json`, or any other format-specific content. Anything like that lives in the source workflow's packaging step before invoking the action.

This keeps the action format-agnostic and lets each source repo own its own URL structure, version layout, and redirect strategy (pdoc, json-schema-for-humans, raw JSON, plain HTML, etc.). The same action serves docs-style targets (`remotiveplatform-docs`) and api-aggregator targets (`remotivelabs-apis`); the difference is the tarball shape and the labels.

## Prerequisites

- A GitHub App installed on the target repo with **Contents: read/write**, **Pull requests: read/write**, **Checks: read**, and **Actions: read** permissions.
- The App's ID and private key stored as secrets in the source repo (e.g. `DOCS_PUSH_APP_ID`, `DOCS_PUSH_PRIVATE_KEY`).
- The target repo must allow rebase merges (the action uses `gh pr merge --rebase`).
- A PR check workflow in the target repo (e.g. a `build-on-pull-request.yaml`) — the action waits for it before merging.
- The labels passed via the `labels` input + a `source:<source-repo>` label exist on the target repo.

## Usage

```yaml
- uses: remotivelabs/remotivelabs-topology-actions/sync-docs@v1
  with:
    # GitHub App ID for the docs-sync App.
    # Required
    app-id: ""
    # GitHub App private key (.pem contents).
    # Required
    private-key: ""
    # Name of the central docs repo. Assumed to be in the same org as the calling repo.
    # Required
    target-repo: ""
    # Slug identifying the source component owning this content (e.g. topology, broker, broker-schemas).
    # Used in the sync branch name (docs-sync/<source-repo>-<component>) so concurrent
    # component releases stay isolated, and in the PR title/commit message.
    # Required
    source-component: ""
    # Local path to the tarball (.tar.gz) produced by the source workflow.
    # Contents land verbatim under <target-subpath> in the target repo.
    # Required
    tarball-path: ""
    # Directory under the target repo where the tarball contents land
    # (e.g. apis-static/python/remotivelabs/topology, apis-static/json, schemas).
    # Required
    target-subpath: ""
    # Newline-separated list of labels to attach to the PR (in addition to
    # the automatically-added `source:<source-repo>` label). Default
    # `docs-sync` matches the convention in remotiveplatform-docs; override
    # with a different label (e.g. `schemas-sync`) when pushing to a target
    # that uses a different convention.
    # Optional, default: docs-sync
    labels: ""
```

## Example: versioned Python API docs (pdoc)

The source workflow's packaging step is responsible for the version layout. It builds pdoc output, then writes the `<version>/` dir, the version-dir redirect `index.html`, the `versions.json` (semver-desc list of all versions present in the target), and the unversioned top-level redirect — all into the tarball — before invoking the action.

```yaml
publish-docs:
  needs: [get-version, create-release]
  runs-on: ubuntu-latest
  concurrency:
    group: publish-docs-${{ github.event.repository.name }}-topology
    cancel-in-progress: false
  steps:
    - uses: actions/download-artifact@v4
      with:
        name: docs-${{ needs.get-version.outputs.version }}
        path: /tmp/pdoc

    - name: Package versioned tarball
      env:
        VERSION: ${{ needs.get-version.outputs.version }}
        PACKAGE_NAME: remotivelabs-topology
        TARGET_SUBPATH: apis-static/python/remotivelabs/topology
      run: bash scripts/package-versioned-docs.sh /tmp/pdoc /tmp/docs-bundle.tar.gz

    - uses: remotivelabs/remotivelabs-topology-actions/sync-docs@v1
      with:
        app-id: ${{ secrets.DOCS_PUSH_APP_ID }}
        private-key: ${{ secrets.DOCS_PUSH_PRIVATE_KEY }}
        target-repo: remotiveplatform-docs
        source-component: topology
        tarball-path: /tmp/docs-bundle.tar.gz
        target-subpath: apis-static/python/remotivelabs/topology
```

## Example: flat JSON-schema HTML

For non-versioned content (e.g. schema docs in Phase 1), the packaging step just renders + tars the final layout.

```yaml
- name: Render schemas
  run: |
    pip install --user json-schema-for-humans
    mkdir -p rendered
    generate-schema-doc apps/topology/schemas/topology.schema.json rendered/topology.html
    tar czf /tmp/schema-docs.tar.gz -C rendered .

- uses: remotivelabs/remotivelabs-topology-actions/sync-docs@v1
  with:
    app-id: ${{ secrets.DOCS_PUSH_APP_ID }}
    private-key: ${{ secrets.DOCS_PUSH_PRIVATE_KEY }}
    target-repo: remotiveplatform-docs
    source-component: topology-schemas
    tarball-path: /tmp/schema-docs.tar.gz
    target-subpath: apis-static/json
```

## Example: raw JSON schemas to the apis aggregator

Same action, different target. Stage the schemas under their published filenames, tar, push.

```yaml
- name: Stage schemas for apis
  run: |
    mkdir -p /tmp/apis-stage/schemas
    cp apps/topology/schemas/topology.schema.json /tmp/apis-stage/schemas/topology.json
    tar czf /tmp/schemas-to-apis.tar.gz -C /tmp/apis-stage .

- uses: remotivelabs/remotivelabs-topology-actions/sync-docs@v1
  with:
    app-id: ${{ secrets.DOCS_PUSH_APP_ID }}
    private-key: ${{ secrets.DOCS_PUSH_PRIVATE_KEY }}
    target-repo: remotivelabs-apis
    source-component: topology-apis
    tarball-path: /tmp/schemas-to-apis.tar.gz
    target-subpath: .
    labels: schemas-sync
```
