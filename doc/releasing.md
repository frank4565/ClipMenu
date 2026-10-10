# Releasing ClipMenu

ClipMenu uses Sparkle 2.10.0, GitHub Releases for immutable update ZIPs, and a
GitHub Pages RSS appcast at
`https://frank4565.github.io/ClipMenu/appcast.xml`. The stable and beta channels
share this feed. The app offers beta and release-candidate items only when the
user enables pre-release updates.

This repository already has its Sparkle private-key secret and public update
variables configured. Signed release publication also requires the Apple
Developer ID certificate, notary API credentials, and team ID listed below.

The first release containing this migration requires a **manual installation**.
Old ClipMenu copies use the original maintainer's feeds and DSA trust key. A new
feed and new Ed25519 key cannot automatically update those copies. Subsequent
releases use Sparkle's install-and-relaunch flow. macOS 12 or later is required.

## Configure GitHub once

1. Enable Actions for the repository and set **Settings → Pages → Build and
   deployment → Source** to **GitHub Actions**. The `github-pages` environment
   must allow deployment from `v*` tags, because releases run from version tags.
   GitHub's default environment rule permits only the default branch; change it
   to selected branches and tags and add a `v*` tag rule.
2. Keep the public repository accessible anonymously. Update archive URLs must
   work without a GitHub login.
3. Configure these **repository variables**:

   | Variable | Value |
   | --- | --- |
   | `CLIPMENU_SPARKLE_PUBLIC_KEY` | The base64 Ed25519 public key from `generate_keys -p`. |
   | `CLIPMENU_UPDATE_FEED_URL` | `https://frank4565.github.io/ClipMenu/appcast.xml` (optional override; this is the build default). |
   | `APPLE_TEAM_ID` | The 10-character Apple Developer team ID that owns the Developer ID certificate. |

