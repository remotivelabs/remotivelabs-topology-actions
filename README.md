# RemotiveTopology actions

This repository contains several actions that allows you to work with [RemotiveTopology](https://docs.remotivelabs.com/docs/remotive-topology) using the [RemotiveTopology CLI tool](https://docs.remotivelabs.com/docs/remotive-topology/usage).

## Usage

### topology generate v1 action

```yaml
- uses: remotivelabs/remotivelabs-topology-actions/generate@v1
  with:
    # remotive-topology CLI version to use.
    # See https://hub.docker.com/r/remotivelabs/remotive-topology/tags
    # Default: latest
    version: ""
    # Optional name of the generated topology. Only needed if the topology instance file have the name property undefined.
    name: ""
    # Newline or space separated paths to topology description files, relative the workspace root.
    # Required
    path: ""
    # Optional path to the output directory, relative the workspace root
    # Default: build
    output: ""
    # RemotiveCloud organization.
    #See https://docs.remotivelabs.com/docs/remotive-topology/install#using-remotivetopology-in-a-ci-environment
    # Required
    organization: ""
    # RemotiveCloud authentication token
    # See https://docs.remotivelabs.com/docs/remotive-topology/install#using-remotivetopology-in-a-ci-environment
    # Required
    auth_token: ""
```

## Example

Generate a topology from a topology description

```yaml
- uses: remotivelabs/remotivelabs-topology-actions/generate@v1
  with:
    path: |
      topology/main.instance.yaml
      topology/overlay.instance.yaml
    organization: ${{ secrets.MY_RL_ORG }}
    auth_token: ${{ secrets.MY_RL_TOKEN }}
```
