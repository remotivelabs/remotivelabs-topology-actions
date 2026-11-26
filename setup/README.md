# setup

Install the [RemotiveCLI](https://developer.remotivelabs.com/docs/remotive-cli) with the RemotiveLabs
Toolchain Manager, as `remotive` on the `PATH` of the steps that follow.

## Which version

As with the Toolchain Manager:

1. In a workspace, the version its `remotive.yaml` pins (`tools.cli.version`): the first workspace at
   or above `working-directory`. Nothing overrides it, `cli-version` neither.
2. Elsewhere, the default: `cli-version` when given, else the latest release.

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

## RemotiveBus

RemotiveBus is not installed unless `remotivebus` is `true`. A topology whose CAN channels use
RemotiveBus, the default CAN driver, needs it; one that uses
[UDP emulation](https://developer.remotivelabs.com/docs/remotive-topology/usage/channels/can#emulation-using-udp)
does not.

```yaml
- uses: remotivelabs/remotivelabs-topology-actions/setup@<commit-sha>
  with:
    remotivebus: true
```

The action loads the CAN kernel modules RemotiveBus needs (`vcan`, `vxcan`, `can-gw`), installing
`linux-modules-extra` for the running kernel when they are missing, then installs RemotiveBus with
the Toolchain Manager: `remotivebus-version`, else the latest. It needs Linux and sudo, as on
GitHub-hosted Ubuntu runners; on macOS the step fails.

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
    # Exact RemotiveCLI version, the default outside a workspace. Empty: the latest release.
    # Default: ""
    cli-version: ""
    # Where to look for remotive.yaml, at or above it.
    # Default: .
    working-directory: ""
    # Exact Toolchain Manager version, 0.0.18 or newer; not empty.
    # Default: the version action.yml pins
    toolchain-manager-version: "0.0.18"
    # true: also install RemotiveBus and load the CAN kernel modules. Linux only.
    # Default: false
    remotivebus: false
    # Exact RemotiveBus version when remotivebus is true. Empty: the latest.
    # Default: ""
    remotivebus-version: ""
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