4. Configure these **repository secrets**:

   | Secret | Value |
   | --- | --- |
   | `SPARKLE_PRIVATE_KEY` | Exact contents of the private key file exported by Sparkle `generate_keys -x`; already base64, do not encode it again. |
   | `DEVELOPER_ID_CERTIFICATE_P12_BASE64` | Base64 contents of an exported **Developer ID Application** certificate and its private key in `.p12` format. |
   | `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password used when exporting that `.p12` file. |
   | `APPLE_NOTARY_KEY_P8_BASE64` | Base64 contents of an App Store Connect team API `.p8` private key authorized to notarize apps. |
   | `APPLE_NOTARY_KEY_ID` | The API key's ID. |
   | `APPLE_NOTARY_ISSUER_ID` | The API key's issuer ID. |

`GITHUB_TOKEN` is supplied by Actions; no personal access token is needed for
releases or Pages. The build job has read access to repository contents. Only
the publish job has `contents: write`; only the Pages deployment job has
`pages: write` and `id-token: write`. Pull-request validation uses no secrets.

## Preserve the Sparkle key

The current project's public key corresponds to the official Sparkle key stored
in the maintainer's login Keychain under account `frank4565.ClipMenu`. Reuse this
key rather than creating a new one for every release. To obtain the pinned
official tools and export that existing key on the maintainer's Mac:

```sh
python3 script/release_download_tools.py
build/SparkleTools/bin/generate_keys --account frank4565.ClipMenu -p
umask 077
build/SparkleTools/bin/generate_keys --account frank4565.ClipMenu -x /private/tmp/clipmenu-sparkle-private-key
gh secret set SPARKLE_PRIVATE_KEY --repo frank4565/ClipMenu < /private/tmp/clipmenu-sparkle-private-key
rm /private/tmp/clipmenu-sparkle-private-key
```

Back up the private key securely outside Git. The exported file is sensitive;
do not commit it, attach it to a workflow artifact, or put its contents in a
command-line argument. The release helper sends the key to `sign_update` over
standard input and suppresses signer errors that might disclose malformed key
material. It independently verifies the resulting signature against the public
key embedded in the exported app.

For a different fork, intentionally generate a separate account/key once,
configure its public key and feed URL in the Xcode project and GitHub variables,
and publish a manual bootstrap release. Changing the deployed key later
requires a planned trust migration; it is not a routine version bump.

## Versions and release notes

Supported tags are `vX.Y.Z`, `vX.Y.Z-beta.N`, and `vX.Y.Z-rc.N`, with no leading
zeros. Beta and release candidates both use Sparkle's `beta` channel and GitHub's
pre-release flag. Stable releases use the default Sparkle channel.

The helper deterministically maps a tag to `CFBundleVersion`:

```text
(major * 100 + minor + 1).patch.stage
stage = beta iteration (1–49), 49 + rc iteration (50–98), or 99 for stable
```

For example, `v0.5.0-beta.1` becomes `6.0.1`, `v0.5.0-rc.1` becomes `6.0.50`,
and `v0.5.0` becomes `6.0.99`. This preserves semantic version ordering within
Apple's conservative 4.2.2 digit limits. Minor and patch must be at most 99;
`major * 100 + minor + 1` must be at most 9999. Each beta/rc series permits 49
iterations. Tags outside these bounds fail before the build. Never move or reuse
a published tag; fix a release by incrementing its version.

`CFBundleShortVersionString` stays numeric (`0.5.0`) as Apple requires. The full
pre-release name (`0.5.0-beta.1`) appears in Sparkle's update UI and GitHub's
release title. GitHub-generated release notes summarize merged changes. For
curated Sparkle notes, commit optional UTF-8 HTML files before tagging:

- `doc/releases/v0.5.0.en.html`
- `doc/releases/v0.5.0.ja.html`

Without these files, generated English and Japanese HTML links to the GitHub
release. Notes are embedded in localized appcast descriptions and are also
attached to the GitHub Release for review. Previous feed items retain their
original embedded notes across future releases. Inline HTML avoids relying on
GitHub release assets' `application/octet-stream` MIME type for Sparkle's web view.

## Validate without publishing

The **Validate** workflow builds Debug and runs unit tests for pushes to `master`
and `swiftui-native`, and for pull requests. Release helper tests cover ordering,
feed preservation, immutable versions, fetch errors, and unsigned-preview guards.
The test host uses local ad-hoc signing so it can launch on Apple silicon; it
does not require Apple release credentials.

Run the **Release** workflow manually on the branch being reviewed, provide the
intended `version_tag`, and leave `dry_run` checked (the default). This builds a
universal unsigned Release archive, checks its bundle/feed versions, and saves
`ClipMenu-vX.Y.Z-UNSIGNED.zip`, `build_info.json`, `SHA256SUMS.txt`, and
`appcast-preview.xml` as a workflow artifact. It reads no signing credentials and
does not create a release or deploy Pages. The archive is for inspection and
local testing; automatic updates require a signed production build.

The equivalent local commands use Python 3.9 or later and Xcode:

```sh
python3 -m unittest discover -s script/tests -v
python3 script/release_build.py v0.5.0 --dry-run
python3 script/generate_appcast.py --metadata build/release/build_info.json --preview --output build/release/appcast-preview.xml
```

Each attempt requires fresh `build/release` and `build/release-work` directories.
All build products live under ignored `build/`. To include the real signing
round-trip test using a fixed test seed and the pinned official tool:

```sh
python3 script/release_download_tools.py
CLIPMENU_SPARKLE_TEST_TOOL="$PWD/build/SparkleTools/bin/sign_update" python3 -m unittest discover -s script/tests -v
```

Production builds require clean tracked files and record the source commit
before building. The helper rechecks tracked files and HEAD before writing
release metadata. Dry runs allow working-tree changes for review; untracked
test caches and build products do not block either mode.

## Publish

Once the reviewed commit contains the migration and repository configuration is
complete, push a new version tag:

```sh
git tag -a v0.5.0 -m "Release ClipMenu 0.5.0"
git push origin v0.5.0
```

The Release workflow performs these operations in order:

1. Builds a universal `arm64`/`x86_64` archive using the pinned package, version,
   feed, and public key.
2. Imports the Developer ID certificate into a temporary keychain, signs and
   exports with the hardened runtime, submits to Apple's notary service, and
   requires an accepted result.
3. Staples the ticket, validates code signatures/Gatekeeper, creates a ZIP using
   `ditto` to preserve framework symlinks, then extracts and verifies the final
   archive and its stapled ticket again. Temporary signing files/keychain are
   removed even if an operation fails.
4. Downloads the matching official Sparkle tools and verifies their pinned
   SHA-256, signs the ZIP with Ed25519, and verifies that signature against the
   app's embedded public key.
5. Fetches the previous appcast over HTTPS and preserves all existing stable and
   beta items and embedded English/Japanese notes. An empty/HTTP 404 feed is permitted only for the first release,
   after confirming GitHub has no published modern update (`build_info.json`
   asset). The immutable `appcast.xml` snapshot from the most recently published
   modern release is reconciled with Pages on every release, recovering missing
   or stale deployments without dropping either channel. A published modern
   release without a snapshot requires a manual feed repair. Network failures, other
   HTTP errors, malformed XML, invalid signatures, or foreign archive URLs abort
   publication. Existing build versions cannot change archive bytes.
6. Confirms the built commit still matches the version tag, creates a draft
   GitHub Release, uploads the ZIP, checksum, build metadata, appcast snapshot, and
   localized notes, then publishes it and downloads the public ZIP to verify
   its checksum. Assets are never uploaded with `--clobber`.
7. Uploads and deploys the appcast to GitHub Pages **after** the archive becomes
   public, then checks the deployed feed contains the new version.

All release runs share one concurrency group with `queue: max` so overlapping
runs cannot lose feed items or replace pending releases. Up to 100 runs can
wait for sequential processing. GitHub's Latest release marker moves only when
the new stable item is the highest stable version in the feed.

If Pages deployment fails after the GitHub Release succeeds, use **Re-run failed
jobs** on that workflow within the artifact's 14-day retention period. This
reuses the exact signed archive and Pages artifact. Rebuilding the same tag can
produce different signing/notarization timestamps and is intentionally rejected
when its release assets already exist. If a draft release was left by an upload
failure, review/remove that unpublished draft before starting a fresh build.
Never replace a published ZIP to repair an appcast or a release.

## Maintaining the pipeline

Actions are pinned to reviewed commit SHAs. Update those pins deliberately.
When upgrading Sparkle, update the exact Xcode package dependency,
`Package.resolved`, and `script/release_sparkle_tools.json` together. The tools
version is cross-checked against the resolved dependency, and the tools archive
is checksum verified before execution. The old Python 2/DSA appcast publisher is
replaced; `script/deploy.sh` remains a legacy local disk-image helper and is not
used by this release pipeline.

Reference documentation: [Sparkle publishing](https://sparkle-project.org/documentation/publishing/),
[GitHub Pages custom workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages),
[Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution),
and [Apple bundle version keys](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html).
