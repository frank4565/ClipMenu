#!/usr/bin/env python3
"""Derive Apple's bundle versions and Sparkle's channel from a release tag."""

import argparse
from dataclasses import asdict, dataclass
import json
from pathlib import Path
import re


TAG_PATTERN = re.compile(
    r"v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    r"(?:-(beta|rc)\.([1-9]\d*))?\Z"
)


@dataclass(frozen=True)
class ReleaseMetadata:
    tag: str
    marketing_version: str
    display_version: str
    build_version: str
    channel: str
    prerelease: bool
    archive_name: str


def metadata_for_tag(tag: str) -> ReleaseMetadata:
    match = TAG_PATTERN.fullmatch(tag)
    if not match:
        raise ValueError("Use vX.Y.Z, vX.Y.Z-beta.N, or vX.Y.Z-rc.N (no leading zeros).")
    major, minor, patch = (int(value) for value in match.group(1, 2, 3))
    stage, iteration_text = match.group(4, 5)
    # Preserve semantic ordering within Apple's conservative 4.2.2 digit limits.
    first = major * 100 + minor + 1
    if minor > 99 or patch > 99 or first > 9999:
        raise ValueError("Versions require minor/patch <= 99 and major*100+minor+1 <= 9999.")
    iteration = int(iteration_text or 0)
    if stage and iteration > 49:
        raise ValueError("Each beta or rc series supports iterations 1 through 49.")
    rank = iteration if stage == "beta" else 49 + iteration if stage == "rc" else 99
    return ReleaseMetadata(
        tag=tag,
        marketing_version=f"{major}.{minor}.{patch}",
        display_version=tag[1:],
        build_version=f"{first}.{patch}.{rank}",
        channel="beta" if stage else "",
        prerelease=bool(stage),
        archive_name=f"ClipMenu-{tag}.zip",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag")
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()
    try:
        metadata = asdict(metadata_for_tag(args.tag))
    except ValueError as error:
        parser.error(str(error))
    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as output:
            for key, value in metadata.items():
                output.write(f"{key}={str(value).lower() if isinstance(value, bool) else value}\n")
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
