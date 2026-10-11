# Sparkle 2 migration verification — 2026-10-11

Environment: macOS on Apple Silicon, Xcode 27.0 (27A266a), Sparkle 2.10.0.

## Results

- Debug app build passed with the pinned Sparkle framework embedded.
- All 63 `ClipMenuTests` passed using the Testing configuration and local ad-hoc
  signing. The seven updater tests cover fresh-install consent, persisted legacy
  choices, the old Never interval, one-time installation consent migration,
  HTTPS/public-key validation, and manual checks with automatic checks disabled.
- Updated the pre-existing General preferences test to read excluded apps from
  the current `excludedApplications` snapshot; its old nested path was stale.
- All 14 release-helper tests passed, including Git commit provenance checks,
  the official Sparkle signer and
  an independent CryptoKit verification that rejects the wrong public key.
- A universal unsigned `v0.5.0-beta.1` Release archive passed bundle/version,
  minimum macOS, public-key/feed, and arm64/x86_64 checks. The preview appcast
  contains localized English/Japanese HTML and the beta channel.
- Plists, localized strings, and whitespace validation passed. Workflow lint
  passed except that the installed linter predates GitHub's supported
  `concurrency.queue: max` option.

Build products and logs are under ignored `build/`. Xcode's dependency download
initially stalled; the official Swift package ZIP was downloaded separately,
checked against its manifest SHA-256, and expanded into the local package cache.
The first XCTest host stalled loading a framework from the Documents checkout;
the successful run used `/private/tmp/clipmenu-sparkle-validation` for the
verified package cache and DerivedData.

An isolated QA copy used a separate bundle identifier, support directory, and
disabled update checks/hotkeys/login changes. Direct sandbox launch failed inside
macOS application registration. LaunchServices started the isolated copy, but
native UI capture stalled and was interrupted before returning a screenshot.
That QA process was stopped. Visual layout was not verified.

## GitHub setup

- GitHub Pages is enabled with GitHub Actions as its build source and HTTPS
  enforced at `https://frank4565.github.io/ClipMenu/`.
- The `github-pages` environment permits `master` and `v*` tags.
- The generated Sparkle key is retained in the login Keychain under account
  `frank4565.ClipMenu`; its private value is stored only as the encrypted
  `SPARKLE_PRIVATE_KEY` Actions secret.
- Repository variables contain the matching public Ed25519 key and feed URL.

## Remaining production validation

Developer ID signing, Apple notarization, installation/relaunch, and live
release/Pages deployment require the Apple credentials listed in
[releasing.md](releasing.md). No version tag or public release was created during
verification. Existing legacy copies require a manual first installation;
their original feed and DSA key cannot bootstrap this new trust configuration.
The legacy public DSA asset remains in the repository for historical reference.
