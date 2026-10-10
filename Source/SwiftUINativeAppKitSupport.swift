import AppKit
import Carbon
import Combine
import SwiftUI

final class SwiftUIPreferencesWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate {
    static let shared = SwiftUIPreferencesWindowController()
    private static let defaultContentSize = NSSize(width: 760, height: 640)
    private static let toolbarIdentifier = NSToolbar.Identifier("com.naotaka.ClipMenu.preferences")
    private let presentationState = PreferencesPresentationState()
    private var selectionObserver: AnyCancellable?

    private init() {
        let controller = NSHostingController(rootView: CMPreferencesRootView(state: presentationState))
        if #available(macOS 13.0, *) {
            controller.sizingOptions = []
        }
        let window = NSWindow(contentViewController: controller)
        window.title = presentationState.selection?.title ?? NSLocalizedString("Preferences", comment: "")
        window.setContentSize(Self.defaultContentSize)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.collectionBehavior = [.canJoinAllSpaces]
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = false
        window.isRestorable = false
        window.toolbarStyle = .preference
        super.init(window: window)

        let toolbar = NSToolbar(identifier: Self.toolbarIdentifier)
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconAndLabel
        toolbar.sizeMode = .regular
        window.toolbar = toolbar
        window.setContentSize(Self.defaultContentSize)
        window.contentMinSize = Self.defaultContentSize
        window.contentMaxSize = Self.defaultContentSize
        updateWindowChrome(for: presentationState.selection ?? .general)
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        window.standardWindowButton(.zoomButton)?.isEnabled = false

        window.delegate = self
        selectionObserver = presentationState.$selection
            .combineLatest(presentationState.$contentHeights)
            .receive(on: RunLoop.main)
            .sink { [weak self] tab, contentHeights in
                guard let tab else { return }
                self?.updateWindowChrome(for: tab, contentHeight: contentHeights[tab])
            }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        presentationState.resetForPresentation()
        window?.center()
        CMForegroundWindowActivationPolicyBridge.retainRegularActivationPolicy()
        super.showWindow(sender)
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)
        window?.orderFrontRegardless()
        window?.makeMain()
        window?.makeKeyAndOrderFront(self)
    }

    func debugShellSnapshot() -> [String: Any] {
        let selectedTab = presentationState.selection ?? .general
        let visibleTabs = PreferenceTab.allCases
        return [
            "visiblePaneTitles": visibleTabs.map(\.title),
            "visiblePaneIconSources": Dictionary(
                uniqueKeysWithValues: visibleTabs.map { ($0.title, $0.debugIconSourceName) }
            ),
            "selectedPaneTitle": selectedTab.title,
            "selectedPaneIconSource": selectedTab.debugIconSourceName,
            "windowTitle": window?.title as Any,
            "selectedToolbarItemIdentifier": window?.toolbar?.selectedItemIdentifier?.rawValue as Any,
            "toolbarAllowsUserCustomization": window?.toolbar?.allowsUserCustomization as Any,
            "toolbarAutosavesConfiguration": window?.toolbar?.autosavesConfiguration as Any,
            "miniaturizeButtonEnabled": window?.standardWindowButton(.miniaturizeButton)?.isEnabled as Any,
            "zoomButtonEnabled": window?.standardWindowButton(.zoomButton)?.isEnabled as Any
        ]
    }

    func windowWillClose(_ notification: Notification) {
        if let window, !window.makeFirstResponder(window) {
            window.endEditing(for: nil)
        }
        CMCommitPreferencesBeforeWindowClose()
        CMForegroundWindowActivationPolicyBridge.releaseRegularActivationPolicy()
        NSApp.deactivate()
        NotificationCenter.default.post(name: .CMPreferencePanelWillClose, object: nil)
    }

#if DEBUG
    func debugSelectedTabTitle() -> String? {
        presentationState.selection?.title
    }

    func debugSelectTab(rawValue: String) {
        presentationState.selection = CMPreferenceTab(debugRawValue: rawValue)
    }
