import base64
from dataclasses import asdict
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import urllib.error
import xml.etree.ElementTree as ET


SCRIPT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SCRIPT))
import generate_appcast as appcast
from release_build import source_commit, verify_source_commit
from release_metadata import metadata_for_tag


REPOSITORY = "https://github.com/frank4565/ClipMenu"
SIGNATURE = base64.b64encode(bytes(64)).decode()


def item(tag: str, signature: str = SIGNATURE) -> ET.Element:
    metadata = metadata_for_tag(tag)
    entry = ET.Element("item")
    ET.SubElement(entry, "title").text = f"ClipMenu {metadata.display_version}"
    ET.SubElement(entry, appcast.sparkle("version")).text = metadata.build_version
    if metadata.channel:
        ET.SubElement(entry, appcast.sparkle("channel")).text = metadata.channel
    ET.SubElement(entry, "enclosure", {
        "url": f"{REPOSITORY}/releases/download/{tag}/{metadata.archive_name}",
        "length": "100", "type": "application/octet-stream", appcast.sparkle("edSignature"): signature,
    })
    return entry


class MetadataTests(unittest.TestCase):
    def test_semantic_order_including_channel_transitions_and_component_rollover(self):
        tags = [
            "v0.4.3", "v0.5.0-beta.1", "v0.5.0-beta.49", "v0.5.0-rc.1", "v0.5.0-rc.49",
            "v0.5.0", "v0.5.1-beta.1", "v0.99.99", "v1.0.0-beta.1", "v1.0.0", "v99.98.99",
        ]
        builds = [appcast.version_key(metadata_for_tag(tag).build_version) for tag in tags]
        self.assertEqual(builds, sorted(builds))
        self.assertEqual(len(builds), len(set(builds)))
        for build in builds:
            self.assertTrue(1 <= build[0] <= 9999)
            self.assertTrue(all(0 <= component <= 99 for component in build[1:]))

    def test_apple_numeric_marketing_version_and_beta_channel(self):
        metadata = metadata_for_tag("v0.5.0-rc.2")
        self.assertEqual(metadata.marketing_version, "0.5.0")
        self.assertEqual(metadata.display_version, "0.5.0-rc.2")
        self.assertEqual(metadata.build_version, "6.0.51")
        self.assertEqual(metadata.channel, "beta")
        self.assertFalse(metadata_for_tag("v0.5.0").prerelease)
        self.assertEqual(metadata_for_tag("v0.4.3").build_version, "5.3.99")

    def test_unsupported_tags_fail_closed(self):
        for tag in ["0.5.0", "v0.5", "v00.5.0", "v0.5.0-beta.0", "v0.5.0-beta.50",
                    "v0.5.0-alpha.1", "v0.5.0+build", "v0.100.0", "v0.5.100", "v99.99.0",
                    "v0.5.0\n", "v0.5.0; echo unsafe"]:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                metadata_for_tag(tag)


class BuildProvenanceTests(unittest.TestCase):
    def git(self, repository, *arguments):
        return subprocess.check_output([
            "git", "-c", "core.hooksPath=/dev/null", "-c", "commit.gpgSign=false",
            "-c", "user.name=ClipMenu release test", "-c", "user.email=release-test@example.invalid",
            *arguments,
        ], cwd=repository, text=True).strip()

    def fixture(self, directory):
        repository = Path(directory)
        self.git(repository, "init", "--quiet")
        (repository / "source.txt").write_text("Committed release input\n")
        self.git(repository, "add", "source.txt")
        self.git(repository, "commit", "--quiet", "-m", "Initial fixture")
        return repository

    def test_production_rejects_dirty_tracked_files_but_dry_run_and_untracked_caches_are_allowed(self):
        with tempfile.TemporaryDirectory() as directory:
            repository = self.fixture(directory)
            initial = source_commit(repository, require_clean=True)
            (repository / "__pycache__").mkdir()
            (repository / "__pycache__/test.pyc").write_bytes(b"untracked test cache")
            self.assertEqual(source_commit(repository, require_clean=True), initial)
            (repository / "source.txt").write_text("Modified release input\n")
            for staged in (False, True):
                if staged:
                    self.git(repository, "add", "source.txt")
                with self.subTest(staged=staged), self.assertRaisesRegex(ValueError, "clean tracked files"):
                    source_commit(repository, require_clean=True)
                self.assertEqual(source_commit(repository, require_clean=False), initial)

    def test_a_commit_change_during_build_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            repository = self.fixture(directory)
            initial = source_commit(repository, require_clean=True)
            (repository / "source.txt").write_text("A subsequent committed input\n")
            self.git(repository, "add", "source.txt")
            self.git(repository, "commit", "--quiet", "-m", "Move HEAD")
            for require_clean in (False, True):
                with self.subTest(require_clean=require_clean), self.assertRaisesRegex(ValueError, "HEAD changed"):
                    verify_source_commit(initial, repository, require_clean=require_clean)


