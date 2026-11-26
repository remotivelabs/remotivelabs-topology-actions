# setup

Install the [RemotiveCLI](https://developer.remotivelabs.com/docs/remotive-cli) with the RemotiveLabs
Toolchain Manager, as `remotive` on the `PATH` of the steps that follow.

## Which version

As with the Toolchain Manager:

1. In a workspace, the version its `remotive.yaml` pins (`tools.cli.version`): the first workspace at
   or above `working-directory`. Nothing overrides it, `cli-version` neither.
2. Elsewhere, the default: `cli-version` when given, else the latest release on a runner with no
   RemotiveCLI installed yet. A runner that has one, such as a self-hosted runner, keeps its default:
   give `cli-version` to be sure.

The action ignores
[`requires-version`](https://developer.remotivelabs.com/apis/json/workspace#requires-version): the
RemotiveCLI checks it itself when it runs. Pin a version it allows in `tools.cli.version`.

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
the default is pinned in [`action.yml`](action.yml). Its install script checks the Toolchain Manager,
and the Toolchain Manager each RemotiveCLI, against signed checksums.

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
    # Exact RemotiveCLI version, the default outside a workspace. Empty: the latest release, on a runner with none yet.
    # Default: ""
    cli-version: ""
    # Where to look for remotive.yaml, at or above it.
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
