# sync-docs

Publish a versioned API-docs tarball from a source repo into a central docs repo (e.g. `remotivelabs/remotiveplatform-docs`).

The action:

1. Mints a short-lived [GitHub App](https://docs.github.com/en/apps/creating-github-apps) installation token scoped to the target repo.
2. Checks out the target repo and resets a long-lived branch `docs-sync/<source-repo>` from `origin/main`.
3. Lays out the new version directory under `<target-subpath>/<version>/`, regenerates `versions.json` and a redirect `index.html` for the unversioned URL.
4. Commits, force-pushes the branch with `--force-with-lease`, opens (or reuses) a PR with labels `docs-sync` and `source:<source-repo>`.
5. Waits for the PR's checks to pass via `gh pr checks --watch`.
6. Rebase-merges the PR.

If any of the PR's checks fail, the action fails before merging.

## Prerequisites

- A GitHub App installed on the target repo with **Contents: read/write** and **Pull requests: read/write** permissions.
- The App's ID and private key stored as secrets in the source repo (e.g. `DOCS_PUSH_APP_ID`, `DOCS_PUSH_PRIVATE_KEY`).
- The target repo must allow rebase merges (the action uses `gh pr merge --rebase`).
- A PR check workflow in the target repo (e.g. a `build-on-pull-request.yaml`) — the action waits for it before merging.

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
    # Semver version being published (e.g. 0.17.0).
    # Required
    version: ""
    # Python package name. Used in PR title and commit message (e.g. remotivelabs-topology).
    # Required
    package-name: ""
    # Local path to the docs tarball (.tar.gz) produced by the source workflow.
    # Required
    tarball-path: ""
    # Directory under the target repo where the versioned tree lands. The
    # <version>/ subdir is created here; versions.json and index.html are
    # regenerated alongside it. E.g. apis-static/python/remotivelabs/topology
    # Required
    target-subpath: ""
```

## Example

Publish topology API docs from a release tag:

```yaml
publish-docs:
  needs: [get-version, create-release]
  runs-on: ubuntu-latest
  concurrency:
    group: publish-docs-${{ github.event.repository.name }}
    cancel-in-progress: false
  steps:
    - uses: actions/download-artifact@v4
      with:
        name: remotivelabs-topology-docs-${{ needs.get-version.outputs.version }}
        path: /tmp/docs-artifact

    - uses: remotivelabs/remotivelabs-topology-actions/sync-docs@v1
      with:
        app-id: ${{ secrets.DOCS_PUSH_APP_ID }}
        private-key: ${{ secrets.DOCS_PUSH_PRIVATE_KEY }}
        target-repo: remotiveplatform-docs
        version: ${{ needs.get-version.outputs.version }}
        package-name: remotivelabs-topology
        tarball-path: /tmp/docs-artifact/topology-docs-${{ needs.get-version.outputs.version }}.tar.gz
        target-subpath: apis-static/python/remotivelabs/topology
```

## Output layout in the target repo

After a successful run for version `0.17.0`, the target repo contains:

```
apis-static/python/remotivelabs/topology/
├── 0.17.0/
│   ├── index.html
│   └── ...                  # contents of the tarball
├── versions.json            # { "latest": "0.17.0", "versions": ["0.17.0", ...] }
└── index.html               # meta-refresh to ./<latest>/
```

The unversioned `index.html` always redirects to the latest version. `versions.json` is consumed by an in-page version-switcher dropdown (set up by the source repo's docs theme) so historical versions stay navigable.
