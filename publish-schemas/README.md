# publish-schemas

Publish JSON schemas to a bucket at the path their `$id` names, and stage the same layout in a
tarball for [`sync-docs`](../sync-docs/README.md) to carry into an aggregator repo.

## Contract

A schema declares its canonical URL in `$id`:

```
<id-prefix>schemas/<name>/<name>-<major>.<minor>.schema.json
```

and its file is `<name>.schema.json` — unversioned, so diffs and history read cleanly. What
follows the prefix is the object's path in the bucket and its path in the tarball, so the URL, the
bucket and the aggregator agree by construction, and the name and version come from the `$id`
alone.

A version is immutable. For each schema the action:

1. reads the `$id` and refuses anything not in the form above, or a file not named after it;
2. if the object exists in the bucket with the **same** content, leaves it alone (`unchanged`);
   with **different** content, fails the run — a changed schema needs a new version in its `$id`;
3. otherwise uploads it (`published`);
4. copies it into the tarball at the same path.

Publishing is therefore safe to repeat on every release of the component that owns the schema.
Bumping the version when the schema changes is the release flow's job before it tags; this action
is the check that it happened.

## Prerequisites

- Authenticated to Google Cloud before this step, with write access to the bucket — for example
  `google-github-actions/auth` followed by `google-github-actions/setup-gcloud`, which also
  provides `gsutil`.
- `jq` on the runner (present on GitHub-hosted runners).

## Usage

```yaml
- uses: remotivelabs/remotivelabs-topology-actions/publish-schemas@v1
  with:
    # Newline or space separated schema files, relative to the workspace root.
    # Required
    schemas: |
      schemas/my-format.schema.json
    # Where the schemas are published, as gs://<bucket>.
    # Required
    bucket: gs://my-schemas-bucket
    # The .tar.gz to write, laid out as the published paths, for sync-docs.
    # Required
    tarball-path: /tmp/schemas.tar.gz
    # What every $id starts with. What follows it is the path in the bucket and the tarball.
    # Default: https://releases.remotivelabs.com/
    id-prefix: ''
```

Outputs:

| Output | |
|---|---|
| `urls` | the `$id` of every schema published or found unchanged, one per line |

## Example

```yaml
- id: gcp-auth
  uses: google-github-actions/auth@v3
  with:
    workload_identity_provider: ${{ vars.WORKLOAD_IDENTITY_PROVIDER }}
    service_account: ${{ vars.SERVICE_ACCOUNT_EMAIL }}
- uses: google-github-actions/setup-gcloud@v2

- uses: remotivelabs/remotivelabs-topology-actions/publish-schemas@v1
  with:
    schemas: schemas/my-format.schema.json
    bucket: ${{ vars.SCHEMAS_BUCKET }}
    tarball-path: /tmp/schemas.tar.gz

- uses: remotivelabs/remotivelabs-topology-actions/sync-docs@v1
  with:
    app-id: ${{ secrets.DOCS_PUSH_APP_ID }}
    private-key: ${{ secrets.DOCS_PUSH_PRIVATE_KEY }}
    target-repo: my-apis-repo
    source-component: my-component-schemas
    tarball-path: /tmp/schemas.tar.gz
    target-subpath: .
    labels: schemas-sync
```

## Testing

`bash publish-schemas/test.sh` runs the script against a stubbed `gsutil` whose bucket is a
directory, and covers the upload, the unchanged and the refused cases.
