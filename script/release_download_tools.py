#!/usr/bin/env python3
"""Download checksum-pinned Sparkle tools matching the app's resolved package."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import urllib.request


ROOT = Path(__file__).resolve().parent.parent
RESOLVED = ROOT / "ClipMenu.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination", type=Path, default=ROOT / "build/SparkleTools")
    args = parser.parse_args()
    manifest = json.loads((ROOT / "script/release_sparkle_tools.json").read_text())
    resolved = json.loads(RESOLVED.read_text())
    sparkle = [pin for pin in resolved["pins"] if pin["identity"].lower() == "sparkle"]
    if len(sparkle) != 1 or sparkle[0]["state"]["version"] != manifest["version"]:
        parser.error("Sparkle tools must match Package.resolved. Update the tools pin with the package.")
    destination = args.destination.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="clipmenu-sparkle-") as directory:
        archive = Path(directory) / "Sparkle.tar.xz"
        request = urllib.request.Request(manifest["url"], headers={"User-Agent": "ClipMenu-release"})
        with urllib.request.urlopen(request, timeout=60) as response, archive.open("wb") as output:
            while chunk := response.read(1024 * 1024):
                output.write(chunk)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != manifest["sha256"]:
            parser.error("The Sparkle tools checksum does not match the reviewed release pin.")
        subprocess.run(["tar", "-xf", str(archive), "-C", str(destination)], check=True)
    for tool in ("generate_keys", "sign_update"):
        if not (destination / "bin" / tool).is_file():
            parser.error(f"The Sparkle distribution is missing {tool}.")
    print(f"Verified Sparkle {manifest['version']} tools: {destination / 'bin'}")


if __name__ == "__main__":
    main()