#endif

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        PreferenceTab.allCases.map(\.toolbarItemIdentifier)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let tab = PreferenceTab.allCases.first(where: { $0.toolbarItemIdentifier == itemIdentifier }) else {
            return nil
        }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = tab.title
        item.paletteLabel = tab.title
        item.toolTip = tab.title
        item.image = tab.toolbarImage
        item.target = self
        item.action = #selector(selectPreferencePane(_:))
        item.isEnabled = true
        return item
    }

    @objc private func selectPreferencePane(_ sender: NSToolbarItem) {
        guard let tab = PreferenceTab.allCases.first(where: { $0.toolbarItemIdentifier == sender.itemIdentifier }) else {
            return
        }
        presentationState.selection = tab
    }

    private func updateWindowChrome(for tab: PreferenceTab, contentHeight: CGFloat? = nil) {
        window?.title = tab.title
        window?.toolbar?.selectedItemIdentifier = tab.toolbarItemIdentifier
        UserDefaults.standard.set(tab.rawValue, forKey: CMSelectedPreferencePaneKey)

        guard let window else { return }
        var contentSize = Self.defaultContentSize
        if let contentHeight {
            contentSize.height = contentHeight
        }
        guard let currentSize = window.contentView?.frame.size,
              currentSize != contentSize else { return }

        // Allow the programmatic resize, keeping the toolbar in place as the
        // bottom edge follows the selected pane's content height.
        let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
        window.contentMinSize = NSSize(width: contentSize.width, height: min(currentSize.height, contentSize.height))
        window.contentMaxSize = NSSize(width: contentSize.width, height: max(currentSize.height, contentSize.height))
        window.setContentSize(contentSize)
        var fittedTopLeft = topLeft
        if let screenFrame = window.screen?.visibleFrame {
            fittedTopLeft.y = min(screenFrame.maxY, max(topLeft.y, screenFrame.minY + window.frame.height))
        }
        window.setFrameTopLeftPoint(fittedTopLeft)
        window.contentMinSize = contentSize
        window.contentMaxSize = contentSize
    }
}

final class SwiftUISnippetEditorWindowController: NSWindowController, NSWindowDelegate {
    let store = SnippetFileStore.shared
    static let frameAutosaveName = "SnippetEditorWindow"
    static let defaultContentSize = NSSize(width: 640, height: 480)
    static let verticalDividerAutosaveName = "SnippetEditorVerticalDivider"
    static let horizontalDividerAutosaveName = "SnippetEditorHorizontalDivider"
    static let defaultVerticalPrimarySize: CGFloat = 244
    static let defaultHorizontalPrimarySize: CGFloat = 235
    private var dirtyStateObserver: AnyCancellable?
    private var lastSelectionSnapshot: SnippetFileStore.SelectionSnapshot?
    private let restoredFrameOnInit: Bool

