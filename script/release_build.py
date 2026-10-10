#!/usr/bin/env python3
"""Build a universal Developer ID release, notarize/staple it, then package it."""

import argparse
import base64
from contextlib import contextmanager
from dataclasses import asdict
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import shlex
import subprocess
import tempfile

from generate_appcast import require_https
from release_metadata import metadata_for_tag


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_FEED = "https://frank4565.github.io/ClipMenu/appcast.xml"
SIGNING_SECRETS = (
    "DEVELOPER_ID_CERTIFICATE_P12_BASE64", "DEVELOPER_ID_CERTIFICATE_PASSWORD",
    "APPLE_NOTARY_KEY_P8_BASE64", "APPLE_NOTARY_KEY_ID", "APPLE_NOTARY_ISSUER_ID",
)


def run(arguments: list[str], *, capture: bool = False) -> subprocess.CompletedProcess:
    return subprocess.run(arguments, check=True, text=True, capture_output=capture)


def source_commit(repository: Path, *, require_clean: bool) -> str:
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repository, text=True).strip()
    if require_clean:
        state = subprocess.run(["git", "diff", "--quiet", "HEAD", "--"], cwd=repository, capture_output=True)
        if state.returncode == 1:
            raise ValueError("Production releases require clean tracked files; commit changes or use --dry-run.")
        if state.returncode:
            raise ValueError("Could not inspect the release's tracked source files.")
    return commit


def verify_source_commit(expected: str, repository: Path, *, require_clean: bool) -> None:
    if source_commit(repository, require_clean=require_clean) != expected:
        raise ValueError("HEAD changed during the release build; use a fresh release attempt.")


def secret_run(arguments: list[str]) -> subprocess.CompletedProcess:
    # security import requires a password argument. Never print its command/output.
    result = subprocess.run(arguments, text=True, capture_output=True, check=False)
    if result.returncode:
        raise ValueError("Could not configure the temporary signing keychain. Check the certificate credentials.")
    return result


@contextmanager
def signing_credentials():
    missing = [name for name in SIGNING_SECRETS if not os.environ.get(name)]
    if missing:
        raise ValueError("Missing release secrets: " + ", ".join(missing))
    team = os.environ.get("APPLE_TEAM_ID", "")
    if not re.fullmatch(r"[A-Z0-9]{10}", team):
        raise ValueError("APPLE_TEAM_ID must be your 10-character Developer ID team identifier.")
    if not re.fullmatch(r"[A-Z0-9]{10}", os.environ["APPLE_NOTARY_KEY_ID"]):
        raise ValueError("APPLE_NOTARY_KEY_ID must be the 10-character App Store Connect API key ID.")
    if not re.fullmatch(r"[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}", os.environ["APPLE_NOTARY_ISSUER_ID"]):
        raise ValueError("APPLE_NOTARY_ISSUER_ID must be the App Store Connect team API issuer UUID.")
    previous_keychains = shlex.split(run(["security", "list-keychains", "-d", "user"], capture=True).stdout)
    with tempfile.TemporaryDirectory(prefix="clipmenu-signing-", dir=os.environ.get("RUNNER_TEMP")) as directory:
        credential_directory = Path(directory)
        keychain = credential_directory / "release.keychain-db"
        certificate = credential_directory / "certificate.p12"
        notary_key = credential_directory / "notary.p8"
        try:
            certificate.write_bytes(base64.b64decode("".join(os.environ["DEVELOPER_ID_CERTIFICATE_P12_BASE64"].split()), validate=True))
            notary_key.write_bytes(base64.b64decode("".join(os.environ["APPLE_NOTARY_KEY_P8_BASE64"].split()), validate=True))
        except ValueError as error:
            raise ValueError("Certificate and notary-key secrets must be base64 encoded file contents.") from error
        certificate.chmod(0o600)
        notary_key.chmod(0o600)
        if b"-----BEGIN PRIVATE KEY-----" not in notary_key.read_bytes():
            raise ValueError("APPLE_NOTARY_KEY_P8_BASE64 must encode an App Store Connect API .p8 private key.")
        password = secrets.token_urlsafe(32)
        created = False
        try:
            secret_run(["security", "create-keychain", "-p", password, str(keychain)])
            created = True
            secret_run(["security", "set-keychain-settings", "-lut", "21600", str(keychain)])
            secret_run(["security", "unlock-keychain", "-p", password, str(keychain)])
            secret_run([
                "security", "import", str(certificate), "-P", os.environ["DEVELOPER_ID_CERTIFICATE_PASSWORD"],
                "-t", "cert", "-f", "pkcs12", "-k", str(keychain),
                "-T", "/usr/bin/codesign", "-T", "/usr/bin/security",
            ])
            secret_run([
                "security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:",
                "-s", "-k", password, str(keychain),
            ])
            secret_run(["security", "list-keychains", "-d", "user", "-s", str(keychain), *previous_keychains])
            identities = secret_run(["security", "find-identity", "-v", "-p", "codesigning", str(keychain)]).stdout
            matches = re.findall(r'\b([A-Fa-f0-9]{40})\s+"Developer ID Application: [^"\n]+ \(' + re.escape(team) + r'\)"', identities)
            if len(matches) != 1:
                raise ValueError("The certificate must contain exactly one valid Developer ID Application identity for APPLE_TEAM_ID.")
            yield matches[0], team, notary_key
        finally:
            if created:
                # Restore the runner's original search list even after a failed build.
                subprocess.run(["security", "list-keychains", "-d", "user", "-s", *previous_keychains], capture_output=True)
                subprocess.run(["security", "delete-keychain", str(keychain)], capture_output=True)


