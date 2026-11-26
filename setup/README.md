# setup

Install the [RemotiveCLI](https://developer.remotivelabs.com/docs/remotive-cli) with the RemotiveLabs
Toolchain Manager, as `remotive` on the `PATH` of the steps that follow.

## Which version

The first that applies:

1. `cli-version`, when given. Inside a workspace that pins another version, the pin runs there.
2. `tools.cli.version` in the workspace's `remotive.yaml`: the first workspace at or above
   `working-directory`.
3. The latest release.

The action ignores
[`requires-version`](https://developer.remotivelabs.com/apis/json/workspace#requires-version): the
RemotiveCLI checks it itself when it runs. Give `cli-version` or `tools.cli.version` to choose a
version it allows.

The Toolchain Manager installs RemotiveCLI 0.45.5 and later. If the version cannot be installed, the
step fails.

```yaml
# remotive.yaml
tools:
  cli:
    version: "0.49.1"
```

RemotiveBus is not installed: a CI runner has no CAN.

## Toolchain Manager

The action installs the Toolchain Manager version `toolchain-manager-version` gives, 0.0.18 or newer;
the default is pinned in [`action.yml`](action.yml). Its install script is checked against the
checksum published beside it, which only catches a broken download; the script then checks the
Toolchain Manager, and the Toolchain Manager each RemotiveCLI, against signed checksums.

To move the pin (Dependabot cannot):

1. Read the latest version from
   `https://files.remotivelabs.com/remotive-toolchain-manager/latest/latest-version.txt`.
2. Set it as the default in `action.yml`, in the usage below and in
   [`test_setup.yaml`](../.github/workflows/test_setup.yaml).
3. Open a pull request: its CI installs it on Linux and macOS.

## Usage

```yaml
- uses: remotivelabs/remotivelabs-topology-actions/setup@<commit-sha>
  with:
    # Exact RemotiveCLI version. Empty: the workspace's pin, else the latest release.
    # Default: ""
    cli-version: ""
    # Where to look for remotive.yaml when cli-version is empty.
    # Default: .
    working-directory: ""
    # Exact Toolchain Manager version, 0.0.18 or newer; not empty.
    # Default: the version action.yml pins
    toolchain-manager-version: "0.0.18"
```

The version that runs is the output `cli-version`.

## Example

With [`auth`](../auth/README.md) and [`build`](../build/README.md):

```yaml
- uses: remotivelabs/remotivelabs-topology-actions/setup@<commit-sha>
- uses: remotivelabs/remotivelabs-topology-actions/auth@<commit-sha>
  with:
    auth_token: ${{ secrets.MY_RL_TOKEN }}
    organization: ${{ secrets.MY_RL_ORG }}
- run: remotive topology version
```