    init() {
        let controller = NSHostingController(rootView: CMSnippetEditorRootView())
        if #available(macOS 13.0, *) {
            controller.sizingOptions = []
        }
        let window = ClipMenuUndoWindow(contentViewController: controller)
        window.title = NSLocalizedString("Snippet Editor", comment: "")
        window.setContentSize(Self.defaultContentSize)
        window.minSize = NSSize(width: 560, height: 400)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.collectionBehavior = [.canJoinAllSpaces]
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = false
        window.isRestorable = false
        window.toolbarStyle = .unifiedCompact
        let restoredFrame = window.setFrameAutosaveName(Self.frameAutosaveName)
        restoredFrameOnInit = restoredFrame
        if !restoredFrame {
            window.center()
        }
        window.providedUndoManager = { [weak store] in store?.undoManager }
        super.init(window: window)
        window.delegate = self
        dirtyStateObserver = store.$hasUnsavedChanges
            .receive(on: RunLoop.main)
            .sink { [weak window] hasUnsavedChanges in
                window?.isDocumentEdited = hasUnsavedChanges
            }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        store.reload()
        let targetFrame = window?.frame
        CMForegroundWindowActivationPolicyBridge.retainRegularActivationPolicy()
        super.showWindow(sender)
        window?.isDocumentEdited = store.hasUnsavedChanges
        if let window, let targetFrame, restoredFrameOnInit {
            let applyTargetFrame = {
                var centeredFrame = targetFrame
                let centeredOrigin = CMCenteredWindowOriginForDebug(frameSize: targetFrame.size, screen: window.screen)
                centeredFrame.origin = centeredOrigin
                window.setFrame(centeredFrame, display: false)
            }
            applyTargetFrame()
            DispatchQueue.main.async {
                applyTargetFrame()
            }
        } else {
            window?.setContentSize(Self.defaultContentSize)
            window?.center()
            DispatchQueue.main.async { [weak window] in
                window?.setContentSize(Self.defaultContentSize)
                window?.center()
            }
        }
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)
        window?.orderFrontRegardless()
        window?.makeMain()
        window?.makeKeyAndOrderFront(self)
        restoreSplitPositionsAfterWindowSetup()
        if let lastSelectionSnapshot {
            store.restoreSelectionSnapshot(lastSelectionSnapshot)
        }
    }

    private func restoreSplitPositionsAfterWindowSetup() {
        func savedPrimarySize(forKey key: String, fallback: CGFloat) -> CGFloat {
            guard let savedNumber = UserDefaults.standard.object(forKey: key) as? NSNumber else {
                return fallback
            }
            return CGFloat(savedNumber.doubleValue)
        }

        let applyRestoredPositions = { [weak self] in
            guard let self,
                  let rootView = self.window?.contentViewController?.view ?? self.window?.contentView else {
                return
            }

            rootView.layoutSubtreeIfNeeded()

            if let verticalSplit = CMFindSplitView(in: rootView, identifier: Self.verticalDividerAutosaveName) {
                verticalSplit.setPosition(
                    savedPrimarySize(
                        forKey: Self.verticalDividerAutosaveName,
                        fallback: Self.defaultVerticalPrimarySize
                    ),
                    ofDividerAt: 0
                )
            }

            if let horizontalSplit = CMFindSplitView(in: rootView, identifier: Self.horizontalDividerAutosaveName) {
                horizontalSplit.setPosition(
                    savedPrimarySize(
                        forKey: Self.horizontalDividerAutosaveName,
                        fallback: Self.defaultHorizontalPrimarySize
                    ),
                    ofDividerAt: 0
                )
            }

            rootView.layoutSubtreeIfNeeded()
        }

        let restoreDelays: [TimeInterval] = [0, 0.02, 0.08, 0.16, 0.5]
        for delay in restoreDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                applyRestoredPositions()
            }
        }
    }

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        store.undoManager
    }

    func windowWillClose(_ notification: Notification) {
        if let window, !window.makeFirstResponder(window) {
            window.endEditing(for: nil)
        }
        CMForegroundWindowActivationPolicyBridge.releaseRegularActivationPolicy()
        NSApp.deactivate()
        lastSelectionSnapshot = store.currentSelectionSnapshot()
        store.restoreSelectionSnapshot(.init(
            selectedFolderIDs: [],
            selectedSnippetIDs: [],
            primarySelectedFolderID: nil,
            primarySelectedSnippetID: nil
        ))
        store.save()
        NotificationCenter.default.post(name: .CMSnippetEditorWillClose, object: nil)
    }

    @objc func saveDocument(_ sender: Any?) {
        if let window, !window.makeFirstResponder(window) {
            window.endEditing(for: nil)
        }
        store.save()
    }

    @objc func save(_ sender: Any?) {
        saveDocument(sender)
    }

    @objc func saveDocumentAs(_ sender: Any?) {
        if let window, !window.makeFirstResponder(window) {
            window.endEditing(for: nil)
        }
        store.exportSnippetsToPanel()
    }

    @objc func saveAs(_ sender: Any?) {
        saveDocumentAs(sender)
    }

    @objc func revertDocumentToSaved(_ sender: Any?) {
        if let window, !window.makeFirstResponder(window) {
            window.endEditing(for: nil)
        }
        store.reload()
    }

    @objc func revertToSaved(_ sender: Any?) {
        revertDocumentToSaved(sender)
    }

    @objc func importSnippets(_ sender: Any?) {
        if let window, !window.makeFirstResponder(window) {
            window.endEditing(for: nil)
        }
        store.importSnippetsFromPanel()
    }

    func importSnippets(from url: URL) {
        if let window, !window.makeFirstResponder(window) {
            window.endEditing(for: nil)
        }
        store.importSnippets(from: url)
    }

    @objc func exportSnippets(_ sender: Any?) {
        if let window, !window.makeFirstResponder(window) {
            window.endEditing(for: nil)
        }
        store.exportSnippetsToPanel()
    }
}