def validate_app(app: Path, metadata, feed_url: str, public_key: str, dry_run: bool) -> dict:
    with (app / "Contents/Info.plist").open("rb") as source:
        info = plistlib.load(source)
    expected = {
        "CFBundleIdentifier": "com.naotaka.ClipMenu", "CFBundleVersion": metadata.build_version,
        "CFBundleShortVersionString": metadata.marketing_version, "SUFeedURL": feed_url,
        "SUPublicEDKey": public_key,
    }
    for key, value in expected.items():
        if info.get(key) != value:
            raise ValueError(f"The exported app's {key} does not match the release configuration.")
    if not dry_run:
        try:
            decoded = base64.b64decode(public_key, validate=True)
        except ValueError as error:
            raise ValueError("CLIPMENU_SPARKLE_PUBLIC_KEY must be the base64 public Ed25519 key.") from error
        if len(decoded) != 32:
            raise ValueError("CLIPMENU_SPARKLE_PUBLIC_KEY must decode to exactly 32 bytes.")
    executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
    architectures = run(["lipo", "-archs", str(executable)], capture=True).stdout.split()
    if set(architectures) != {"arm64", "x86_64"}:
        raise ValueError("Release app must contain both arm64 and x86_64 architectures.")
    minimum = str(info.get("LSMinimumSystemVersion", ""))
    if not re.fullmatch(r"\d+(?:\.\d+){0,2}", minimum) or int(minimum.split(".")[0]) < 12:
        raise ValueError("Sparkle 2.10 requires a minimum deployment target of macOS 12.")
    info["release_minimum_system_version"] = ".".join((minimum.split(".") + ["0", "0"])[:3])
    return info


def verify_signed_app(app: Path) -> None:
    run(["codesign", "--verify", "--deep", "--strict", "--verbose=2", str(app)])
    details = subprocess.run(["codesign", "--display", "--verbose=4", str(app)], text=True, capture_output=True, check=True)
    if "runtime" not in details.stderr:
        raise ValueError("Release app must be signed with the hardened runtime.")


