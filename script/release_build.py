#!/usr/bin/env python3
"""Build a universal ad-hoc signed release and verify the delivered package."""

import argparse
import base64
from dataclasses import asdict
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile

from generate_appcast import require_https
from release_metadata import metadata_for_tag


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_FEED = "https://frank4565.github.io/ClipMenu/appcast.xml"


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
    lines = details.stderr.splitlines()
    if "Signature=adhoc" not in lines or "TeamIdentifier=not set" not in lines:
        raise ValueError("Release app must have an ad-hoc signature without an Apple signing identity.")
    if any(line.startswith("CodeDirectory ") and "runtime" in line for line in lines):
        raise ValueError("The ad-hoc release host must not enable hardened-runtime library validation.")


def sign_adhoc_app(app: Path) -> None:
    # Xcode signs embedded frameworks on copy. Only seal the host here, preserving
    # Sparkle's nested helper signatures and entitlements rather than signing deeply.
    run(["codesign", "--force", "--sign", "-", "--timestamp=none", str(app)])
    verify_signed_app(app)


def release_notices(repository: Path, source_packages: Path) -> dict[str, bytes]:
    resolved_path = repository / "ClipMenu.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    resolved = json.loads(resolved_path.read_text(encoding="utf-8"))
    pins = [pin for pin in resolved.get("pins", []) if pin.get("identity") == "sparkle"]
    if len(pins) != 1:
        raise ValueError("Package.resolved must identify exactly one Sparkle dependency for its release license.")
    workspace = json.loads((source_packages / "workspace-state.json").read_text(encoding="utf-8")).get("object", {})
    if not isinstance(workspace, dict):
        raise ValueError("The release package cache has invalid Swift package workspace metadata.")
    dependencies = [dependency for dependency in workspace.get("dependencies", [])
                    if dependency.get("packageRef", {}).get("identity") == "sparkle"]
    if len(dependencies) != 1:
        raise ValueError("The release package cache must contain exactly one resolved Sparkle dependency.")
    checkout = dependencies[0].get("state", {}).get("checkoutState", {})
    expected_state = pins[0].get("state", {})
    if not expected_state.get("revision") or any(
        checkout.get(key) != expected_state.get(key) for key in ("revision", "version")
    ):
        raise ValueError("The cached Sparkle dependency does not match Package.resolved.")
    artifacts = [artifact for artifact in workspace.get("artifacts", [])
                 if artifact.get("packageRef", {}).get("identity") == "sparkle"
                 and artifact.get("targetName") == "Sparkle"]
    if len(artifacts) != 1 or not artifacts[0].get("path"):
        raise ValueError("The release package cache must identify the resolved Sparkle framework artifact.")
    artifact = Path(artifacts[0]["path"])
    if not artifact.is_absolute():
        artifact = source_packages / artifact
    artifact = artifact.resolve()
    if not artifact.is_relative_to(source_packages.resolve()) or not artifact.is_dir() or artifact.suffix != ".xcframework":
        raise ValueError("The resolved Sparkle framework artifact is missing from the release package cache.")
    sources = {"LICENSE.txt": repository / "LICENSE", "Sparkle-LICENSE.txt": artifact.parent / "LICENSE"}
    notices = {}
    for name, source in sources.items():
        if not source.is_file():
            raise ValueError(f"Missing required release license: {source}")
        content = source.read_bytes()
        if not content:
            raise ValueError(f"The required release license is empty: {source}")
        notices[name] = content
    return notices


def verify_release_notices(extracted: Path, notices: dict[str, bytes]) -> None:
    for name, expected in notices.items():
        delivered = extracted / name
        if not delivered.is_file() or delivered.read_bytes() != expected:
            raise ValueError(f"The delivered archive's {name} is missing or differs from its release license.")


def package(app: Path, archive: Path, notices: dict[str, bytes]) -> None:
    if archive.exists():
        raise ValueError(f"Refusing to overwrite an existing archive: {archive}")
    with tempfile.TemporaryDirectory(prefix="clipmenu-release-package-") as directory:
        staging = Path(directory)
        # Copy the signed bundle without adding resources to it or changing its signature.
        run(["ditto", str(app), str(staging / app.name)])
        for name, content in notices.items():
            (staging / name).write_bytes(content)
        run(["ditto", "-c", "-k", "--sequesterRsrc", str(staging), str(archive)])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "build/release")
    parser.add_argument("--work-dir", type=Path, default=ROOT / "build/release-work")
    parser.add_argument("--dry-run", action="store_true", help="Build/package an unsigned preview")
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
            # An ad-hoc host cannot use library validation with differently signed
            # dependencies. Its update archive is authenticated separately by Sparkle.
            "ENABLE_HARDENED_RUNTIME=NO", "CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO",
        ]
        signing_settings = (
            ["CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY="]
            if args.dry_run else
            ["CODE_SIGNING_ALLOWED=YES", "CODE_SIGNING_REQUIRED=YES", "CODE_SIGN_IDENTITY=-",
             "CODE_SIGN_STYLE=Manual", "DEVELOPMENT_TEAM="]
        )
        run(common + ["-archivePath", str(archive_path), "archive", *build_settings, *signing_settings])
        app = archive_path / "Products/Applications/ClipMenu.app"
        info = validate_app(app, metadata, feed_url, public_key, args.dry_run)
        notices = release_notices(ROOT, work / "SourcePackages")
        if not args.dry_run:
            sign_adhoc_app(app)
        archive_name = f"ClipMenu-{metadata.tag}-UNSIGNED.zip" if args.dry_run else metadata.archive_name
        package(app, output / archive_name, notices)
        extracted = work / "verify-extraction"
        run(["ditto", "-x", "-k", str(output / archive_name), str(extracted)])
        delivered_app = extracted / "ClipMenu.app"
        validate_app(delivered_app, metadata, feed_url, public_key, args.dry_run)
        verify_release_notices(extracted, notices)
        if not args.dry_run:
            verify_signed_app(delivered_app)
        verify_source_commit(build_commit, ROOT, require_clean=not args.dry_run)
        digest = hashlib.sha256((output / archive_name).read_bytes()).hexdigest()
        build_info = asdict(metadata) | {
            "archive_name": archive_name, "dry_run": args.dry_run, "feed_url": feed_url,
            "signing_mode": "unsigned" if args.dry_run else "adhoc",
            "public_key": public_key, "repository_url": f"https://github.com/{repository}",
            "minimum_system_version": info["release_minimum_system_version"], "sha256": digest,
            "build_commit": build_commit,
        }
        (output / "build_info.json").write_text(json.dumps(build_info, indent=2) + "\n", encoding="utf-8")
        (output / "SHA256SUMS.txt").write_text(f"{digest}  {archive_name}\n", encoding="utf-8")
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.error(str(error))
    print(f"{'Unsigned dry run' if args.dry_run else 'Ad-hoc signed release'} ready: {output / archive_name}")


if __name__ == "__main__":
    main()