final class HotKeyRecorderNSView: NSView {
    var keyCode = 0
    var modifierFlags = 0
    var onCapture: ((Int, Int) -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1

        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)
        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 210, height: 26)
    }

    override func layout() {
        super.layout()
        label.frame = bounds.insetBy(dx: 8, dy: 4)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        refresh()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 {
            isRecording = false
            refresh()
            return
        }

        if event.modifierFlags.normalizedShortcutFlags.isEmpty,
           event.keyCode == 51 || event.keyCode == 117 {
            keyCode = -1
            modifierFlags = 0
            isRecording = false
            onCapture?(keyCode, modifierFlags)
            refresh()
            return
        }

        let flags = event.modifierFlags.normalizedShortcutFlags
        guard !flags.isEmpty else {
            NSSound.beep()
            return
        }

        keyCode = Int(event.keyCode)
        modifierFlags = Int(flags.rawValue)
        isRecording = false
        onCapture?(keyCode, modifierFlags)
        refresh()
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        refresh()
        return true
    }

    func refresh() {
        label.stringValue = isRecording
            ? NSLocalizedString("Type shortcut", comment: "")
            : Self.displayString(keyCode: keyCode, modifierFlags: modifierFlags)
        label.textColor = (keyCode >= 0 && modifierFlags != 0) || isRecording
            ? .labelColor
            : .secondaryLabelColor
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        layer?.borderColor = (isRecording ? NSColor.keyboardFocusIndicatorColor : NSColor.separatorColor).cgColor
    }

    private static func displayString(keyCode: Int, modifierFlags: Int) -> String {
        guard keyCode >= 0, modifierFlags != 0 else {
            return NSLocalizedString("(None)", comment: "")
        }

        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifierFlags))
        var parts = ""
        if flags.contains(.control) {
            parts += "\u{2303}"
        }
        if flags.contains(.option) {
            parts += "\u{2325}"
        }
        if flags.contains(.shift) {
            parts += "\u{21E7}"
        }
        if flags.contains(.command) {
            parts += "\u{2318}"
        }
        return parts + keyName(for: keyCode)
    }

    static func keyName(for keyCode: Int) -> String {
        if let layoutName = keyboardLayoutKeyName(for: keyCode) {
            return layoutName
        }

        let names: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 49: "Space", 50: "`", 51: "Delete",
            53: "Escape", 65: ".", 67: "*", 69: "+", 71: "Clear", 75: "/",
            76: "Return", 78: "-", 81: "=", 82: "0", 83: "1", 84: "2",
            85: "3", 86: "4", 87: "5", 88: "6", 89: "7", 91: "8", 92: "9",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
            103: "F11", 105: "F13", 106: "F16", 107: "F14", 109: "F10",
            111: "F12", 113: "F15", 114: "Help", 115: "Home", 116: "Page Up",
            117: "Forward Delete", 118: "F4", 119: "End", 120: "F2",
            121: "Page Down", 122: "F1", 123: "Left", 124: "Right",
            125: "Down", 126: "Up"
        ]
        return names[keyCode] ?? "Key \(keyCode)"
    }

    private static func keyboardLayoutKeyName(for keyCode: Int) -> String? {
        guard keyCode >= 0,
              let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let data = unsafeBitCast(layoutData, to: CFData.self)
        guard let keyboardLayout = UnsafeRawPointer(CFDataGetBytePtr(data))?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
            return nil
        }

        var keysDown = UInt32(0)
        var chars = [UniChar](repeating: 0, count: 4)
        var realLength = 0
        let status = UCKeyTranslate(
            keyboardLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &keysDown,
            chars.count,
            &realLength,
            &chars
        )

        guard status == noErr, realLength > 0 else { return nil }
        let translated = String(utf16CodeUnits: chars, count: realLength)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return translated.isEmpty ? nil : translated.uppercased()
    }
}

