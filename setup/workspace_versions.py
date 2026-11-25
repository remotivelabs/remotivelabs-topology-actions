"""The released RemotiveCLI versions a workspace's `requires-version` allows, for the setup action.

Prints them newest first, space separated; nothing when there is no workspace, or it has no
`requires-version`. A workspace that pins its version (`tools.cli.version`) is the Toolchain
Manager's to read, before this runs.

Usage: python3 workspace_versions.py <directory>
"""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.request
from collections.abc import Callable
from pathlib import Path

RELEASES = "https://pypi.org/pypi/remotivelabs-cli/json"
# Top-level keys only: an indented one belongs to another mapping
REQUIRES_VERSION = re.compile(r"""^(["']?)requires-version\1[ \t]*:[ \t]*(.*?)[ \t]*(?:#.*)?$""", re.MULTILINE)


def main(start: Path) -> None:
    marker = _workspace_marker(start)
    if marker is None:
        return
    written = _requires_version(marker.read_text(encoding="utf-8"), marker)
    if written is None:
        return
    exact = EXACT.match(written)
    if exact and not RELEASE.match(exact[1]):
        # One pre-release or post-release, asked for exactly: install it as it is
        print(exact[1])
        return
    try:
        allowed = _specifier(written)
    except InvalidSpecifier:
        sys.exit(f'requires-version {written!r} in {marker} is not a version or a range, such as ">=0.47,<1.0"')
    versions = sorted((v for v in _released() if allowed(_release(v))), key=_release, reverse=True)
    if not versions:
        sys.exit(f"no released RemotiveCLI version satisfies requires-version {written!r} in {marker}")
    print(" ".join(versions))


def _requires_version(text: str, marker: Path) -> str | None:
    """The top-level `requires-version`: on its line, or as a block scalar (`>-`, `|`) on the lines after it.

    The RemotiveCLI reads the file as YAML. A form read here differently, such as a flow mapping, is
    refused rather than taken for no `requires-version`, so no version outside the range is installed.
    """
    lines = text.splitlines()
    value = None
    for number, line in enumerate(lines):
        found = REQUIRES_VERSION.match(line)
        if found is None:
            continue
        value = found[2]
        if value[:1] in (">", "|") and not BLOCK_SCALAR.match(value):
            sys.exit(
                f"requires-version {value} in {marker} must be quoted, as YAML reads > and | as the start of a block"
            )
        if BLOCK_SCALAR.match(value):
            block = []
            for following in lines[number + 1 :]:
                if following.strip() and not following[:1].isspace():
                    break
                block.append(following.strip())
            value = " ".join(part for part in block if part)
    if value is not None:
        # The last one, as a YAML reader takes a key written twice. Empty or null is no requirement.
        value = value.strip().strip("\"'").strip()
        return None if value in ("", "~", "null", "Null", "NULL") else value
    if any(ANY_REQUIRES_VERSION.match(line) for line in lines):
        sys.exit(
            f"requires-version in {marker} is not a top-level key on a line of its own: "
            'write it as requires-version: ">=0.47,<1.0"'
        )
    return None


def _workspace_marker(start: Path) -> Path | None:
    """The workspace's remotive.yaml: the one REMOTIVE_TOPOLOGY_WORKSPACE names, else the first at or above `start`."""
    named = os.environ.get("REMOTIVE_TOPOLOGY_WORKSPACE")
    if named and (Path(named) / "remotive.yaml").is_file():
        return Path(named) / "remotive.yaml"
    for directory in [start.resolve(), *start.resolve().parents]:
        if (directory / "remotive.yaml").is_file():
            return directory / "remotive.yaml"
    return None


# A final release, as `requires-version` picks among them: a pre-release is only ever asked for exactly
RELEASE = re.compile(r"^\d+(\.\d+)*$")
# `requires-version` as a key anywhere, also indented or in a flow mapping; not in a comment
ANY_REQUIRES_VERSION = re.compile(r"""^[^#]*?[\s{,]?["']?requires-version["']?\s*:""")
# The header of a block scalar, the value on the lines after it; `>=0.47` unquoted is not one
BLOCK_SCALAR = re.compile(r"^[>|][-+0-9]*$")
# One version, bare or with ==, of the characters a version is written with
EXACT = re.compile(r"^(?:==\s*)?([0-9][0-9A-Za-z.+!-]*)$")
CLAUSE = re.compile(r"^(~=|===|==|!=|<=|>=|<|>)?\s*(\d+(?:\.\d+)*)(\.\*)?$")


class InvalidSpecifier(ValueError):
    pass


def _release(text: str) -> tuple[int, ...]:
    return tuple(int(part) for part in text.split("."))


def _padded(a: tuple[int, ...], b: tuple[int, ...]) -> tuple[tuple[int, ...], tuple[int, ...]]:
    width = max(len(a), len(b))
    return a + (0,) * (width - len(a)), b + (0,) * (width - len(b))


def _specifier(text: str) -> Callable[[tuple[int, ...]], bool]:
    """`requires-version` as the CLI reads it, PEP 440: one version, or comma-separated clauses."""
    clauses = []
    for clause in (c.strip() for c in text.split(",")):
        if not clause:
            continue
        found = CLAUSE.match(clause)
        if found is None:
            raise InvalidSpecifier(text)
        op, version, wildcard = found[1] or "==", _release(found[2]), bool(found[3])
        if (wildcard and op not in ("==", "!=")) or (op == "~=" and len(version) < 2):
            raise InvalidSpecifier(text)
        clauses.append((op, version, wildcard))

    def allows(candidate: tuple[int, ...]) -> bool:
        return all(_satisfies(candidate, op, version, wildcard) for op, version, wildcard in clauses)

    return allows


def _satisfies(candidate: tuple[int, ...], op: str, version: tuple[int, ...], wildcard: bool) -> bool:
    if wildcard:
        prefix = candidate[: len(version)] + (0,) * max(0, len(version) - len(candidate))
        return (prefix == version) == (op == "==")
    if op == "~=":
        return _satisfies(candidate, ">=", version, False) and _satisfies(candidate, "==", version[:-1], True)
    left, right = _padded(candidate, version)
    return {
        "==": left == right,
        "===": candidate == version,
        "!=": left != right,
        "<=": left <= right,
        ">=": left >= right,
        "<": left < right,
        ">": left > right,
    }[op]


def _released() -> list[str]:
    with urllib.request.urlopen(RELEASES, timeout=30) as answer:
        releases = json.load(answer)["releases"]
    return [
        name
        for name, files in releases.items()
        if RELEASE.match(name) and files and not all(f.get("yanked") for f in files)
    ]


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else "."))
