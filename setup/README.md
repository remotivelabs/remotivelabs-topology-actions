# setup

Install the [RemotiveCLI](https://developer.remotivelabs.com/docs/remotive-cli) with the RemotiveLabs
Toolchain Manager, as `remotive` on the `PATH` of the steps that follow.

## Which version

The first that applies:

1. `cli-version`, when given. Outside a workspace that pins its version: inside one, the pin runs,
   and the action warns.
2. `tools.cli.version` in the workspace's `remotive.yaml`: the first workspace at or above
   `working-directory`.
3. The newest release the workspace's
   [`requires-version`](https://developer.remotivelabs.com/apis/json/workspace#requires-version)
   allows, such as `">=0.47,<1.0"`.
4. The latest release, on a runner with no RemotiveCLI installed yet.

A workspace that pins its version runs the same RemotiveCLI locally and in CI, from one place. A
workspace that gives a range with `requires-version` gets the newest release in it, which every
command in the workspace then accepts.

```yaml
# remotive.yaml
tools:
  cli:
    version: "0.49.1"
```

RemotiveBus is not installed: a CI runner has no CAN.

The Toolchain Manager's install script is checked against the checksum published beside it, so a
truncated download never runs. The RemotiveCLI it installs is checked against signed checksums.

## Usage

```yaml
- uses: remotivelabs/remotivelabs-topology-actions/setup@v1
  with:
    # Exact RemotiveCLI version. Empty: the workspace's pin, else the newest release its
    # requires-version allows, else the latest release.
    # Default: ""
    cli-version: ""
    # Where to look for remotive.yaml when cli-version is empty.
    # Default: .
    working-directory: ""
```

The version that runs is the output `cli-version`.

## Example

Run commands that need RemotiveCloud as a service account:

```yaml
- uses: remotivelabs/remotivelabs-topology-actions/setup@v1

- run: remotive topology generate -f topology/main.instance.yaml build
  env:
    REMOTIVE_CLOUD_AUTH_TOKEN: ${{ secrets.MY_RL_TOKEN }}
    REMOTIVE_CLOUD_ORGANIZATION: ${{ secrets.MY_RL_ORG }}
```