@objc(CMLegacyArchivedActionNode)
final class LegacyArchivedActionNode: NSObject, NSCoding {
    var nodeTitle = ""
    var isLeaf = false
    var children: [LegacyArchivedActionNode] = []
    var action: [String: String]?

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        nodeTitle = coder.decodeObject(forKey: CMActionNodeTitleKey) as? String ?? ""
        isLeaf = (coder.decodeObject(forKey: CMActionNodeIsLeafKey) as? NSNumber)?.boolValue ?? false
        let decodedChildren = coder.decodeObject(forKey: CMActionNodeChildrenKey)
        if let childNodes = decodedChildren as? [LegacyArchivedActionNode] {
            children = childNodes
        } else if let childNodes = decodedChildren as? NSArray {
            children = childNodes.compactMap { $0 as? LegacyArchivedActionNode }
        }
        action = CMLegacyActionDictionary(from: coder.decodeObject(forKey: CMActionNodeActionKey))
        super.init()
    }

    func encode(with coder: NSCoder) {}

}

private struct CMSplitPaneHostingRoot: View {
    let content: AnyView

    var body: some View {
        ZStack(alignment: .topLeading) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

final class AutoSavingSplitViewController: NSSplitViewController {
    private let autosaveName: String
    private let initialPrimarySize: CGFloat
    private let primaryHost: NSHostingController<AnyView> = NSHostingController(rootView: AnyView(EmptyView()))
    private let secondaryHost: NSHostingController<AnyView> = NSHostingController(rootView: AnyView(EmptyView()))
    private var didApplyInitialPosition = false
    private var didScheduleInitialPosition = false
    private let savedPrimarySize: CGFloat?

    init(
        autosaveName: String,
        isVertical: Bool,
        dividerStyle: NSSplitView.DividerStyle,
        initialPrimarySize: CGFloat,
        primaryMin: CGFloat,
        primaryMax: CGFloat?,
        secondaryMin: CGFloat
    ) {
        self.autosaveName = autosaveName
        self.initialPrimarySize = initialPrimarySize
        if let savedNumber = UserDefaults.standard.object(forKey: autosaveName) as? NSNumber {
            self.savedPrimarySize = CGFloat(savedNumber.doubleValue)
        } else {
            self.savedPrimarySize = nil
        }
        super.init(nibName: nil, bundle: nil)

        if #available(macOS 13.0, *) {
            primaryHost.sizingOptions = []
            secondaryHost.sizingOptions = []
        }

        let primaryItem = NSSplitViewItem(viewController: primaryHost)
        primaryItem.canCollapse = false
        primaryItem.minimumThickness = primaryMin
        if let primaryMax {
            primaryItem.maximumThickness = primaryMax
        }

        let secondaryItem = NSSplitViewItem(viewController: secondaryHost)
        secondaryItem.canCollapse = false
        secondaryItem.minimumThickness = secondaryMin

        addSplitViewItem(primaryItem)
        addSplitViewItem(secondaryItem)

        splitView.isVertical = isVertical
        splitView.dividerStyle = dividerStyle
        splitView.identifier = NSUserInterfaceItemIdentifier(autosaveName)
        splitView.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(primary: AnyView, secondary: AnyView) {
        primaryHost.rootView = AnyView(CMSplitPaneHostingRoot(content: primary))
        secondaryHost.rootView = AnyView(CMSplitPaneHostingRoot(content: secondary))
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        applyInitialPositionIfNeeded()
    }

    private func applyInitialPositionIfNeeded() {
        guard !didApplyInitialPosition else { return }
        let totalPrimaryAxis = splitView.isVertical ? splitView.bounds.width : splitView.bounds.height
        guard totalPrimaryAxis > splitView.dividerThickness else { return }
        guard !didScheduleInitialPosition else { return }
        let targetPrimarySize = savedPrimarySize ?? initialPrimarySize
        didScheduleInitialPosition = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.splitView.setPosition(targetPrimarySize, ofDividerAt: 0)
            self.splitView.layoutSubtreeIfNeeded()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.splitView.setPosition(targetPrimarySize, ofDividerAt: 0)
                self.splitView.layoutSubtreeIfNeeded()
                self.didApplyInitialPosition = true
                self.persistCurrentPrimarySize()
            }
        }
    }

    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        guard didApplyInitialPosition else { return }
        persistCurrentPrimarySize()
    }

    private func persistCurrentPrimarySize() {
        guard let primarySubview = splitView.subviews.first else { return }
        let primarySize = splitView.isVertical ? primarySubview.frame.width : primarySubview.frame.height
        UserDefaults.standard.set(Double(primarySize), forKey: autosaveName)
    }
}
