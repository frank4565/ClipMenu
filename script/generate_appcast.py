#!/usr/bin/env python3
"""Sign an update with Sparkle 2 and merge it into the GitHub Pages appcast."""

from __future__ import annotations

import argparse
import base64
import binascii
from datetime import datetime, timezone
from email.utils import format_datetime
import hashlib
import html
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import uuid
import xml.etree.ElementTree as ET

from release_metadata import metadata_for_tag


ROOT = Path(__file__).resolve().parent.parent
SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
XML = "http://www.w3.org/XML/1998/namespace"
ET.register_namespace("sparkle", SPARKLE)
ET.register_namespace("xml", XML)
MAX_FEED_BYTES = 4 * 1024 * 1024


def sparkle(name: str) -> str:
    return f"{{{SPARKLE}}}{name}"


def require_https(url: str) -> str:
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("Release and feed URLs must be HTTPS URLs without credentials.")
    return url


def version_key(value: str) -> tuple[int, ...]:
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", value):
        raise ValueError(f"The appcast contains an unsupported build version: {value!r}.")
    components = tuple(int(part) for part in value.split("."))
    return components + (0,) * (3 - len(components))


def read_previous_url(url: str) -> bytes | None:
    # A fresh query avoids merging a cached Pages response after the last deploy.
    parsed = urllib.parse.urlsplit(require_https(url))
    query = urllib.parse.parse_qsl(parsed.query)
    query.append(("clipmenu_release", uuid.uuid4().hex))
    fresh_url = urllib.parse.urlunsplit(parsed._replace(query=urllib.parse.urlencode(query)))
    request = urllib.request.Request(fresh_url, headers={
        "User-Agent": "ClipMenu-release", "Cache-Control": "no-cache", "Accept": "application/rss+xml",
    })
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read(MAX_FEED_BYTES + 1)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None  # The first release bootstraps a new Pages site.
        raise ValueError(f"Previous appcast download returned HTTP {error.code}; refusing to discard it.") from error
    if len(body) > MAX_FEED_BYTES:
        raise ValueError("Previous appcast exceeds the 4 MiB limit.")
    return body


def parse_previous(body: bytes | None, repository_url: str) -> ET.Element:
    if body is None:
        rss = ET.Element("rss", {"version": "2.0"})
        channel = ET.SubElement(rss, "channel")
        ET.SubElement(channel, "title").text = "ClipMenu updates"
        ET.SubElement(channel, "link").text = repository_url
        ET.SubElement(channel, "description").text = "Signed ClipMenu releases for macOS."
        ET.SubElement(channel, "language").text = "en"
        return rss
    if len(body) > MAX_FEED_BYTES or b"<!DOCTYPE" in body.upper() or b"<!ENTITY" in body.upper():
        raise ValueError("Previous appcast contains unsupported XML declarations or is too large.")
    rss = ET.fromstring(body)
    if rss.tag != "rss" or len(rss.findall("channel")) != 1:
        raise ValueError("Previous appcast must contain one RSS channel.")
    seen_versions = set()
    for item in rss.find("channel").findall("item"):
        version = item.findtext(sparkle("version")) or ""
        version_key(version)
        if version in seen_versions:
            raise ValueError("Previous appcast contains duplicate build versions.")
        seen_versions.add(version)
        enclosure = item.find("enclosure")
        if enclosure is None:
            raise ValueError("Previous appcast item is missing its enclosure.")
        archive_url = require_https(enclosure.get("url", ""))
        if not archive_url.startswith(repository_url + "/releases/download/"):
            raise ValueError("Previous appcast points outside this repository's release assets.")
        try:
            signature = base64.b64decode(enclosure.get(sparkle("edSignature"), ""), validate=True)
            length = int(enclosure.get("length", "0"))
        except (ValueError, binascii.Error) as error:
            raise ValueError("Previous appcast contains an invalid archive signature or length.") from error
        if len(signature) != 64 or length <= 0:
            raise ValueError("Previous appcast contains an invalid archive signature or length.")
        if item.findtext(sparkle("channel"), "") not in ("", "beta"):
            raise ValueError("Previous appcast contains an unsupported update channel.")
    return rss


