# build

Build a [RemotiveTopology](https://developer.remotivelabs.com/docs/remotive-topology) environment, a
Docker Compose project, from one or more instance files, with `remotive topology build`. It
replaces [`generate`](../generate/README.md).

It needs the RemotiveCLI ([`setup`](../setup/README.md)) and a RemotiveCloud account
([`auth`](../auth/README.md)) first, and runs in a RemotiveTopology workspace: a directory with a
`remotive.yaml`, at or above `working-directory`, made with `remotive topology workspace init`. The
topology is built as the runner's user, so the job can
change or remove what is built.

## Usage

```yaml
- uses: remotivelabs/remotivelabs-topology-actions/build@<commit-sha>
  with:
    # Newline or space separated instance files, applied in order, relative to working-directory.
    # Required
    files: ""
    # Name of the topology, when the instance files do not name it.
    # Default: ""
    name: ""
    # Directory the topology is built in, as <output>/<name>, relative to working-directory.
    # Default: build
    output: ""
    # Add Prometheus and Grafana to the topology.
    # Default: false
    with-metrics: ""
    # Where to run the build; the workspace is the first remotive.yaml at or above it.
    # Default: .
    working-directory: ""
```

The directory the topology was built in is the output `path`.

## Example

```yaml
- uses: remotivelabs/remotivelabs-topology-actions/setup@<commit-sha>
- uses: remotivelabs/remotivelabs-topology-actions/auth@<commit-sha>
  with:
    auth_token: ${{ secrets.MY_RL_TOKEN }}
    organization: ${{ secrets.MY_RL_ORG }}
- uses: remotivelabs/remotivelabs-topology-actions/build@<commit-sha>
  id: topology
  with:
    files: |
      topology/main.instance.yaml
      topology/overlay.instance.yaml
- run: docker compose -f "${{ steps.topology.outputs.path }}/docker-compose.yml" up -d
```

## From generate

| `generate` | `build` |
|---|---|
| `version` (RemotiveTopology image) | the RemotiveCLI's version, `setup`'s `cli-version` or the workspace's pin; the CLI picks the RemotiveTopology it was released with |
| `path` | `files` |
| `name`, `output` | the same |
| `organization`, `auth_token` | the `auth` action |
