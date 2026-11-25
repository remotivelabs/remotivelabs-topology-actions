# RemotiveTopology actions

Reusable GitHub Actions used across RemotiveLabs CI pipelines.

## Actions

| Action | Description |
|---|---|
| [`setup`](setup/README.md) | Install the RemotiveCLI with the RemotiveLabs Toolchain Manager: the version given, or the one the workspace's `remotive.yaml` pins, else the latest. |
| [`auth`](auth/README.md) | Make a RemotiveCloud service account the account of the job's later steps, from secrets given as inputs. |
| [`build`](build/README.md) | Build a RemotiveTopology environment from instance files with `remotive topology build`. |
| [`generate`](generate/README.md) | **Deprecated**, use `setup`, `auth` and `build`. Generate a Docker Compose file from one or more RemotiveTopology description files via the [RemotiveTopology CLI](https://developer.remotivelabs.com/docs/remotive-topology/usage). |
| [`sync-docs`](sync-docs/README.md) | Publish a pre-packaged content tarball from a source repo into a central target repo (docs site, api aggregator, ...), opening + auto-merging a PR. Pure transport — packaging stays in the source workflow. |
| [`publish-schemas`](publish-schemas/README.md) | Publish JSON schemas to a bucket at the path their `$id` names — immutable per version — and stage the same layout in a tarball for `sync-docs`. |

## Versioning

Pin via the `@v1` tag on this repo:

```yaml
- uses: remotivelabs/remotivelabs-topology-actions/setup@v1
- uses: remotivelabs/remotivelabs-topology-actions/auth@v1
- uses: remotivelabs/remotivelabs-topology-actions/build@v1
- uses: remotivelabs/remotivelabs-topology-actions/sync-docs@v1
- uses: remotivelabs/remotivelabs-topology-actions/publish-schemas@v1
```

See each action's README for full input documentation and usage examples.
