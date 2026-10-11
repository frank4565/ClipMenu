#!/usr/bin/env python3
"""Publish immutable GitHub release assets before GitHub Pages advertises them."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

from generate_appcast import parse_previous, sparkle, version_key
from release_metadata import metadata_for_tag


ROOT = Path(__file__).resolve().parent.parent


def release_notes_options(tag: str, repository: Path) -> list[str]:
    metadata_for_tag(tag)
    notes = repository / "doc/releases" / f"{tag}.md"
    if not notes.exists():
        return ["--generate-notes"]
    # Validate the exact tag's source without rewriting its Markdown or newlines.
    notes.read_text(encoding="utf-8")
    return ["--notes-file", str(notes)]


def gh(arguments: list[str], repository: str) -> None:
    subprocess.run(["gh", "release", *arguments, "--repo", repository], check=True)


def lookup_release(repository: str, tag: str) -> dict | None:
    token = os.environ.get("GH_TOKEN")
    if not token:
        raise ValueError("GH_TOKEN is required to publish a release.")
    request = urllib.request.Request(
        f"https://api.github.com/repos/{repository}/releases/tags/{tag}",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json",
                 "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "ClipMenu-release"},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise


def verify_public_archive(url: str, expected_digest: str) -> None:
    for attempt in range(6):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "ClipMenu-release"})
            with urllib.request.urlopen(request, timeout=30) as response:
                digest = hashlib.sha256()
                while chunk := response.read(1024 * 1024):
                    digest.update(chunk)
            if digest.hexdigest() != expected_digest:
                raise ValueError("The public GitHub release archive does not match the signed build.")
            return
        except urllib.error.HTTPError as error:
            if error.code != 404 or attempt == 5:
                raise
            time.sleep(2)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=Path("build/release"))
    args = parser.parse_args()
    try:
        directory = args.directory.resolve()
        info = json.loads((directory / "build_info.json").read_text(encoding="utf-8"))
        metadata = metadata_for_tag(info["tag"])
        if info["dry_run"] or info["archive_name"] != metadata.archive_name:
            raise ValueError("Unsigned dry runs cannot be published.")
        repository = info["repository_url"].removeprefix("https://github.com/")
        if repository != os.environ.get("GITHUB_REPOSITORY"):
            raise ValueError("The build must belong to the workflow's GitHub repository.")
        tagged_commit = subprocess.check_output(["git", "rev-parse", f"refs/tags/{metadata.tag}^{{commit}}"], text=True).strip()
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
        if tagged_commit != head or info["build_commit"] != head:
            raise ValueError("The release tag, checked-out commit, and archive's built commit must match.")
        archive = directory / metadata.archive_name
        if hashlib.sha256(archive.read_bytes()).hexdigest() != info["sha256"]:
            raise ValueError("The packaged archive changed before publication.")
        feed = parse_previous((directory / "site/appcast.xml").read_bytes(), info["repository_url"])
        matching = [item for item in feed.find("channel").findall("item")
                    if item.findtext(sparkle("version")) == metadata.build_version]
        if len(matching) != 1 or matching[0].find("enclosure").get("length") != str(archive.stat().st_size):
            raise ValueError("The appcast does not describe this signed archive.")
        assets = [archive, directory / "SHA256SUMS.txt", directory / "build_info.json", directory / "site/appcast.xml",
                  directory / f"ClipMenu-{metadata.tag}.html", directory / f"ClipMenu-{metadata.tag}.ja.html"]
        stable_builds = [version_key(item.findtext(sparkle("version"))) for item in feed.find("channel").findall("item")
                         if not item.findtext(sparkle("channel"))]
        is_latest = not metadata.prerelease and version_key(metadata.build_version) == max(stable_builds)
        existing = lookup_release(repository, metadata.tag)
        if existing is None:
            options = ["create", metadata.tag, *(str(asset) for asset in assets), "--verify-tag", "--draft",
                       "--title", f"ClipMenu {metadata.display_version}",
                       *release_notes_options(metadata.tag, ROOT)]
            if metadata.prerelease:
                options.append("--prerelease")
            gh(options, repository)
        else:
            existing_assets = {asset["name"]: asset for asset in existing["assets"]}
            with tempfile.TemporaryDirectory(prefix="clipmenu-published-") as temporary:
                for asset in assets:
                    if asset.name == "appcast.xml" and not existing["draft"] and asset.name in existing_assets:
                        # Keep this release's original snapshot immutable. A retry
                        # can reconcile newer releases into the Pages artifact.
                        continue
                    if asset.name not in existing_assets:
                        if not existing["draft"]:
                            raise ValueError("Published releases cannot gain or replace assets; use a new version tag.")
                        gh(["upload", metadata.tag, str(asset)], repository)
                        continue
                    gh(["download", metadata.tag, "--pattern", asset.name, "--dir", temporary], repository)
                    downloaded = Path(temporary) / asset.name
                    if hashlib.sha256(downloaded.read_bytes()).digest() != hashlib.sha256(asset.read_bytes()).digest():
                        raise ValueError("A release asset already exists with different bytes; use a new version tag.")
        if existing is None or existing["draft"]:
            gh(["edit", metadata.tag, "--draft=false", f"--prerelease={'true' if metadata.prerelease else 'false'}",
                f"--latest={'true' if is_latest else 'false'}"], repository)
        url = f"{info['repository_url']}/releases/download/{metadata.tag}/{metadata.archive_name}"
        verify_public_archive(url, info["sha256"])
    except (ValueError, OSError, subprocess.CalledProcessError, urllib.error.URLError) as error:
        parser.error(str(error))
    print(f"Verified public release archive: {url}")


if __name__ == "__main__":
    main()