class AppcastTests(unittest.TestCase):
    def test_merging_preserves_both_channels_and_old_signatures(self):
        feed = appcast.parse_previous(None, REPOSITORY)
        stable = item("v0.5.0")
        beta = item("v0.6.0-beta.1", base64.b64encode(bytes([1]) * 64).decode())
        appcast.merge_item(feed, stable)
        appcast.merge_item(feed, beta)
        old_bytes = ET.tostring(feed)
        parsed = appcast.parse_previous(old_bytes, REPOSITORY)
        appcast.merge_item(parsed, item("v0.6.0"))
        entries = parsed.find("channel").findall("item")
        self.assertEqual([entry.findtext(appcast.sparkle("version")) for entry in entries],
                         ["7.0.99", "7.0.1", "6.0.99"])
        self.assertEqual(entries[1].find("enclosure").attrib, beta.find("enclosure").attrib)
        self.assertEqual(entries[2].find("enclosure").attrib, stable.find("enclosure").attrib)

    def test_duplicate_version_cannot_change_signed_archive(self):
        feed = appcast.parse_previous(None, REPOSITORY)
        original = item("v0.5.0")
        ET.SubElement(original, "pubDate").text = "Original publication date"
        appcast.merge_item(feed, original)
        appcast.merge_item(feed, item("v0.5.0"))
        self.assertEqual(len(feed.find("channel").findall("item")), 1)
        self.assertEqual(feed.find("channel/item/pubDate").text, "Original publication date")
        with self.assertRaisesRegex(ValueError, "cannot be replaced"):
            appcast.merge_item(feed, item("v0.5.0", base64.b64encode(bytes([2]) * 64).decode()))

    def test_only_a_404_bootstraps_an_empty_feed(self):
        for status in [403, 429, 500, 503]:
            error = urllib.error.HTTPError("https://example.com/appcast.xml", status, "failure", {}, None)
            with mock.patch.object(appcast.urllib.request, "urlopen", side_effect=error):
                with self.assertRaisesRegex(ValueError, "refusing to discard"):
                    appcast.read_previous_url("https://example.com/appcast.xml")
        error = urllib.error.HTTPError("https://example.com/appcast.xml", 404, "missing", {}, None)
        with mock.patch.object(appcast.urllib.request, "urlopen", side_effect=error):
            self.assertIsNone(appcast.read_previous_url("https://example.com/appcast.xml"))

    def test_invalid_previous_feed_is_not_silently_replaced(self):
        for body in [b"<html>Temporary outage</html>", b"<!DOCTYPE rss><rss><channel/></rss>",
                     b"<rss><channel/><channel/></rss>", b"not XML"]:
            with self.subTest(body=body), self.assertRaises((ValueError, ET.ParseError)):
                appcast.parse_previous(body, REPOSITORY)
        feed = appcast.parse_previous(None, REPOSITORY)
        entry = item("v0.5.0")
        entry.find("enclosure").set("url", "https://other.example.com/ClipMenu.zip")
        feed.find("channel").append(entry)
        with self.assertRaisesRegex(ValueError, "outside this repository"):
            appcast.parse_previous(ET.tostring(feed), REPOSITORY)

    def test_release_snapshot_recovers_a_missing_or_stale_pages_deployment(self):
        pages = appcast.parse_previous(None, REPOSITORY)
        appcast.merge_item(pages, item("v0.5.0"))
        snapshot = appcast.parse_previous(ET.tostring(pages), REPOSITORY)
        appcast.merge_item(snapshot, item("v0.6.0-beta.1"))
        for page_body in (None, ET.tostring(pages)):
            with self.subTest(page_body=page_body), \
                 mock.patch.object(appcast, "read_previous_url", return_value=page_body), \
                 mock.patch.object(appcast, "read_published_snapshot", return_value=ET.fromstring(ET.tostring(snapshot))):
                recovered = appcast.load_previous_feed("https://example.com/appcast.xml", REPOSITORY, False)
                self.assertEqual([entry.findtext(appcast.sparkle("version")) for entry in recovered.find("channel").findall("item")],
                                 ["7.0.1", "6.0.99"])

    def test_bootstrap_requires_explicit_permission_and_no_published_snapshot(self):
        with mock.patch.object(appcast, "read_previous_url", return_value=None), \
             mock.patch.object(appcast, "read_published_snapshot", return_value=None):
            with self.assertRaisesRegex(ValueError, "explicit first-release"):
                appcast.load_previous_feed("https://example.com/appcast.xml", REPOSITORY, False)
            feed = appcast.load_previous_feed("https://example.com/appcast.xml", REPOSITORY, True)
            self.assertEqual(feed.find("channel").findall("item"), [])

    def test_dry_run_cannot_create_a_publishable_feed(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            metadata = asdict(metadata_for_tag("v0.5.0")) | {"dry_run": True}
            source = directory / "build_info.json"
            source.write_text(json.dumps(metadata))
            result = subprocess.run([
                sys.executable, str(SCRIPT / "generate_appcast.py"), "--metadata", str(source),
                "--preview", "--output", str(directory / "appcast.xml"),
            ], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("must not be named appcast.xml", result.stderr)
            self.assertFalse((directory / "appcast.xml").exists())

    def test_release_notes_are_embedded_html_in_both_locales(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            archive = directory / "ClipMenu-v0.5.0-beta.1-UNSIGNED.zip"
            archive.write_bytes(b"preview fixture")
            metadata = asdict(metadata_for_tag("v0.5.0-beta.1")) | {
                "dry_run": True, "archive_name": archive.name, "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
                "repository_url": REPOSITORY, "minimum_system_version": "12.0.0",
            }
            source = directory / "build_info.json"
            source.write_text(json.dumps(metadata))
            output = directory / "appcast-preview.xml"
            subprocess.run([
                sys.executable, str(SCRIPT / "generate_appcast.py"), "--metadata", str(source),
                "--preview", "--output", str(output),
            ], check=True, capture_output=True, text=True)
            entry = ET.parse(output).find("channel/item")
            notes = {node.get(f"{{{appcast.XML}}}lang"): node.text for node in entry.findall("description")}
            self.assertEqual(set(notes), {"en", "ja"})
            self.assertIn("See the GitHub release", notes["en"])
            self.assertIn("詳しい変更内容", notes["ja"])
            self.assertIn("<!doctype html>", notes["en"])
            self.assertEqual(entry.findall(appcast.sparkle("releaseNotesLink")), [])
            self.assertEqual(entry.findtext(appcast.sparkle("fullReleaseNotesLink")),
                             REPOSITORY + "/releases/tag/v0.5.0-beta.1")


@unittest.skipUnless(sys.platform == "darwin" and os.environ.get("CLIPMENU_SPARKLE_TEST_TOOL"),
                     "Set CLIPMENU_SPARKLE_TEST_TOOL to the verified macOS sign_update binary.")
class SparkleSigningTests(unittest.TestCase):
    def test_official_signer_matches_embedded_public_key_and_rejects_another_key(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "fixture.zip"
            archive.write_bytes(b"A release signing test fixture; not an application.")
            public_key = subprocess.check_output([
                "xcrun", "swift", "-module-cache-path", str(Path(temporary) / "SwiftModuleCache"), "-e", 'import CryptoKit; import Foundation; '
                'print(try Curve25519.Signing.PrivateKey(rawRepresentation: Data(repeating: 0, count: 32))'
                '.publicKey.rawRepresentation.base64EncodedString())',
            ], text=True).strip()
            with mock.patch.dict(os.environ, {"SPARKLE_PRIVATE_KEY": base64.b64encode(bytes(32)).decode()}):
                signature = appcast.sign_archive(archive, Path(os.environ["CLIPMENU_SPARKLE_TEST_TOOL"]), public_key)
                self.assertEqual(len(base64.b64decode(signature)), 64)
                with self.assertRaisesRegex(ValueError, "does not match"):
                    appcast.sign_archive(archive, Path(os.environ["CLIPMENU_SPARKLE_TEST_TOOL"]), SIGNATURE[:43] + "=")


if __name__ == "__main__":
    unittest.main()
