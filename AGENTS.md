# Repository Guidelines

## Project Structure & Module Organization

ClipMenu is a macOS Xcode project. Core application code lives in `Source/`, currently split between `AppController.swift` and SwiftUI native window support. Localized Interface Builder and string resources are in `English.lproj/` and `Japanese.lproj/`. App assets, icons, Core Data models, and JavaScript action scripts are under `resource/`; action scripts are grouped by menu category in `resource/script/action/`. Release notes, fixtures, and manual feature-test reports live in `doc/`. Build and release helpers live in `script/`.

## Build, Test, and Development Commands

- `xcodebuild -list -project ClipMenu.xcodeproj`: show available targets, schemes, and configurations.
- `xcodebuild -project ClipMenu.xcodeproj -scheme ClipMenu -configuration Debug build`: build the app for local development.
- `xcodebuild -project ClipMenu.xcodeproj -scheme ClipMenu -configuration Release build`: produce a release configuration build.
- `xcodebuild -project ClipMenu.xcodeproj -scheme "ClipMenu (deployment)" -configuration Release build`: build the deployment scheme.
- `script/generate_versionhistories.sh`: regenerate version-history artifacts from `doc/VersionHistory-*.yaml`.

Keep generated products in ignored `DerivedData*`, `.derivedData*`, or `build/` directories.

## Coding Style & Naming Conventions

Use Swift conventions: four-space indentation, `PascalCase` for types, `camelCase` for functions/properties, and explicit access control where it clarifies ownership. Existing Objective-C-era preference constants use the `CM...Key` pattern; follow that style for related keys. Prefer localized user-facing strings through `NSLocalizedString` and update both English and Japanese `.strings` files when changing visible text. JavaScript action filenames are user-facing menu labels, so preserve readable names such as `Title Case.js` or `Encode URI component.js`.

## Testing Guidelines

This repository does not currently include a dedicated automated test target. Verify changes with a Debug `xcodebuild` and, for user-facing behavior, update or consult the manual test material in `doc/feature_test_cases.md` and related dated reports. Use fixtures in `doc/*_hotkey_fixture.*` when validating hotkey import/export behavior. For UI changes, include screenshots or notes from a local run.

## Commit & Pull Request Guidelines

Recent commits use concise imperative subjects, for example `Fix automatic paste from history menu` and `Migrate ClipMenu to native SwiftUI windows`. Keep the first line focused on the behavior changed. Pull requests should describe the user-visible impact, list build/manual test results, mention localization updates, and include screenshots for menu, preferences, or window changes. Link related issues when available and call out any release-script or signing implications.

## Security & Configuration Tips

Do not commit signing identities, private keys, exported archives, or generated `.app` bundles. Treat `resource/dsa_pub.pem` as a public update-verification asset; do not replace it without documenting the release-update impact.
