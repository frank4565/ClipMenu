ClipMenu
========
A clipboard manager for macOS 12 and later, with native SwiftUI preferences.

The Swift app uses Sparkle 2 for signed updates. The release workflow publishes packages to GitHub Releases and an HTTPS update feed to GitHub Pages. See [release setup and publishing](doc/releasing.md) for signing credentials, repository configuration, and migration from the legacy updater.

![ClipMenu](./screenshot.jpg)

## Distribution

If you distribute derived work, especially in the Mac App Store, I ask you to follow two rules:

1. **Don't use "ClipMenu" as your product name.**
2. **Follow the MIT license terms.**

Thank you for your cooperation.

Target environments
-------------------

* macOS 12 or later
* A current Xcode installation with Swift Package Manager

Dependencies
------------
Xcode resolves the pinned [Sparkle](https://sparkle-project.org/) package automatically. No separate dependency installation is needed.

Build with `xcodebuild -project ClipMenu.xcodeproj -scheme ClipMenu -configuration Debug -derivedDataPath build/DerivedData build`. The project includes this fork's public update key and feed URL. Fork maintainers should configure their own key and feed before distributing builds.

Author
------

Naotaka Morimoto ([@naotakaM](http://twitter.com/naotakaM))

License
-------
ClipMenu is available under the MIT license. See the LICENSE file for more info.

Icons are copyrighted by their respective authors.
