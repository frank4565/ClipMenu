#!/usr/bin/env python3
"""Confirm a Pages deployment contains the newly published update."""

import argparse
import json
from pathlib import Path
import time
import urllib.error

from generate_appcast import parse_previous, read_previous_url, sparkle


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metadata", type=Path, default=Path("build/release/build_info.json"))
    args = parser.parse_args()
    info = json.loads(args.metadata.read_text(encoding="utf-8"))
    last_error = "The new release is not visible in the deployed appcast."
    for attempt in range(12):
        try:
            rss = parse_previous(read_previous_url(info["feed_url"]), info["repository_url"])
            if any(item.findtext(sparkle("version")) == info["build_version"]
                   for item in rss.find("channel").findall("item")):
                print(f"Verified deployed appcast: {info['feed_url']}")
                return
        except (ValueError, OSError, urllib.error.URLError) as error:
            last_error = str(error)
        if attempt < 11:
            time.sleep(3)
    parser.error(last_error)


if __name__ == "__main__":
    main()