def package(app: Path, archive: Path) -> None:
    if archive.exists():
        raise ValueError(f"Refusing to overwrite an existing archive: {archive}")
    run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(archive)])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "build/release")
    parser.add_argument("--work-dir", type=Path, default=ROOT / "build/release-work")
    parser.add_argument("--dry-run", action="store_true", help="Build/package unsigned; do not access release secrets")
    args = parser.parse_args()
    try:
        metadata = metadata_for_tag(args.tag)
        build_commit = source_commit(ROOT, require_clean=not args.dry_run)
        feed_url = require_https(os.environ.get("CLIPMENU_UPDATE_FEED_URL") or DEFAULT_FEED)
        public_key = os.environ.get("CLIPMENU_SPARKLE_PUBLIC_KEY", "").strip()
        if not args.dry_run:
            if os.environ.get("SPARKLE_KEY_CONFIGURED", "true").lower() != "true":
                raise ValueError("Configure the SPARKLE_PRIVATE_KEY repository secret before a production release.")
            try:
                decoded_public_key = base64.b64decode(public_key, validate=True)
            except ValueError as error:
                raise ValueError("CLIPMENU_SPARKLE_PUBLIC_KEY must contain a base64 Ed25519 public key.") from error
            if len(decoded_public_key) != 32:
                raise ValueError("Configure CLIPMENU_SPARKLE_PUBLIC_KEY before a production release.")
        repository = os.environ.get("GITHUB_REPOSITORY", "frank4565/ClipMenu")
        if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
            raise ValueError("GITHUB_REPOSITORY must be owner/repository.")
        output = args.output_dir.resolve()
        work = args.work_dir.resolve()
        output.mkdir(parents=True, exist_ok=True)
        work.mkdir(parents=True, exist_ok=True)
        if (output / "build_info.json").exists() or (work / "ClipMenu.xcarchive").exists():
            raise ValueError("Use fresh output/work directories for each release attempt.")
        archive_path = work / "ClipMenu.xcarchive"
        common = [
            "xcodebuild", "-project", str(ROOT / "ClipMenu.xcodeproj"), "-scheme", "ClipMenu",
            "-configuration", "Release", "-derivedDataPath", str(work / "DerivedData"),
            "-clonedSourcePackagesDirPath", str(work / "SourcePackages"),
            "-onlyUsePackageVersionsFromResolvedFile",
        ]
        build_settings = [
            f"MARKETING_VERSION={metadata.marketing_version}", f"CURRENT_PROJECT_VERSION={metadata.build_version}",
            f"CLIPMENU_UPDATE_FEED_URL={feed_url}", f"CLIPMENU_SPARKLE_PUBLIC_KEY={public_key}",
            "ARCHS=arm64 x86_64", "ONLY_ACTIVE_ARCH=NO", "SKIP_INSTALL=NO", "INSTALL_PATH=/Applications",
            "ENABLE_HARDENED_RUNTIME=YES", "CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO",
        ]
        if args.dry_run:
            run(common + ["-archivePath", str(archive_path), "archive", *build_settings,
                          "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY="])
            app = archive_path / "Products/Applications/ClipMenu.app"
            info = validate_app(app, metadata, feed_url, public_key, True)
            archive_name = f"ClipMenu-{metadata.tag}-UNSIGNED.zip"
            package(app, output / archive_name)
        else:
            with signing_credentials() as (identity, team, notary_key):
                run(common + ["-archivePath", str(archive_path), "archive", *build_settings,
                              f"DEVELOPMENT_TEAM={team}", "CODE_SIGN_STYLE=Manual", f"CODE_SIGN_IDENTITY={identity}"])
                options = work / "ExportOptions.plist"
                with options.open("wb") as destination:
                    plistlib.dump({"method": "developer-id", "teamID": team, "signingStyle": "manual",
                                   "signingCertificate": identity}, destination)
                run(["xcodebuild", "-exportArchive", "-archivePath", str(archive_path),
                     "-exportOptionsPlist", str(options), "-exportPath", str(work / "export")])
                app = work / "export/ClipMenu.app"
                info = validate_app(app, metadata, feed_url, public_key, False)
                verify_signed_app(app)
                notary_archive = work / "notarization.zip"
                package(app, notary_archive)
                submitted = run([
                    "xcrun", "notarytool", "submit", str(notary_archive), "--key", str(notary_key),
                    "--key-id", os.environ["APPLE_NOTARY_KEY_ID"], "--issuer", os.environ["APPLE_NOTARY_ISSUER_ID"],
                    "--wait", "--output-format", "json",
                ], capture=True)
                notary_result = json.loads(submitted.stdout)
                (output / "notarization.json").write_text(json.dumps(notary_result, indent=2) + "\n", encoding="utf-8")
                if notary_result.get("status") != "Accepted":
                    raise ValueError("Apple rejected notarization; inspect notarization.json and the notary submission log.")
                run(["xcrun", "stapler", "staple", str(app)])
                run(["xcrun", "stapler", "validate", str(app)])
                verify_signed_app(app)
                run(["spctl", "--assess", "--type", "execute", "--verbose=2", str(app)])
                archive_name = metadata.archive_name
                package(app, output / archive_name)
                # Verify the delivered archive, including the ticket, after packaging.
                extracted = work / "verify-extraction"
                run(["ditto", "-x", "-k", str(output / archive_name), str(extracted)])
                delivered_app = extracted / "ClipMenu.app"
                validate_app(delivered_app, metadata, feed_url, public_key, False)
                verify_signed_app(delivered_app)
                run(["xcrun", "stapler", "validate", str(delivered_app)])
        verify_source_commit(build_commit, ROOT, require_clean=not args.dry_run)
        digest = hashlib.sha256((output / archive_name).read_bytes()).hexdigest()
        build_info = asdict(metadata) | {
            "archive_name": archive_name, "dry_run": args.dry_run, "feed_url": feed_url,
            "public_key": public_key, "repository_url": f"https://github.com/{repository}",
            "minimum_system_version": info["release_minimum_system_version"], "sha256": digest,
            "build_commit": build_commit,
        }
        (output / "build_info.json").write_text(json.dumps(build_info, indent=2) + "\n", encoding="utf-8")
        (output / "SHA256SUMS.txt").write_text(f"{digest}  {archive_name}\n", encoding="utf-8")
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.error(str(error))
    print(f"{'Unsigned dry run' if args.dry_run else 'Notarized release'} ready: {output / archive_name}")


if __name__ == "__main__":
    main()