def read_published_snapshot(repository_url: str) -> ET.Element | None:
    repository = repository_url.removeprefix("https://github.com/")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Release history requires this GitHub repository's canonical HTTPS URL.")
    headers = {"User-Agent": "ClipMenu-release", "Accept": "application/vnd.github+json",
               "X-GitHub-Api-Version": "2022-11-28"}
    if os.environ.get("GH_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GH_TOKEN"]
    latest = None
    for page in range(1, 101):
        request = urllib.request.Request(
            f"https://api.github.com/repos/{repository}/releases?per_page=100&page={page}", headers=headers,
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            releases = json.load(response)
        if not isinstance(releases, list):
            raise ValueError("Could not inspect existing releases before bootstrapping the appcast.")
        for release in releases:
            if not release["draft"] and any(asset["name"] == "build_info.json" for asset in release["assets"]):
                if latest is None or release["published_at"] > latest["published_at"]:
                    latest = release
        if len(releases) < 100:
            break
    else:
        raise ValueError("Release history exceeds the inspection limit.")
    if latest is None:
        return None
    snapshots = [asset for asset in latest["assets"] if asset["name"] == "appcast.xml"]
    if len(snapshots) != 1:
        raise ValueError("The latest published update has no recoverable appcast snapshot; restore its feed before releasing.")
    tag = metadata_for_tag(latest["tag_name"]).tag
    expected_url = f"{repository_url}/releases/download/{tag}/appcast.xml"
    if snapshots[0]["browser_download_url"] != expected_url:
        raise ValueError("Published appcast snapshot is outside this repository's release assets.")
    request = urllib.request.Request(expected_url, headers={"User-Agent": "ClipMenu-release"})
    with urllib.request.urlopen(request, timeout=30) as response:
        body = response.read(MAX_FEED_BYTES + 1)
    return parse_previous(body, repository_url)


def load_previous_feed(url: str, repository_url: str, permit_bootstrap: bool) -> ET.Element:
    # Pages may lag a successful release or a failed deploy. The newest immutable
    # published snapshot carries every previously released channel/version.
    pages = parse_previous(read_previous_url(url), repository_url)
    published = read_published_snapshot(repository_url)
    if published is not None:
        for old_item in pages.find("channel").findall("item"):
            merge_item(published, old_item)
        return published
    if not pages.find("channel").findall("item") and not permit_bootstrap:
        raise ValueError("Missing/empty previous appcast requires an explicit first-release bootstrap.")
    return pages


def sign_archive(archive: Path, tool: Path, public_key: str) -> str:
    secret = os.environ.get("SPARKLE_PRIVATE_KEY", "").strip()
    try:
        decoded = base64.b64decode(secret, validate=True)
    except binascii.Error as error:
        raise ValueError("SPARKLE_PRIVATE_KEY must contain Sparkle's exported base64 private key.") from error
    if len(decoded) not in (32, 64, 96):
        raise ValueError("SPARKLE_PRIVATE_KEY has an unsupported key length.")
    # Sparkle may echo malformed keys in errors. Capture both streams and never forward them.
    result = subprocess.run(
        [str(tool), "--ed-key-file", "-", "-p", str(archive)],
        input=secret + "\n", text=True, capture_output=True, check=False,
    )
    if result.returncode or not re.fullmatch(r"[A-Za-z0-9+/]{86}==\s*", result.stdout):
        raise ValueError("Sparkle could not sign the archive; check SPARKLE_PRIVATE_KEY.")
    signature = result.stdout.strip()
    # A wrong key can sign successfully. Verify against SUPublicEDKey from the app.
    cache = ROOT / "build/SwiftModuleCache"
    cache.mkdir(parents=True, exist_ok=True)
    verification = subprocess.run([
        "xcrun", "swift", "-module-cache-path", str(cache), str(ROOT / "script/release_verify_signature.swift"),
        str(archive), signature, public_key,
    ], check=False)
    if verification.returncode:
        raise ValueError("The signing key does not match the app's embedded public key.")
    return signature


def merge_item(rss: ET.Element, item: ET.Element) -> None:
    channel = rss.find("channel")
    build_version = item.findtext(sparkle("version"))
    for old_item in channel.findall("item"):
        if old_item.findtext(sparkle("version")) == build_version:
            if old_item.find("enclosure").attrib != item.find("enclosure").attrib:
                raise ValueError("A published build version cannot be replaced with another archive.")
            return  # Leave the immutable version and its original notes/date intact.
    channel.append(item)
    items = channel.findall("item")
    for old_item in items:
        channel.remove(old_item)
    items.sort(key=lambda entry: version_key(entry.findtext(sparkle("version"))), reverse=True)
    channel.extend(items)


def write_notes(directory: Path, tag: str, display_version: str, repository_url: str) -> list[tuple[str, str]]:
    notes = []
    release_url = f"{repository_url}/releases/tag/{tag}"
    for language, title, message in (
        ("en", f"ClipMenu {display_version}", "See the GitHub release for the full change list."),
        ("ja", f"ClipMenu {display_version}", "詳しい変更内容は GitHub のリリースをご覧ください。"),
    ):
        name = f"ClipMenu-{tag}{'.ja' if language == 'ja' else ''}.html"
        source = ROOT / "doc/releases" / f"{tag}.{language}.html"
        content = source.read_text(encoding="utf-8") if source.is_file() else (
            f'<!doctype html><html lang="{language}"><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width, initial-scale=1">'
            '<style>body{font:14px -apple-system,sans-serif;padding:1rem;line-height:1.5}</style>'
            f"<title>{html.escape(title)}</title><h2>{html.escape(title)}</h2>"
            f'<p><a href="{html.escape(release_url)}">{html.escape(message)}</a></p></html>\n'
        )
        (directory / name).write_text(content, encoding="utf-8")
        notes.append((language, content))
    return notes


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metadata", type=Path, required=True, help="build_info.json from release_build.py")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--sign-update", type=Path)
    previous = parser.add_mutually_exclusive_group()
    previous.add_argument("--previous-url")
    previous.add_argument("--previous-file", type=Path)
    parser.add_argument("--preview", action="store_true", help="Create an unsigned local preview, never appcast.xml")
    parser.add_argument("--bootstrap-if-no-published-updates", action="store_true",
                        help="Permit an empty first feed only after checking GitHub release history")
    args = parser.parse_args()
    try:
        info = json.loads(args.metadata.read_text(encoding="utf-8"))
        metadata = metadata_for_tag(info["tag"])
        if info["build_version"] != metadata.build_version or info["marketing_version"] != metadata.marketing_version:
            raise ValueError("Build metadata does not match its release tag.")
        if bool(info["dry_run"]) != args.preview:
            raise ValueError("An unsigned dry-run archive requires --preview; signed releases forbid it.")
        if args.preview and args.output.name == "appcast.xml":
            raise ValueError("Unsigned previews must not be named appcast.xml.")
        repository_url = require_https(info["repository_url"])
        archive = args.metadata.parent / info["archive_name"]
        if hashlib.sha256(archive.read_bytes()).hexdigest() != info["sha256"]:
            raise ValueError("The archive has changed since packaging.")
        if not args.preview and not args.sign_update:
            raise ValueError("Signed appcasts require the pinned Sparkle sign_update tool.")
        signature = "" if args.preview else sign_archive(archive, args.sign_update.resolve(), info["public_key"])
        rss = load_previous_feed(args.previous_url, repository_url, args.bootstrap_if_no_published_updates) if args.previous_url else (
            parse_previous(args.previous_file.read_bytes() if args.previous_file else None, repository_url)
        )
        item = ET.Element("item")
        ET.SubElement(item, "title").text = f"ClipMenu {metadata.display_version}"
        ET.SubElement(item, "link").text = f"{repository_url}/releases/tag/{metadata.tag}"
        ET.SubElement(item, sparkle("version")).text = metadata.build_version
        ET.SubElement(item, sparkle("shortVersionString")).text = metadata.display_version
        ET.SubElement(item, sparkle("minimumSystemVersion")).text = info["minimum_system_version"]
        if metadata.channel:
            ET.SubElement(item, sparkle("channel")).text = metadata.channel
        ET.SubElement(item, "pubDate").text = format_datetime(datetime.now(timezone.utc))
        args.output.parent.mkdir(parents=True, exist_ok=True)
        notes = write_notes(args.metadata.parent, metadata.tag, metadata.display_version, repository_url)
        for language, content in notes:
            # GitHub serves release assets as octet-stream, which Sparkle's
            # WKWebView cannot display. Inline HTML also keeps past notes intact.
            ET.SubElement(item, "description", {f"{{{XML}}}lang": language}).text = content
        ET.SubElement(item, sparkle("fullReleaseNotesLink")).text = f"{repository_url}/releases/tag/{metadata.tag}"
        enclosure = {
            "url": f"{repository_url}/releases/download/{metadata.tag}/{info['archive_name']}",
            "length": str(archive.stat().st_size), "type": "application/octet-stream",
        }
        if signature:
            enclosure[sparkle("edSignature")] = signature
        ET.SubElement(item, "enclosure", enclosure)
        merge_item(rss, item)
        ET.indent(rss, space="  ")
        ET.ElementTree(rss).write(args.output, encoding="utf-8", xml_declaration=True)
        if not args.preview:
            (args.output.parent / "index.html").write_text(
                '<!doctype html><html lang="en"><meta charset="utf-8"><title>ClipMenu updates</title>'
                '<h1>ClipMenu updates</h1><p><a href="appcast.xml">Sparkle appcast</a></p>'
                f'<p><a href="{html.escape(repository_url)}/releases">Download ClipMenu</a></p></html>\n',
                encoding="utf-8",
            )
    except (ValueError, OSError, ET.ParseError, urllib.error.URLError) as error:
        parser.error(str(error))
    print(f"{'Unsigned preview' if args.preview else 'Signed appcast'}: {args.output}")


if __name__ == "__main__":
    main()
