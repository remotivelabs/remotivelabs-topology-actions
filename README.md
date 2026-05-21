# RemotiveTopology actions

Reusable GitHub Actions used across RemotiveLabs CI pipelines.

## Actions

| Action | Description |
|---|---|
| [`generate`](generate/README.md) | Generate a Docker Compose file from one or more RemotiveTopology description files via the [RemotiveTopology CLI](https://docs.remotivelabs.com/docs/remotive-topology/usage). |
| [`sync-docs`](sync-docs/README.md) | Publish a versioned API-docs tarball from a source repo into the central docs repo (e.g. `remotivelabs/remotiveplatform-docs`), opening + auto-merging a PR. |

## Versioning

Pin via the `@v1` tag on this repo:

```yaml
- uses: remotivelabs/remotivelabs-topology-actions/generate@v1
- uses: remotivelabs/remotivelabs-topology-actions/sync-docs@v1
```

See each action's README for full input documentation and usage examples.
