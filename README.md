# RemotiveTopology actions

Reusable GitHub Actions used across RemotiveLabs CI pipelines.

## Actions

| Action | Description |
|---|---|
| [`generate`](generate/README.md) | Generate a Docker Compose file from one or more RemotiveTopology description files via the [RemotiveTopology CLI](https://docs.remotivelabs.com/docs/remotive-topology/usage). |
| [`sync-docs`](sync-docs/README.md) | Publish a pre-packaged content tarball from a source repo into a central target repo (docs site, api aggregator, ...), opening + auto-merging a PR. Pure transport — packaging stays in the source workflow. |

## Versioning

Pin via the `@v1` tag on this repo:

```yaml
- uses: remotivelabs/remotivelabs-topology-actions/generate@v1
- uses: remotivelabs/remotivelabs-topology-actions/sync-docs@v1
```

See each action's README for full input documentation and usage examples.
