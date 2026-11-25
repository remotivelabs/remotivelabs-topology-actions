# auth

Make a RemotiveCloud service account the account of the job's later steps, the way the cloud
providers' auth actions do: the secrets are inputs, named in one place in the workflow. The
RemotiveCLI, RemotiveTopology and the brokers a topology starts then run as that account.

It sets `REMOTIVE_CLOUD_AUTH_TOKEN`, `REMOTIVE_CLOUD_ORGANIZATION` and, when given,
`REMOTIVE_CLOUD_PROJECT` for the later steps of the job, with the token masked in the log. When the
RemotiveCLI is installed ([`setup`](../setup/README.md) first), it checks the token with
`remotive auth whoami`, so a token RemotiveCloud refuses fails here and not in a later step.

Create a service account and its token with `remotive auth service-accounts create --it`, as
[RemotiveTopology in CI](https://developer.remotivelabs.com/docs/remotive-topology/usage/ci) shows.
To build and run a topology, the account needs the RemotiveTopology Executor role
(`org/topologyRunner`).

## Usage

```yaml
- uses: remotivelabs/remotivelabs-topology-actions/auth@v1
  with:
    # A RemotiveCloud service-account access token.
    # Required
    auth_token: ""
    # The RemotiveCloud organization the account acts in.
    # Required
    organization: ""
    # The RemotiveCloud project, for commands that act in one.
    # Default: ""
    project: ""
```

A secret that is not set, as in a pull request from a fork, is empty: the action then fails, saying
so.

Pass the token from a secret. A token from another step's output must be masked by that step
(`echo "::add-mask::$TOKEN"`) before it is given here: a step's log lists its inputs before the step
runs, and only a masked value is hidden there.

`remotive setup` is for a person at a terminal and does not run in CI; this action and
[`setup`](../setup/README.md) are what it does there.
