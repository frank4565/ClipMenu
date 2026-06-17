import Cocoa

@objc(AppController)
final class AppController: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var snippetEditorController: SnippetEditorController?
    private var previousFrontmostApplication: NSRunningApplication?
    private static var didRegisterDefaultValues = false

    override init() {
        AppController.registerDefaultValuesOnce()
        super.init()
    }

    private static func storeTypesDictionary() -> [String: Bool] {
        var storeTypes: [String: Bool] = [:]
        for case let name as String in Clip.availableTypeNames() {
            storeTypes[name] = true
        }
        return storeTypes
    }

    @objc private static func defaultHotKeyCombos() -> [String: Any] {
        let newCombos: [PTKeyCombo] = [
            PTKeyCombo.keyCombo(withKeyCode: 9, modifiers: 768) as! PTKeyCombo,
            PTKeyCombo.keyCombo(withKeyCode: 9, modifiers: 4352) as! PTKeyCombo,
            PTKeyCombo.keyCombo(withKeyCode: 11, modifiers: 768) as! PTKeyCombo
        ]

        var hotKeyCombos: [String: Any] = [:]
        guard let hotKeyMap = CMUtilities.hotKeyMap() as? [String: [String: Any]] else {
            return hotKeyCombos
        }

        for (identifier, config) in hotKeyMap {
            guard let index = config[kIndex] as? UInt, index < newCombos.count else {
                continue
            }
            hotKeyCombos[identifier] = newCombos[Int(index)].plistRepresentation()
        }

        return hotKeyCombos
    }

    private static func defaultExcludeList() -> [[String: String]] {
        return [[
            kCMBundleIdentifierKey: "org.openoffice.script",
            kCMNameKey: "OpenOffice.org"
        ]]
    }

    private static func registerDefaultValuesOnce() {
        guard !didRegisterDefaultValues else { return }
        didRegisterDefaultValues = true
        
        var defaultValues: [String: Any] = [:]
        defaultValues[CMPrefHotKeysKey] = defaultHotKeyCombos()

        defaultValues[CMPrefLoginItemKey] = false
        defaultValues[CMPrefSuppressAlertForLoginItemKey] = false
        defaultValues[CMPrefInputPasteCommandKey] = true
        defaultValues[CMPrefReorderClipsAfterPasting] = true
        defaultValues[CMPrefMaxHistorySizeKey] = UInt(20)
        defaultValues[CMPrefAutosaveDelayKey] = UInt(1800)
        defaultValues[CMPrefSaveHistoryOnQuitKey] = true
        defaultValues[CMPrefExportHistoryAsSingleFileKey] = true
        defaultValues[CMPrefTagOfSeparatorForExportHistoryToFileKey] = UInt(1)
        defaultValues[CMPrefShowStatusItemKey] = UInt(1)
        defaultValues[CMPrefTimeIntervalKey] = 0.75
        defaultValues[CMPrefStoreTypesKey] = storeTypesDictionary()
        defaultValues[CMPrefExcludeAppsKey] = defaultExcludeList()

        defaultValues[CMPrefMaxMenuItemTitleLengthKey] = UInt(20)
        defaultValues[CMPrefNumberOfItemsPlaceInlineKey] = UInt(0)
        defaultValues[CMPrefNumberOfItemsPlaceInsideFolderKey] = UInt(10)
        defaultValues[CMPrefMenuItemsAreMarkedWithNumbersKey] = true
        defaultValues[CMPrefMenuItemsTitleStartWithZeroKey] = false
        defaultValues[CMPrefAddNumericKeyEquivalentsKey] = false
        defaultValues[CMPrefShowLabelsInMenuKey] = true
        defaultValues[CMPrefAddClearHistoryMenuItemKey] = true
        defaultValues[CMPrefShowAlertBeforeClearHistoryKey] = true
        defaultValues[CMPrefShowToolTipOnMenuItemKey] = true
        defaultValues[CMPrefMaxLengthOfToolTipKey] = UInt(200)
        defaultValues[CMPrefChangeFontSizeKey] = false
        defaultValues[CMPrefHowToChangeFontSizeKey] = 0
        defaultValues[CMPrefSelectedFontSizeKey] = UInt(14)
        defaultValues[CMPrefShowImageInTheMenuKey] = true
        defaultValues[CMPrefThumbnailWidthKey] = UInt(100)
        defaultValues[CMPrefThumbnailHeightKey] = UInt(32)
        defaultValues[CMPrefShowIconInTheMenuKey] = true

        defaultValues[CMPrefMenuIconSizeKey] = UInt(16)
        defaultValues[CMPrefMenuIconOfFileTypeTagForStringKey] = 1
        defaultValues[CMPrefMenuIconOfFileTypeForStringKey] = "TEXT"
        defaultValues[CMPrefMenuIconOfFileTypeTagForRTFKey] = 0
        defaultValues[CMPrefMenuIconOfFileTypeForRTFKey] = "rtf"
        defaultValues[CMPrefMenuIconOfFileTypeTagForRTFDKey] = 0
        defaultValues[CMPrefMenuIconOfFileTypeForRTFDKey] = "rtfd"
        defaultValues[CMPrefMenuIconOfFileTypeTagForPDFKey] = 0
        defaultValues[CMPrefMenuIconOfFileTypeForPDFKey] = "pdf"
        defaultValues[CMPrefMenuIconOfFileTypeTagForFilenamesKey] = 1
        defaultValues[CMPrefMenuIconOfFileTypeForFilenamesKey] = "clpu"
        defaultValues[CMPrefMenuIconOfFileTypeTagForURLKey] = 1
        defaultValues[CMPrefMenuIconOfFileTypeForURLKey] = "gurl"
        defaultValues[CMPrefMenuIconOfFileTypeTagForTIFFKey] = 0
        defaultValues[CMPrefMenuIconOfFileTypeForTIFFKey] = "tiff"
        defaultValues[CMPrefMenuIconOfFileTypeTagForPICTKey] = 0
        defaultValues[CMPrefMenuIconOfFileTypeForPICTKey] = "pict"

        defaultValues["actions"] = ActionController.defaultActions()
        defaultValues[CMPrefEnableActionKey] = true
        defaultValues[CMPrefInvokeActionImmediatelyKey] = false
        defaultValues[CMPrefContorlClickBehaviorKey] = kPopUpActionMenu
        defaultValues[CMPrefPositionOfSnippetsKey] = CMPositionOfSnippetsBelowClips.rawValue

        defaultValues[CMEnableAutomaticCheckKey] = true
        defaultValues[CMEnableAutomaticCheckPreReleaseKey] = false
        defaultValues[CMUpdateCheckIntervalKey] = 86400

        UserDefaults.standard.register(defaults: defaultValues)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        let defaults = UserDefaults.standard
        defaults.removeObserver(self, forKeyPath: CMPrefHotKeysKey)
        defaults.removeObserver(self, forKeyPath: CMEnableAutomaticCheckPreReleaseKey)
        ClipsController.sharedInstance().removeObserver(self, forKeyPath: "clips")
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let defaults = UserDefaults.standard
        defaults.addObserver(self, forKeyPath: CMPrefHotKeysKey, options: .new, context: nil)
        ClipsController.sharedInstance().addObserver(self, forKeyPath: "clips", options: .new, context: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferencePanelWillClose(_:)),
            name: NSNotification.Name.CMPreferencePanelWillClose,
            object: nil
        )
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        case "clips":
            MenuController.sharedInstance().updateStatusMenu()
        case CMPrefHotKeysKey:
            registerHotKeys()
        case CMEnableAutomaticCheckPreReleaseKey:
            toggleCheckPreReleaseUpdates(UserDefaults.standard.bool(forKey: CMEnableAutomaticCheckPreReleaseKey))
        default:
            break
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaults = UserDefaults.standard
        let queue = OperationQueue()

        if defaults.bool(forKey: CMPrefShowStatusItemKey) {
            MenuController.sharedInstance().perform(#selector(MenuController.createStatusItem), with: nil, afterDelay: 0.5)
        }

        queue.addOperation { ClipsController.sharedInstance().loadClips() }
        queue.addOperation { ActionController.sharedInstance().loadActions() }
        queue.addOperation { self.registerHotKeys() }

        if !defaults.bool(forKey: CMPrefLoginItemKey) && !defaults.bool(forKey: CMPrefSuppressAlertForLoginItemKey) {
            promptToAddLoginItems()
        }

        let updater = SUUpdater.shared()
        toggleCheckPreReleaseUpdates(defaults.bool(forKey: CMEnableAutomaticCheckPreReleaseKey))
        updater?.automaticallyChecksForUpdates = defaults.bool(forKey: CMEnableAutomaticCheckKey)
        updater?.updateCheckInterval = defaults.double(forKey: CMUpdateCheckIntervalKey)

        defaults.addObserver(self, forKeyPath: CMEnableAutomaticCheckPreReleaseKey, options: .new, context: nil)
        queue.waitUntilAllOperationsAreFinished()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if UserDefaults.standard.bool(forKey: CMPrefSaveHistoryOnQuitKey) {
            if !ClipsController.sharedInstance().saveClips() {
                NSApp.activate(ignoringOtherApps: true)
                CMRunAlertPanel(
                    NSLocalizedString("Error", comment: ""),
                    NSLocalizedString("Could not save your clipboard history to file.", comment: ""),
                    NSLocalizedString("OK", comment: ""),
                    nil,
                    nil
                )
            }
        } else {
            ClipsController.sharedInstance().removeClips()
        }

        ActionController.sharedInstance().saveActions()
        unregisterHotKeys()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(clearHistory(_:)) {
            return ClipsController.sharedInstance().clips.count > 0
        }
        return true
    }

    @IBAction func showPreferencePanel(_ sender: Any?) {
        PrefsWindowController.sharedPref().showWindow(nil)
    }

    @IBAction func showSnippetEditor(_ sender: Any?) {
        if snippetEditorController == nil {
            snippetEditorController = SnippetEditorController()
        }
        snippetEditorController?.showWindow(self)
    }

    @IBAction func clearHistory(_ sender: Any?) {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: CMPrefShowAlertBeforeClearHistoryKey) {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Clear History", comment: "")
            alert.informativeText = NSLocalizedString("Are you sure you want to clear your clipboard history?", comment: "")
            alert.addButton(withTitle: NSLocalizedString("Clear History", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            alert.showsSuppressionButton = true

            NSApp.activate(ignoringOtherApps: true)
            let result = alert.runModal()

            if alert.suppressionButton?.state == .on {
                defaults.set(false, forKey: CMPrefShowAlertBeforeClearHistoryKey)
            }

            if result != .alertFirstButtonReturn {
                return
            }
        }

        ClipsController.sharedInstance().clearAll()
    }

    @objc func popUpClipMenu(_ sender: Any?) {
        MenuController.sharedInstance().popUpMenu(for: CMPopUpMenuTypeMain)
    }

    @objc func popUpActionMenu(_ sender: Any?) {
        guard let actionNodes = ActionController.sharedInstance().actionNodes, actionNodes.count > 0 else {
            return
        }

        let menuItem = sender as? NSMenuItem
        var tag = menuItem?.tag ?? 0

        if let snippet = menuItem?.representedObject as? NSManagedObject {
            tag = -1
            ActionController.sharedInstance().selectedSnippet = snippet
        }

        ActionController.sharedInstance().selectedClipTag = tag

        if UserDefaults.standard.bool(forKey: CMPrefInvokeActionImmediatelyKey), actionNodes.count == 1,
           let actionNode = actionNodes[0] as? ActionNode,
           let action = actionNode.action {
            invokeAction(action as NSDictionary as! [String: Any])
        } else {
            MenuController.sharedInstance().popUpMenu(for: CMPopUpMenuTypeActions)
        }

        ActionController.sharedInstance().clearSelection()
    }

    @objc func popUpHistoryMenu(_ sender: Any?) {
        MenuController.sharedInstance().popUpMenu(for: CMPopUpMenuTypeHistory)
    }

    @objc func popUpSnippetsMenu(_ sender: Any?) {
        MenuController.sharedInstance().popUpMenu(for: CMPopUpMenuTypeSnippets)
    }

    @objc func selectMenuItem(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else { return }
        if applyAction(toTarget: menuItem) {
            return
        }

        ClipsController.sharedInstance().copyClipToPasteboard(at: UInt(menuItem.tag))
        CMUtilities.paste()
    }

    @objc func selectSnippetMenuItem(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem,
              let snippet = menuItem.representedObject as? NSManagedObject else {
            NSSound.beep()
            return
        }

        if applyAction(toTarget: menuItem) {
            return
        }

        if let content = snippet.value(forKey: kContent) as? String {
            ClipsController.sharedInstance().copyString(toPasteboard: content)
            CMUtilities.paste()
        }
    }

    @objc func selectActionMenuItem(_ sender: Any?) {
        guard let action = (sender as AnyObject?)?.representedObject as? [String: Any] else {
            return
        }
        invokeAction(action)
    }

    private func toggleCheckPreReleaseUpdates(_ flag: Bool) {
        let key = flag ? "SUPreReleaseFeedURL" : "SUFeedURL"
        guard let feed = CMUtilities.infoValue(forKey: key) as? String else {
            return
        }
        SUUpdater.shared()?.feedURL = URL(string: feed)
    }

    private func promptToAddLoginItems() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Launch ClipMenu on system startup?", comment: "")
        alert.informativeText = NSLocalizedString("You can change this setting in the Preferences if you want.", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Launch on system startup", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Don't Launch", comment: ""))
        alert.showsSuppressionButton = true

        let defaults = UserDefaults.standard
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            defaults.set(true, forKey: CMPrefLoginItemKey)
            toggleLoginItemState()
        }

        if alert.suppressionButton?.state == .on {
            defaults.set(true, forKey: CMPrefSuppressAlertForLoginItemKey)
        }
    }

    private func toggleAddingToLoginItems(_ flag: Bool) {
        let appPath = Bundle.main.bundlePath
        if flag {
            NMLoginItems.addPath(toLoginItems: appPath, hide: false)
        } else {
            NMLoginItems.removePath(fromLoginItems: appPath)
        }
    }

    private func toggleLoginItemState() {
        toggleAddingToLoginItems(UserDefaults.standard.bool(forKey: CMPrefLoginItemKey))
    }

    @objc private func registerHotKeys() {
        guard let hotKeyCenter = PTHotKeyCenter.shared() else { return }
        let savedCombos = UserDefaults.standard.dictionary(forKey: CMPrefHotKeysKey) ?? [:]
        let defaultCombos = AppController.defaultHotKeyCombos()
        guard let hotKeyMap = CMUtilities.hotKeyMap() as? [String: [String: Any]] else {
            return
        }

        for (identifier, defaultCombo) in defaultCombos {
            let keyComboPlist = savedCombos[identifier] ?? defaultCombo
            guard let keyCombo = PTKeyCombo(plistRepresentation: keyComboPlist),
                  let hotKey = PTHotKey(identifier: identifier, keyCombo: keyCombo),
                  let selectorName = hotKeyMap[identifier]?[kSelector] as? String else {
                continue
            }

            hotKey.setTarget(self)
            hotKey.setAction(NSSelectorFromString(selectorName))
            hotKeyCenter.register(hotKey)
        }
    }

    private func unregisterHotKeys() {
        guard let hotKeyCenter = PTHotKeyCenter.shared(),
              let hotKeys = hotKeyCenter.allHotKeys() as? [PTHotKey] else {
            return
        }

        for hotKey in hotKeys {
            hotKeyCenter.unregisterHotKey(hotKey)
        }
    }

    private func invokeModifiedClick(with behavior: Any?, sender: NSMenuItem) -> Bool {
        guard let behavior = behavior else { return false }

        if let behaviorString = behavior as? String {
            if behaviorString.isEmpty {
                return false
            }
            if behaviorString == kPopUpActionMenu {
                popUpActionMenu(sender)
            }
        } else if let action = behavior as? [String: Any] {
            invokeAction(action, toIndex: sender.tag)
        }

        return true
    }

    private func applyAction(toTarget sender: NSMenuItem) -> Bool {
        guard UserDefaults.standard.bool(forKey: CMPrefEnableActionKey),
              let currentEvent = NSApp.currentEvent else {
            return false
        }

        let defaults = UserDefaults.standard
        let flags = currentEvent.modifierFlags

        if currentEvent.type == .rightMouseUp || flags.contains(.control) {
            return invokeModifiedClick(with: defaults.object(forKey: CMPrefContorlClickBehaviorKey), sender: sender)
        } else if flags.contains(.shift) {
            return invokeModifiedClick(with: defaults.object(forKey: CMPrefShiftClickBehaviorKey), sender: sender)
        } else if flags.contains(.option) {
            return invokeModifiedClick(with: defaults.object(forKey: CMPrefOptionClickBehaviorKey), sender: sender)
        } else if flags.contains(.command) {
            return invokeModifiedClick(with: defaults.object(forKey: CMPrefCommandClickBehaviorKey), sender: sender)
        }

        return false
    }

    private func invokeAction(_ action: [String: Any], toIndex index: Int) {
        guard let type = action["type"] as? String else { return }

        let target: Any?
        if index < 0 {
            target = ActionController.sharedInstance().selectedSnippet
        } else {
            target = ClipsController.sharedInstance().clip(at: UInt(index))
        }

        if type == CMBuiltinActionTypeKey {
            invokeBuiltinAction(action, toTarget: target)
        } else if type == CMJavaScriptActionTypeKey {
            invokeJavaScriptAction(action, at: index)
        }
    }

    private func invokeAction(_ action: [String: Any]) {
        invokeAction(action, toIndex: ActionController.sharedInstance().selectedClipTag)
    }

    private func invokeBuiltinAction(_ action: [String: Any], toTarget target: Any?) {
        guard let actionName = action["name"] as? String else { return }
        ActionController.sharedInstance().invokeCommand(forKey: actionName, toTarget: target)
    }

    private func invokeJavaScriptAction(_ action: [String: Any], at index: Int) {
        guard let scriptPath = action["path"] as? String,
              FileManager.default.fileExists(atPath: scriptPath) else {
            CMRunAlertPanel(
                nil,
                NSLocalizedString("The script you selected does not exist", comment: ""),
                NSLocalizedString("OK", comment: ""),
                nil,
                nil
            )
            return
        }

        let actionController = ActionController.sharedInstance()
        let selectedClip: Clip?
        if index < 0 {
            let snippetString = actionController?.selectedSnippet?.value(forKey: kContent) as? String
            selectedClip = Clip.clip(with: snippetString) as? Clip
        } else {
            selectedClip = ClipsController.sharedInstance().clip(at: UInt(index))
        }

        guard let clip = selectedClip,
              let resultClip = actionController?.invokeScript(scriptPath, to: clip) else {
            return
        }

        ClipsController.sharedInstance().copyClip(toPasteboard: resultClip)
        CMUtilities.paste()
    }

    @objc func keepCurrentFrontProcessAndActivate() {
        previousFrontmostApplication = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func restorePreviousFrontProcess() -> Bool {
        guard let application = previousFrontmostApplication else {
            return true
        }

        previousFrontmostApplication = nil
        return application.activate(options: [])
    }

    @objc private func handlePreferencePanelWillClose(_ notification: Notification) {
        toggleLoginItemState()
    }
}
