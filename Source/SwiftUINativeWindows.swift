import AppKit
import Carbon
import Combine
import CoreData
import SwiftUI
import UniformTypeIdentifiers

private extension UTType {
    static let clipMenuSnippetDrag = UTType(exportedAs: "net.clipmenu.snippet")
    static let clipMenuActionNodeDrag = UTType(exportedAs: "net.clipmenu.action-node")
}

private func CMSnippetEditorFolderRowIcon() -> NSImage? {
    let icon = NSWorkspace.shared.icon(
        forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon))
    )
    let copiedIcon = icon.copy() as? NSImage
    copiedIcon?.size = NSSize(width: 16, height: 16)
    return copiedIcon
}

private func CMSnippetEditorSnippetRowIcon() -> NSImage? {
    let icon = NSWorkspace.shared.icon(
        forFileType: NSFileTypeForHFSTypeCode(OSType(kClippingTextTypeIcon))
    )
    let copiedIcon = icon.copy() as? NSImage
    copiedIcon?.size = NSSize(width: 16, height: 16)
    return copiedIcon
}

func CMShowAlert(_ alert: NSAlert, sheetFor window: NSWindow?) {
#if DEBUG
    CMRecordAlertForDebug(alert)
    if CMShouldBypassAlertPresentationForDebug() {
        return
    }
#endif
    if let window, window.isVisible {
        alert.beginSheetModal(for: window)
    } else {
        alert.runModal()
    }
}

func localizedActionSaveFailureAccessoryTitle() -> String {
    NSLocalizedString("Action Library Save Failed", comment: "")
}

func localizedActionSaveFailureAccessoryDetail() -> String {
    NSLocalizedString(
        "ClipMenu could not write the current action library to disk. Review storage permissions or available space, then try again.",
        comment: ""
    )
}

private func makeActionSaveFailureAlertAccessory() -> NSView {
    let width: CGFloat = 420
    let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: 72))
    container.material = .menu
    container.state = .active
    container.wantsLayer = true
    container.layer?.cornerRadius = 12
    container.layer?.masksToBounds = true

    let iconBackground = NSVisualEffectView(frame: NSRect(x: 16, y: 16, width: 40, height: 40))
    iconBackground.material = .sidebar
    iconBackground.state = .active
    iconBackground.wantsLayer = true
    iconBackground.layer?.cornerRadius = 10
    iconBackground.layer?.masksToBounds = true
    container.addSubview(iconBackground)

    let title = localizedActionSaveFailureAccessoryTitle()
    let detail = localizedActionSaveFailureAccessoryDetail()
    let iconConfiguration = NSImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
    let iconView = NSImageView(frame: NSRect(x: 9, y: 9, width: 22, height: 22))
    iconView.image = NSImage(
        systemSymbolName: "square.stack.3d.down.right.badge.exclamationmark",
        accessibilityDescription: title
    )?.withSymbolConfiguration(iconConfiguration)
    iconView.contentTintColor = .systemOrange
    iconView.imageScaling = .scaleProportionallyUpOrDown
    iconBackground.addSubview(iconView)

    let textWidth = width - 90

    let titleLabel = NSTextField(labelWithString: title)
    titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
    titleLabel.frame = NSRect(x: 70, y: 38, width: textWidth, height: 18)
    container.addSubview(titleLabel)

    let detailLabel = NSTextField(labelWithString: detail)
    detailLabel.font = .systemFont(ofSize: 12)
    detailLabel.textColor = .secondaryLabelColor
    detailLabel.lineBreakMode = .byTruncatingTail
    detailLabel.frame = NSRect(x: 70, y: 18, width: textWidth, height: 17)
    container.addSubview(detailLabel)

    return container
}

func CMMakeActionSaveFailureAlert(_ error: Error) -> NSAlert {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Could not save actions.", comment: "")
    alert.informativeText = error.localizedDescription
    alert.accessoryView = makeActionSaveFailureAlertAccessory()
    alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
    return alert
}

private enum CMSnippetAlertKind {
    case endEditing
    case saveFailure
    case importFailure
    case exportFailure
}

private func localizedSnippetAlertAccessoryTitle(for kind: CMSnippetAlertKind) -> String {
    switch kind {
    case .endEditing:
        return NSLocalizedString("Finish Editing First", comment: "")
    case .saveFailure:
        return NSLocalizedString("Snippet Library Save Failed", comment: "")
    case .importFailure:
        return NSLocalizedString("Snippet Import Failed", comment: "")
    case .exportFailure:
        return NSLocalizedString("Snippet Export Failed", comment: "")
    }
}

private func localizedSnippetAlertAccessoryDetail(for kind: CMSnippetAlertKind) -> String {
    switch kind {
    case .endEditing:
        return NSLocalizedString(
            "ClipMenu needs the current inline edit to finish before it can continue with this snippet command.",
            comment: ""
        )
    case .saveFailure:
        return NSLocalizedString(
            "ClipMenu could not write the current snippet library to disk. Review storage permissions or available space, then try again.",
            comment: ""
        )
    case .importFailure:
        return NSLocalizedString(
            "ClipMenu could not read the selected snippet XML file. Review the file contents and try again.",
            comment: ""
        )
    case .exportFailure:
        return NSLocalizedString(
            "ClipMenu could not finish writing the selected snippet export. Check the destination and try again.",
            comment: ""
        )
    }
}

private func makeSnippetAlertAccessory(
    title: String,
    detail: String,
    symbolName: String,
    tintColor: NSColor
) -> NSView {
    let width: CGFloat = 420
    let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: 72))
    container.material = .menu
    container.state = .active
    container.wantsLayer = true
    container.layer?.cornerRadius = 12
    container.layer?.masksToBounds = true

    let iconBackground = NSVisualEffectView(frame: NSRect(x: 16, y: 16, width: 40, height: 40))
    iconBackground.material = .sidebar
    iconBackground.state = .active
    iconBackground.wantsLayer = true
    iconBackground.layer?.cornerRadius = 10
    iconBackground.layer?.masksToBounds = true
    container.addSubview(iconBackground)

    let iconConfiguration = NSImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
    let iconView = NSImageView(frame: NSRect(x: 9, y: 9, width: 22, height: 22))
    iconView.image = NSImage(
        systemSymbolName: symbolName,
        accessibilityDescription: title
    )?.withSymbolConfiguration(iconConfiguration)
    iconView.contentTintColor = tintColor
    iconView.imageScaling = .scaleProportionallyUpOrDown
    iconBackground.addSubview(iconView)

    let textWidth = width - 90

    let titleLabel = NSTextField(labelWithString: title)
    titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
    titleLabel.frame = NSRect(x: 70, y: 38, width: textWidth, height: 18)
    container.addSubview(titleLabel)

    let detailLabel = NSTextField(labelWithString: detail)
    detailLabel.font = .systemFont(ofSize: 12)
    detailLabel.textColor = .secondaryLabelColor
    detailLabel.lineBreakMode = .byTruncatingTail
    detailLabel.frame = NSRect(x: 70, y: 18, width: textWidth, height: 17)
    container.addSubview(detailLabel)

    return container
}

private func makeSnippetAlertAccessory(kind: CMSnippetAlertKind, symbolName: String, tintColor: NSColor) -> NSView {
    makeSnippetAlertAccessory(
        title: localizedSnippetAlertAccessoryTitle(for: kind),
        detail: localizedSnippetAlertAccessoryDetail(for: kind),
        symbolName: symbolName,
        tintColor: tintColor
    )
}

func CMMakeUnableToEndEditingAlert() -> NSAlert {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Unable to end editing", comment: "")
    alert.accessoryView = makeSnippetAlertAccessory(
        kind: .endEditing,
        symbolName: "pencil.and.ellipsis.rectangle",
        tintColor: .systemOrange
    )
    alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
    return alert
}

func CMMakeSnippetSaveFailureAlert(_ error: Error) -> NSAlert {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Could not save snippets.", comment: "")
    alert.informativeText = error.localizedDescription
    alert.accessoryView = makeSnippetAlertAccessory(
        kind: .saveFailure,
        symbolName: "text.badge.xmark",
        tintColor: .systemRed
    )
    alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
    return alert
}

func CMMakeSnippetImportFailureAlert(_ error: Error) -> NSAlert {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Failed to parse XML file", comment: "")
    alert.informativeText = error.localizedDescription
    alert.accessoryView = makeSnippetAlertAccessory(
        kind: .importFailure,
        symbolName: "doc.badge.gearshape",
        tintColor: .systemOrange
    )
    alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
    return alert
}

func CMMakeSnippetExportFailureAlert(_ error: Error) -> NSAlert {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Could not write document out...", comment: "")
    alert.informativeText = error.localizedDescription
    alert.accessoryView = makeSnippetAlertAccessory(
        kind: .exportFailure,
        symbolName: "square.and.arrow.up.trianglebadge.exclamationmark",
        tintColor: .systemOrange
    )
    alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
    return alert
}

func CMMakeGenericSnippetAlert(messageText: String, informativeText: String) -> NSAlert {
    let alert = NSAlert()
    alert.messageText = messageText
    alert.informativeText = informativeText
    alert.accessoryView = makeSnippetAlertAccessory(
        title: messageText,
        detail: informativeText,
        symbolName: "exclamationmark.bubble",
        tintColor: .systemOrange
    )
    alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
    return alert
}

@discardableResult
func CMEndEditingForWindow(_ window: NSWindow?, showFailureAlert: Bool) -> Bool {
    guard let window else { return true }
    if let committed = FocusablePlainTextField.commitCurrentEditing(in: window), !committed {
        if showFailureAlert {
            let alert = CMMakeUnableToEndEditingAlert()
            CMShowAlert(alert, sheetFor: window)
        }
        return false
    }
    if window.makeFirstResponder(window) {
        return true
    }

    window.endEditing(for: nil)
    if window.firstResponder === window {
        return true
    }

    if showFailureAlert {
        let alert = CMMakeUnableToEndEditingAlert()
        CMShowAlert(alert, sheetFor: window)
    }

    return false
}

#if DEBUG
private var cmLastDebugAlertSnapshot: [String: Any]?
private var cmBypassAlertPresentationForDebug = false
private final class CMDebugInvalidEditingTextField: NSTextField {
    override func resignFirstResponder() -> Bool {
        false
    }
}

private final class CMDebugInvalidEditingHarness: NSObject, NSTextFieldDelegate {
    private weak var window: NSWindow?
    private var textField: NSTextField?

    func begin(in window: NSWindow?) -> Bool {
        end()
        guard let window,
              let contentView = window.contentView else {
            return false
        }

        let textField = CMDebugInvalidEditingTextField(frame: NSRect(x: 8, y: 8, width: 10, height: 10))
        textField.isBordered = false
        textField.drawsBackground = false
        textField.isBezeled = false
        textField.focusRingType = .none
        textField.isEditable = true
        textField.isSelectable = true
        textField.delegate = self
        textField.stringValue = ""
        contentView.addSubview(textField)
        guard window.makeFirstResponder(textField) else {
            textField.removeFromSuperview()
            return false
        }
        textField.selectText(nil)

        self.window = window
        self.textField = textField
        return true
    }

    func replaceText(_ value: String) -> Bool {
        guard let textField else { return false }
        if let editor = textField.currentEditor() {
            editor.string = value
        } else {
            textField.stringValue = value
        }
        return true
    }

    func end() {
        if let window, window.firstResponder === textField {
            window.makeFirstResponder(nil)
        }
        textField?.removeFromSuperview()
        textField = nil
        window = nil
    }

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        false
    }
}
private let cmDebugInvalidEditingHarness = CMDebugInvalidEditingHarness()

private func CMRecordAlertForDebug(_ alert: NSAlert) {
    cmLastDebugAlertSnapshot = [
        "messageText": alert.messageText,
        "informativeText": alert.informativeText,
        "buttonTitles": alert.buttons.map(\.title)
    ]
}

func CMResetLastAlertForDebug() {
    cmLastDebugAlertSnapshot = nil
}

func CMLastAlertSnapshotForDebug() -> [String: Any]? {
    cmLastDebugAlertSnapshot
}

func CMSetBypassAlertPresentationForDebug(_ bypass: Bool) {
    cmBypassAlertPresentationForDebug = bypass
}

private func CMShouldBypassAlertPresentationForDebug() -> Bool {
    cmBypassAlertPresentationForDebug
}

private func CMCollectEditableTextFieldsForDebug(in view: NSView) -> [NSTextField] {
    var fields: [NSTextField] = []
    if let textField = view as? NSTextField, textField.isEditable, !textField.isHidden {
        fields.append(textField)
    }
    for subview in view.subviews {
        fields.append(contentsOf: CMCollectEditableTextFieldsForDebug(in: subview))
    }
    return fields
}

@discardableResult
func CMBeginDebugInvalidEditing(in window: NSWindow?) -> Bool {
    cmDebugInvalidEditingHarness.begin(in: window)
}

@discardableResult
func CMReplaceDebugInvalidEditingText(_ value: String) -> Bool {
    cmDebugInvalidEditingHarness.replaceText(value)
}

func CMEndDebugInvalidEditing() {
    cmDebugInvalidEditingHarness.end()
}

@discardableResult
func CMBeginEditingFirstSnippetTextFieldForDebug(in window: NSWindow?) -> Bool {
    guard let contentView = window?.contentView,
          let textField = CMCollectEditableTextFieldsForDebug(in: contentView).first,
          let window = textField.window else {
        return false
    }
    guard window.makeFirstResponder(textField) else {
        return false
    }
    textField.selectText(nil)
    return true
}

@discardableResult
func CMReplaceEditingFirstSnippetTextFieldForDebug(_ value: String, in window: NSWindow?) -> Bool {
    guard let contentView = window?.contentView,
          let textField = CMCollectEditableTextFieldsForDebug(in: contentView).first else {
        return false
    }
    if let editor = textField.currentEditor() {
        editor.string = value
    } else {
        textField.stringValue = value
    }
    return true
}
#endif

final class ClipMenuUndoWindow: NSWindow {
    var providedUndoManager: (() -> UndoManager?)?

    override var undoManager: UndoManager? {
        providedUndoManager?() ?? super.undoManager
    }

    @objc func undo(_ sender: Any?) {
        undoManager?.undo()
    }

    @objc func redo(_ sender: Any?) {
        undoManager?.redo()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard flags == [.command] || flags == [.command, .shift] else {
            return super.performKeyEquivalent(with: event)
        }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "z":
            if flags.contains(.shift) {
                redo(nil)
            } else {
                undo(nil)
            }
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}

private final class PreferencesPresentationState: ObservableObject {
    @Published var selection: PreferenceTab?
    @Published var sidebarQuery = ""

    init() {
        resetForPresentation()
    }

    func resetForPresentation() {
        selection = CMInitialPreferenceTabSelection() ?? .general
        sidebarQuery = ""
    }
}

private enum CMForegroundWindowActivationPolicyBridge {
    private static var retainCount = 0
    private static var previousActivationPolicy: NSApplication.ActivationPolicy?

    static func retainRegularActivationPolicy() {
        if retainCount == 0 {
            previousActivationPolicy = NSApp.activationPolicy()
            if previousActivationPolicy != .regular {
                _ = NSApp.setActivationPolicy(.regular)
            }
        }
        retainCount += 1
    }

    static func releaseRegularActivationPolicy() {
        guard retainCount > 0 else { return }
        retainCount -= 1
        guard retainCount == 0 else { return }
        if let previousActivationPolicy {
            _ = NSApp.setActivationPolicy(previousActivationPolicy)
        }
        previousActivationPolicy = nil
    }
}

final class SwiftUIPreferencesWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SwiftUIPreferencesWindowController()
    private let presentationState = PreferencesPresentationState()

    private init() {
        let controller = NSHostingController(rootView: PreferencesView(state: presentationState))
        let window = NSWindow(contentViewController: controller)
        window.title = NSLocalizedString("Preferences", comment: "")
        window.setContentSize(NSSize(width: 1016, height: 640))
        window.minSize = NSSize(width: 820, height: 540)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.collectionBehavior = [.canJoinAllSpaces]
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = false
        window.isRestorable = false
        window.toolbarStyle = .preference
        super.init(window: window)
        window.delegate = self
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
            "selectedPaneIconSource": selectedTab.debugIconSourceName
        ]
    }

    func windowWillClose(_ notification: Notification) {
        if let window, !window.makeFirstResponder(window) {
            window.endEditing(for: nil)
        }
        RecordingPreferencesStore.shared.applyStoreTypes()
        ActionFileStore.shared.commitPendingChanges()
        ActionBehaviorDraft.shared.commitPendingSelections()
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
}

final class SwiftUISnippetEditorWindowController: NSWindowController, NSWindowDelegate {
    private let store = SnippetFileStore.shared
    private static let frameAutosaveName = "SnippetEditorWindow"
    private static let defaultContentSize = NSSize(width: 640, height: 480)
    private static let verticalDividerAutosaveName = "SnippetEditorVerticalDivider"
    private static let horizontalDividerAutosaveName = "SnippetEditorHorizontalDivider"
    private static let defaultVerticalPrimarySize: CGFloat = 244
    private static let defaultHorizontalPrimarySize: CGFloat = 235
    private var dirtyStateObserver: AnyCancellable?
    private var lastSelectionSnapshot: SnippetFileStore.SelectionSnapshot?
    private let restoredFrameOnInit: Bool

    init() {
        let controller = NSHostingController(rootView: SnippetEditorView(store: store))
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
            DispatchQueue.main.async(execute: applyTargetFrame)
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

private func CMCenteredWindowOriginForDebug(frameSize: NSSize, screen: NSScreen?) -> CGPoint {
    let targetScreen = screen ?? NSScreen.main
    let initialFrame = NSRect(origin: targetScreen?.frame.origin ?? .zero, size: frameSize)
    let probeWindow = NSWindow(
        contentRect: initialFrame,
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        screen: targetScreen
    )
    probeWindow.setFrame(NSRect(origin: initialFrame.origin, size: frameSize), display: false)
    probeWindow.center()
    return probeWindow.frame.origin
}

#if DEBUG
extension SwiftUISnippetEditorWindowController {
    static func debugFrameRestoreReport() -> [String: Any] {
        let defaults = UserDefaults.standard
        let frameKey = "NSWindow Frame \(frameAutosaveName)"
        let originalFrame = defaults.string(forKey: frameKey)

        defer {
            if let originalFrame {
                defaults.set(originalFrame, forKey: frameKey)
            } else {
                defaults.removeObject(forKey: frameKey)
            }
        }

        let seededRect = NSRect(x: 196, y: 188, width: 1112, height: 684)
        let seedController = SwiftUISnippetEditorWindowController()
        seedController.window?.setFrame(seededRect, display: false)
        seedController.window?.saveFrame(usingName: frameAutosaveName)

        let controller = SwiftUISnippetEditorWindowController()
        controller.showWindow(nil)
        guard let restoredWindow = controller.window else {
            return ["error": "Snippet Editor window not available", "matchesExpected": false]
        }

        let restoredFrame = restoredWindow.frame
        let expectedOrigin = CMCenteredWindowOriginForDebug(frameSize: restoredFrame.size, screen: restoredWindow.screen)
        let matchesExpected = abs(restoredFrame.origin.x - expectedOrigin.x) < 1.0
            && abs(restoredFrame.origin.y - expectedOrigin.y) < 1.0
            && abs(restoredFrame.size.width - seededRect.size.width) < 0.5
            && abs(restoredFrame.size.height - seededRect.size.height) < 0.5

        return [
            "seededFrame": [
                "x": seededRect.origin.x,
                "y": seededRect.origin.y,
                "width": seededRect.size.width,
                "height": seededRect.size.height
            ],
            "restoredFrame": [
                "x": restoredFrame.origin.x,
                "y": restoredFrame.origin.y,
                "width": restoredFrame.size.width,
                "height": restoredFrame.size.height
            ],
            "expectedCenteredOrigin": [
                "x": expectedOrigin.x,
                "y": expectedOrigin.y
            ],
            "matchesExpected": matchesExpected
        ]
    }

    static func debugDividerRestoreReport() -> [String: Any] {
        func flushMainRunLoop(_ count: Int = 1) {
            guard count > 0 else { return }
            for _ in 0..<count {
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            }
        }

        func currentSnippetEditorWindow() -> NSWindow? {
            let snippetEditorTitle = NSLocalizedString("Snippet Editor", comment: "")
            return NSApp.windows.first { window in
                window.title == snippetEditorTitle && !window.isMiniaturized
            }
        }

        @discardableResult
        func showSnippetEditorThroughAppController() -> NSWindow? {
            guard let appController = NSApp.delegate as? NSObject else { return nil }
            appController.perform(NSSelectorFromString("showSnippetEditor:"), with: nil)
            flushMainRunLoop(6)
            return currentSnippetEditorWindow()
        }

        let defaults = UserDefaults.standard
        let verticalKey = "SnippetEditorVerticalDivider"
        let horizontalKey = "SnippetEditorHorizontalDivider"
        let frameKey = "NSWindow Frame SnippetEditorWindow"
        let originalVertical = defaults.object(forKey: verticalKey)
        let originalHorizontal = defaults.object(forKey: horizontalKey)
        let originalFrame = defaults.object(forKey: frameKey)

        defer {
            if let originalVertical {
                defaults.set(originalVertical, forKey: verticalKey)
            } else {
                defaults.removeObject(forKey: verticalKey)
            }
            if let originalHorizontal {
                defaults.set(originalHorizontal, forKey: horizontalKey)
            } else {
                defaults.removeObject(forKey: horizontalKey)
            }
            if let originalFrame {
                defaults.set(originalFrame, forKey: frameKey)
            } else {
                defaults.removeObject(forKey: frameKey)
            }
        }

        defaults.removeObject(forKey: verticalKey)
        defaults.removeObject(forKey: horizontalKey)
        defaults.removeObject(forKey: frameKey)

        let seededVertical: CGFloat = 260
        let seededHorizontal: CGFloat = 210

        currentSnippetEditorWindow()?.close()
        flushMainRunLoop(2)

        guard let seedWindow = showSnippetEditorThroughAppController() else {
            return ["error": "Snippet Editor seed window not available", "matchesExpected": false]
        }

        seedWindow.setFrame(NSRect(x: 120, y: 120, width: 840, height: 620), display: false)
        seedWindow.displayIfNeeded()
        seedWindow.contentView?.layoutSubtreeIfNeeded()
        flushMainRunLoop()
        if let rootView = seedWindow.contentViewController?.view,
           let verticalSplit = CMFindSplitView(in: rootView, identifier: verticalKey),
           let horizontalSplit = CMFindSplitView(in: rootView, identifier: horizontalKey) {
            verticalSplit.setPosition(seededVertical, ofDividerAt: 0)
            horizontalSplit.setPosition(seededHorizontal, ofDividerAt: 0)
            rootView.layoutSubtreeIfNeeded()
            flushMainRunLoop()
        }

        let seededVerticalActual = (CMFindSplitView(in: seedWindow.contentViewController?.view ?? NSView(), identifier: verticalKey)?.subviews.first?.frame.width) ?? 0
        let seededHorizontalActual = (CMFindSplitView(in: seedWindow.contentViewController?.view ?? NSView(), identifier: horizontalKey)?.subviews.first?.frame.height) ?? 0
        defaults.set(Double(seededVerticalActual), forKey: verticalKey)
        defaults.set(Double(seededHorizontalActual), forKey: horizontalKey)
        seedWindow.saveFrame(usingName: frameAutosaveName)
        let savedFrameDescriptorAfterSeed = defaults.string(forKey: frameKey)
        seedWindow.close()
        flushMainRunLoop(2)

        guard let restoredWindow = showSnippetEditorThroughAppController() else {
            return ["error": "Snippet Editor restored window not available", "matchesExpected": false]
        }

        restoredWindow.displayIfNeeded()
        restoredWindow.contentView?.layoutSubtreeIfNeeded()
        flushMainRunLoop(20)

        guard let restoredRootView = restoredWindow.contentViewController?.view,
              let restoredVerticalSplit = CMFindSplitView(in: restoredRootView, identifier: verticalKey),
              let restoredHorizontalSplit = CMFindSplitView(in: restoredRootView, identifier: horizontalKey) else {
            return ["error": "Snippet Editor split views not available", "matchesExpected": false]
        }

        let restoredVertical = restoredVerticalSplit.subviews.first?.frame.width ?? 0
        let restoredHorizontal = restoredHorizontalSplit.subviews.first?.frame.height ?? 0
        let matchesExpected = abs(restoredVertical - seededVerticalActual) < 0.5
            && abs(restoredHorizontal - seededHorizontalActual) < 0.5

        return [
            "requestedVerticalPrimarySize": seededVertical,
            "requestedHorizontalPrimarySize": seededHorizontal,
            "seededVerticalPrimarySize": seededVerticalActual,
            "seededHorizontalPrimarySize": seededHorizontalActual,
            "savedFrameDescriptorAfterSeed": savedFrameDescriptorAfterSeed as Any,
            "restoredFrame": restoredWindow.frame.debugDescription,
            "restoredVerticalPrimarySize": restoredVertical,
            "restoredHorizontalPrimarySize": restoredHorizontal,
            "matchesExpected": matchesExpected
        ]
    }
}
#endif

private func CMFindSplitView(in view: NSView, identifier: String) -> NSSplitView? {
    if let splitView = view as? NSSplitView,
       splitView.identifier?.rawValue == identifier {
        return splitView
    }
    for subview in view.subviews {
        if let match = CMFindSplitView(in: subview, identifier: identifier) {
            return match
        }
    }
    return nil
}

func CMCollectTableViews(in view: NSView) -> [NSTableView] {
    var tables: [NSTableView] = []
    if let tableView = view as? NSTableView {
        tables.append(tableView)
    }
    for subview in view.subviews {
        tables.append(contentsOf: CMCollectTableViews(in: subview))
    }
    return tables
}

private func CMCollectTextViews(in view: NSView) -> [NSTextView] {
    var textViews: [NSTextView] = []
    if let textView = view as? NSTextView {
        textViews.append(textView)
    }
    for subview in view.subviews {
        textViews.append(contentsOf: CMCollectTextViews(in: subview))
    }
    return textViews
}

private func CMCollectSearchFields(in view: NSView) -> [NSSearchField] {
    var searchFields: [NSSearchField] = []
    if let searchField = view as? NSSearchField {
        searchFields.append(searchField)
    }
    for subview in view.subviews {
        searchFields.append(contentsOf: CMCollectSearchFields(in: subview))
    }
    return searchFields
}

private func CMCollectSnippetSearchFields(in view: NSView) -> [CMSnippetSearchField] {
    var searchFields: [CMSnippetSearchField] = []
    if let searchField = view as? CMSnippetSearchField {
        searchFields.append(searchField)
    }
    for subview in view.subviews {
        searchFields.append(contentsOf: CMCollectSnippetSearchFields(in: subview))
    }
    return searchFields
}

private func CMCollectSnippetContentTextViews(in view: NSView) -> [CMSnippetContentTextView] {
    var textViews: [CMSnippetContentTextView] = []
    if let textView = view as? CMSnippetContentTextView {
        textViews.append(textView)
    }
    for subview in view.subviews {
        textViews.append(contentsOf: CMCollectSnippetContentTextViews(in: subview))
    }
    return textViews
}

private func CMSnippetEditorTextAppearance(for textField: NSTextField?) -> [String: Any]? {
    guard let font = textField?.font else { return nil }
    return [
        "fontName": font.fontName,
        "fontSize": Int(font.pointSize.rounded())
    ]
}

private func CMCollectViewClassNames(in view: NSView, limit: Int) -> [String] {
    var names: [String] = []

    func walk(_ currentView: NSView) {
        guard names.count < limit else { return }
        names.append(String(describing: type(of: currentView)))
        for subview in currentView.subviews {
            guard names.count < limit else { return }
            walk(subview)
        }
    }

    walk(view)
    return names
}

extension SwiftUISnippetEditorWindowController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(saveDocument(_:)), #selector(save(_:)):
            return store.hasUnsavedChanges
        case #selector(saveDocumentAs(_:)), #selector(saveAs(_:)):
            return true
        case #selector(revertDocumentToSaved(_:)), #selector(revertToSaved(_:)):
            return store.hasUnsavedChanges
        default:
            return true
        }
    }
}

private enum PreferenceTab: String, CaseIterable, Identifiable {
    case general
    case menu
    case types
    case actions
    case shortcuts
    case updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return NSLocalizedString("General", comment: "")
        case .menu: return NSLocalizedString("Menu", comment: "")
        case .types:
            return NSLocalizedString("1086.label", tableName: "Preferences", bundle: .main, value: "Type", comment: "")
        case .actions: return NSLocalizedString("Action", comment: "")
        case .shortcuts:
            return NSLocalizedString("1366.title", tableName: "Preferences", bundle: .main, value: "Shortcuts", comment: "")
        case .updates: return NSLocalizedString("Updates", comment: "")
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .menu: return "list.bullet"
        case .types: return "app.badge"
        case .actions: return "bolt"
        case .shortcuts: return "keyboard"
        case .updates: return "arrow.triangle.2.circlepath"
        }
    }

    var legacyImageResourceName: String? {
        switch self {
        case .general:
            return nil
        case .menu:
            return "Menu.png"
        case .types:
            return "ComposingPreferences.tiff"
        case .actions:
            return "Action.tiff"
        case .shortcuts:
            return "PTKeyboardIcon.tiff"
        case .updates:
            return "SparkleIcon.tif"
        }
    }

    var legacyImageUsesTemplateRendering: Bool {
        switch self {
        case .menu, .actions, .updates:
            return false
        case .shortcuts:
            return true
        case .general, .types:
            return true
        }
    }

    var iconPrefersLegacyArtwork: Bool {
        legacyImageResourceName != nil
    }

    var debugIconSourceName: String {
        iconPrefersLegacyArtwork ? "legacyArtwork" : "systemSymbol"
    }

    var subtitle: String {
        switch self {
        case .general:
            return NSLocalizedString("Startup, history capture, paste behavior, and appearance.", comment: "")
        case .menu:
            return NSLocalizedString("Layout, numbering, tooltips, fonts, and menu visuals.", comment: "")
        case .types:
            return NSLocalizedString("Stored clipboard types, previews, and file type icons.", comment: "")
        case .actions:
            return NSLocalizedString("Action menu behavior, modifier clicks, and built-in actions and JavaScript actions.", comment: "")
        case .shortcuts:
            return NSLocalizedString("Global shortcuts for the main menu and snippets menu.", comment: "")
        case .updates:
            return NSLocalizedString("Automatic checks, channels, and update timing.", comment: "")
        }
    }

    var sidebarShortSummary: String {
        switch self {
        case .general:
            return NSLocalizedString("Startup and history", comment: "")
        case .menu:
            return NSLocalizedString("Layout and visuals", comment: "")
        case .types:
            return NSLocalizedString("Types and previews", comment: "")
        case .actions:
            return NSLocalizedString("Actions and modifiers", comment: "")
        case .shortcuts:
            return NSLocalizedString("Global hotkeys", comment: "")
        case .updates:
            return NSLocalizedString("Checks and channels", comment: "")
        }
    }

    var sidebarAccentColor: Color {
        switch self {
        case .general: return Color(NSColor.systemBlue)
        case .menu: return Color(NSColor.systemIndigo)
        case .types: return Color(NSColor.systemTeal)
        case .actions: return Color(NSColor.systemOrange)
        case .shortcuts: return Color(NSColor.systemGreen)
        case .updates: return Color(NSColor.systemPurple)
        }
    }

    var legacySidebarImage: NSImage? {
        guard let legacyImageResourceName else { return nil }
        let fallbackName = (legacyImageResourceName as NSString).deletingPathExtension
        guard let sourceImage = NSImage(named: legacyImageResourceName) ?? NSImage(named: fallbackName),
              let copiedImage = sourceImage.copy() as? NSImage else {
            return nil
        }
        copiedImage.isTemplate = legacyImageUsesTemplateRendering
        return copiedImage
    }
}

func CMConfiguredPreferencePaneTitlesForDebug() -> [String] {
    PreferenceTab.allCases.map(\.title)
}

private func CMVisiblePreferenceTabsForDebug(query: String) -> [PreferenceTab] {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else {
        return PreferenceTab.allCases
    }

    let needle = trimmedQuery.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    return PreferenceTab.allCases.filter { tab in
        [tab.title, tab.subtitle, tab.sidebarShortSummary].contains { value in
            value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(needle)
        }
    }
}

private func CMPreferenceTab(debugRawValue: String) -> PreferenceTab? {
    switch debugRawValue
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased() {
    case "general":
        return .general
    case "menu":
        return .menu
    case "type", "types":
        return .types
    case "action", "actions":
        return .actions
    case "shortcut", "shortcuts":
        return .shortcuts
    case "update", "updates":
        return .updates
    default:
        return nil
    }
}

private func CMInitialPreferenceTabSelection() -> PreferenceTab? {
#if DEBUG
    let arguments = ProcessInfo.processInfo.arguments
    if let index = arguments.firstIndex(of: "-debugShowPreferencesTab"),
       arguments.indices.contains(arguments.index(after: index)) {
        let value = arguments[arguments.index(after: index)].trimmingCharacters(in: .whitespacesAndNewlines)
        if let tab = CMPreferenceTab(debugRawValue: value) {
            return tab
        }
    }
#endif
    return .general
}

func CMPreferencesShellSnapshotForDebug() -> [String: Any] {
    let selectedTab = CMInitialPreferenceTabSelection() ?? .general
    let visibleTabs = PreferenceTab.allCases
    return [
        "visiblePaneTitles": visibleTabs.map(\.title),
        "visiblePaneIconSources": Dictionary(
            uniqueKeysWithValues: visibleTabs.map { ($0.title, $0.debugIconSourceName) }
        ),
        "selectedPaneTitle": selectedTab.title,
        "selectedPaneIconSource": selectedTab.debugIconSourceName
    ]
}

private struct PreferencesView: View {
    @ObservedObject var state: PreferencesPresentationState

    var body: some View {
        VStack(spacing: 0) {
            PreferencesTabBar(selection: Binding(
                get: { state.selection ?? .general },
                set: { state.selection = $0 }
            ))

            Divider()

            if let selection = state.selection {
                selectedPane(for: selection)
            } else {
                VStack(alignment: .center, spacing: 10) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text(CMPreferencesEmptySelectionTitle())
                        .font(.headline)
                    Text(CMPreferencesEmptySelectionDetail())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if state.selection == nil {
                state.selection = .general
            }
        }
    }

    @ViewBuilder
    private func selectedPane(for selection: PreferenceTab) -> some View {
        switch selection {
        case .general:
            GeneralPreferencesView()
        case .menu:
            MenuPreferencesView()
        case .types:
            TypePreferencesView()
        case .actions:
            ActionPreferencesView()
        case .shortcuts:
            ShortcutsPreferencesView()
        case .updates:
            UpdatePreferencesView()
        }
    }
}

private struct PreferencesTabBar: View {
    @Binding var selection: PreferenceTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(PreferenceTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    PreferenceTabIcon(
                        tab: tab,
                        size: 18,
                        foregroundColor: selection == tab ? tab.sidebarAccentColor : Color.secondary
                    )
                    .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .help(tab.title)
                .accessibilityLabel(Text(tab.title))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PreferenceTabIcon: View {
    let tab: PreferenceTab
    let size: CGFloat
    let foregroundColor: Color

    var body: some View {
        Group {
            if let image = tab.legacySidebarImage {
                if tab.legacyImageUsesTemplateRendering {
                    Image(nsImage: image)
                        .renderingMode(.template)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .foregroundColor(foregroundColor)
                        .padding(tab.iconPrefersLegacyArtwork ? max(2, size * 0.14) : 0)
                } else {
                    Image(nsImage: image)
                        .renderingMode(.original)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .padding(tab.iconPrefersLegacyArtwork ? max(2, size * 0.14) : 0)
                }
            } else {
                Image(systemName: tab.systemImage)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundColor(foregroundColor)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct TypePreferencesView: View {
    @ObservedObject private var store = RecordingPreferencesStore.shared
    @AppStorage(CMPrefShowImageInTheMenuKey) private var showImages = true
    @AppStorage(CMPrefThumbnailWidthKey) private var thumbnailWidth = 100
    @AppStorage(CMPrefThumbnailHeightKey) private var thumbnailHeight = 32
    @AppStorage(CMPrefShowIconInTheMenuKey) private var showIcons = true
    @AppStorage(CMPrefMenuIconSizeKey) private var menuIconSize = 16

    var body: some View {
        PreferencePane {
            StoreTypePreferencesViewContent()
            IconPreferencesViewContent()
        }
    }
}

private struct PreferencePane<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                content
            }
            .padding(.horizontal, 40)
            .padding(.top, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: 760, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct PreferenceSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
        }
    }
}

private struct PreferenceToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .toggleStyle(.checkbox)
            .controlSize(.regular)
    }
}

private struct PreferenceRow<Control: View>: View {
    let title: String
    let control: Control

    init(_ title: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 258, alignment: .trailing)
                .foregroundColor(.primary)
            control
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

func CMPasteAutomationPreferencesSnapshotForDebug(inputPasteCommand: Bool) -> [String: Any] {
    let accessibilityGranted = AXIsProcessTrusted()
    let postEventGranted = CGPreflightPostEventAccess()
    let grantedCount = accessibilityGranted ? 1 : 0
    let isReady = accessibilityGranted

    let detail: String = {
        if !inputPasteCommand {
            return NSLocalizedString("Automatic paste is currently off, but permission readiness is still shown here.", comment: "")
        }
        return isReady
            ? NSLocalizedString("ClipMenu can send Command-V automatically after menu item selection.", comment: "")
            : NSLocalizedString("macOS still needs permission before automatic paste can drive the keyboard on your behalf.", comment: "")
    }()

    return [
        "title": NSLocalizedString("Automatic Paste Permissions", comment: ""),
        "detail": detail,
        "badges": [
            inputPasteCommand
                ? NSLocalizedString("Auto-paste on", comment: "")
                : NSLocalizedString("Auto-paste off", comment: ""),
            isReady
                ? NSLocalizedString("Ready to Paste", comment: "")
                : NSLocalizedString("Setup Needed", comment: ""),
            String(format: NSLocalizedString("%d of %d granted", comment: ""), grantedCount, 1)
        ],
        "states": [
            "inputPasteCommand": inputPasteCommand,
            "accessibilityGranted": accessibilityGranted,
            "postEventGranted": postEventGranted,
            "grantedCount": grantedCount,
            "isReady": isReady
        ]
    ]
}

func CMObserveIntervalPreferencesSnapshotForDebug(timeInterval: Double) -> [String: Any] {
    let normalizedTimeInterval = CMNormalizedLegacyObserveInterval(timeInterval)
    let secondsLabel = NSLocalizedString("689.title", tableName: "Preferences", bundle: .main, value: "sec.", comment: "")
    let formattedInterval = String(format: "%.2f %@", normalizedTimeInterval, secondsLabel)

    let cadence: (key: String, badge: String, detail: String) = {
        if normalizedTimeInterval <= 0.20 {
            return (
                "fast",
                NSLocalizedString("Fast capture", comment: ""),
                NSLocalizedString("ClipMenu checks the clipboard as often as possible for the quickest capture.", comment: "")
            )
        }
        if normalizedTimeInterval <= 0.75 {
            return (
                "balanced",
                NSLocalizedString("Balanced polling", comment: ""),
                NSLocalizedString("ClipMenu balances quick capture with steadier background activity.", comment: "")
            )
        }
        return (
            "light",
            NSLocalizedString("Light background load", comment: ""),
            NSLocalizedString("ClipMenu checks less often to keep background activity light.", comment: "")
        )
    }()

    return [
        "title": NSLocalizedString("Clipboard polling interval", comment: ""),
        "detail": cadence.detail,
        "badges": [
            formattedInterval,
            cadence.badge
        ],
        "states": [
            "timeInterval": normalizedTimeInterval,
            "cadence": cadence.key
        ]
    ]
}

func CMHistoryRetentionPreferencesSnapshotForDebug(
    maxHistorySize: Int,
    autosaveDelay: Int,
    saveHistoryOnQuit: Bool
) -> [String: Any] {
    let normalizedMaxHistorySize = CMNormalizedLegacyMaxHistorySize(maxHistorySize)
    let normalizedAutosaveDelay = CMNormalizedLegacyAutosaveDelay(autosaveDelay)

    let autosaveSummary: String = {
        if normalizedAutosaveDelay == 0 {
            return NSLocalizedString("Autosave Never", comment: "")
        }
        if normalizedAutosaveDelay == 60 {
            return NSLocalizedString("Autosave 1 min", comment: "")
        }
        if normalizedAutosaveDelay < 3600 {
            return String(format: NSLocalizedString("Autosave %d min", comment: ""), normalizedAutosaveDelay / 60)
        }
        if normalizedAutosaveDelay == 86400 {
            return NSLocalizedString("Autosave 1 day", comment: "")
        }
        return String(format: NSLocalizedString("Autosave %d hr", comment: ""), normalizedAutosaveDelay / 3600)
    }()

    let detail: String = {
        if normalizedAutosaveDelay == 0 {
            return String(
                format: NSLocalizedString("ClipMenu keeps up to %d history items and saves them only when you ask it to.", comment: ""),
                normalizedMaxHistorySize
            )
        }
        return String(
            format: NSLocalizedString("ClipMenu keeps up to %1$d history items and saves them on the selected %2$@ cadence.", comment: ""),
            normalizedMaxHistorySize,
            autosaveSummary
        )
    }()

    return [
        "title": NSLocalizedString("History retention", comment: ""),
        "detail": detail,
        "badges": [
            "\(normalizedMaxHistorySize) \(NSLocalizedString("1171.title", tableName: "Preferences", bundle: .main, value: "items", comment: ""))",
            autosaveSummary,
            CMGeneralQuitPersistenceBadgeTitle(saveHistoryOnQuit: saveHistoryOnQuit)
        ],
        "states": [
            "maxHistorySize": normalizedMaxHistorySize,
            "autosaveDelay": normalizedAutosaveDelay,
            "saveHistoryOnQuit": saveHistoryOnQuit
        ]
    ]
}

func CMCaptureRulesPreferencesSnapshotForDebug(
    reorderClipsAfterPasting: Bool,
    excludedApps: [String]
) -> [String: Any] {
    let normalizedSortByLastUsed = CMNormalizedLegacyReorderClipsAfterPastingValue(reorderClipsAfterPasting)
    let sortBadge = CMGeneralSortOrderBadgeTitle(sortByLastUsed: normalizedSortByLastUsed)
    let captureBadge = excludedApps.isEmpty
        ? NSLocalizedString("Capture open to all apps", comment: "")
        : NSLocalizedString("Capture filtered by app", comment: "")

    let detail: String = {
        if excludedApps.isEmpty {
            return normalizedSortByLastUsed
                ? NSLocalizedString("ClipMenu keeps clips from every app and reorders them by last use after pasting.", comment: "")
                : NSLocalizedString("ClipMenu keeps clips from every app and leaves them ordered by date created.", comment: "")
        }
        if excludedApps.count == 1 {
            return String(
                format: normalizedSortByLastUsed
                    ? NSLocalizedString("ClipMenu skips %@ while still reordering pasted clips by last use.", comment: "")
                    : NSLocalizedString("ClipMenu skips %@ while preserving date-created ordering.", comment: ""),
                excludedApps[0]
            )
        }
        return String(
            format: normalizedSortByLastUsed
                ? NSLocalizedString("ClipMenu skips %1$d apps while still reordering pasted clips by last use.", comment: "")
                : NSLocalizedString("ClipMenu skips %1$d apps while preserving date-created ordering.", comment: ""),
            excludedApps.count
        )
    }()

    return [
        "title": NSLocalizedString("Capture rules", comment: ""),
        "detail": detail,
        "badges": [
            sortBadge,
            captureBadge
        ],
        "states": [
            "sortByLastUsed": normalizedSortByLastUsed,
            "excludedAppsCount": excludedApps.count
        ]
    ]
}

private final class PasteAutomationStatusModel: ObservableObject {
    @Published var accessibilityGranted = false
    @Published var postEventGranted = false

    init() {
        refresh()
    }

    var isFullyGranted: Bool {
        accessibilityGranted
    }

    var canPostEvents: Bool {
        accessibilityGranted || postEventGranted
    }

    func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        postEventGranted = CGPreflightPostEventAccess()
    }

    func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        _ = CGRequestPostEventAccess()
        refresh()
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private struct PermissionStatusBadge: View {
    let title: String
    let detail: String
    let isGranted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(isGranted ? .green : .orange)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(isGranted ? NSLocalizedString("Ready", comment: "") : NSLocalizedString("Needs Access", comment: ""))
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text(detail)
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct UpdateStatusBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption)
        }
        .foregroundColor(tint)
    }
}

private struct UpdateWorkflowStageView: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 68, alignment: .leading)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
            }

            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 76)
        }
    }
}

private struct CMUpdateWorkflowStage {
    let title: String
    let value: String
    let detail: String

    var debugDictionary: [String: String] {
        [
            "title": title,
            "value": value,
            "detail": detail
        ]
    }
}

private func CMUpdatesLastCheckedDisplay(_ date: Date?) -> String {
    guard let date else { return CMUpdatesNeverCheckedDisplayTitle() }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

private func CMUpdatesWorkflowStages(
    automaticChecks: Bool,
    preReleases: Bool,
    interval: Int,
    coordinator: UpdateCoordinator
) -> [CMUpdateWorkflowStage] {
    let visibleIntervalTitle = CMVisibleUpdateIntervalOptions()
        .first(where: { $0.value == CMVisibleUpdateIntervalSelectionValue(for: interval) })?
        .title
        ?? NSLocalizedString("Daily", comment: "")
    let lastCheckedPrefix = NSLocalizedString("Last checked", comment: "")
    let lastCheckedValue = CMUpdatesLastCheckedDisplay(coordinator.lastCheckDate)

    let modeValue = automaticChecks
        ? NSLocalizedString("Automatic checks on", comment: "")
        : NSLocalizedString("Manual only", comment: "")
    let modeDetail = automaticChecks
        ? NSLocalizedString("Scheduled checks are enabled.", comment: "")
        : NSLocalizedString("Check manually whenever you want to review updates.", comment: "")

    let channelValue: String
    let channelDetail: String
    if coordinator.feedURL == nil {
        channelValue = NSLocalizedString("Unavailable", comment: "")
        channelDetail = NSLocalizedString("No update feed is currently available.", comment: "")
    } else if preReleases {
        channelValue = NSLocalizedString("Pre-release", comment: "")
        channelDetail = NSLocalizedString("Pre-release updates are included.", comment: "")
    } else {
        channelValue = NSLocalizedString("Stable", comment: "")
        channelDetail = NSLocalizedString("Stable releases only.", comment: "")
    }

    let intervalDetail = CMVisibleUpdateIntervalOptions().contains(where: { $0.value == interval })
        ? NSLocalizedString("Daily, weekly, or monthly cadence is selected.", comment: "")
        : CMImportedUpdateIntervalNoticeTitle(for: interval)

    let checkNowValue: String
    if coordinator.isChecking {
        checkNowValue = NSLocalizedString("Checking now", comment: "")
    } else if automaticChecks && coordinator.feedURL != nil {
        checkNowValue = NSLocalizedString("Ready", comment: "")
    } else {
        checkNowValue = NSLocalizedString("Unavailable", comment: "")
    }
    let checkNowDetail = "\(lastCheckedPrefix): \(lastCheckedValue)"

    return [
        CMUpdateWorkflowStage(
            title: NSLocalizedString("Mode", comment: ""),
            value: modeValue,
            detail: modeDetail
        ),
        CMUpdateWorkflowStage(
            title: NSLocalizedString("Channel", comment: ""),
            value: channelValue,
            detail: channelDetail
        ),
        CMUpdateWorkflowStage(
            title: NSLocalizedString("Interval", comment: ""),
            value: visibleIntervalTitle,
            detail: intervalDetail
        ),
        CMUpdateWorkflowStage(
            title: NSLocalizedString("Check Now", comment: ""),
            value: checkNowValue,
            detail: checkNowDetail
        )
    ]
}

private struct PasteAutomationPreferencesView: View {
    @StateObject private var status = PasteAutomationStatusModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(statusSummaryText)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                PermissionStatusBadge(
                    title: NSLocalizedString("Accessibility", comment: ""),
                    detail: NSLocalizedString("Lets ClipMenu control Command-V in the frontmost app.", comment: ""),
                    isGranted: status.accessibilityGranted
                )
                PermissionStatusBadge(
                    title: NSLocalizedString("Post Events", comment: ""),
                    detail: NSLocalizedString("Uses paste automation access for synthetic keyboard events after a menu selection.", comment: ""),
                    isGranted: status.canPostEvents
                )
            }

            HStack(spacing: 8) {
                automationSecondaryButton(
                    title: NSLocalizedString("Request Access", comment: ""),
                    systemImage: "hand.tap",
                    action: status.requestAccess
                )
                automationSecondaryButton(
                    title: NSLocalizedString("Open Accessibility Settings", comment: ""),
                    systemImage: "gearshape",
                    action: status.openAccessibilitySettings
                )
                automationSecondaryButton(
                    title: NSLocalizedString("Refresh Status", comment: ""),
                    systemImage: "arrow.clockwise",
                    action: status.refresh
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            status.refresh()
        }
    }

    private var statusSummaryText: String {
        status.isFullyGranted
            ? NSLocalizedString("ClipMenu can send Command-V automatically after menu item selection.", comment: "")
            : NSLocalizedString("macOS still needs permission before automatic paste can drive the keyboard on your behalf.", comment: "")
    }

    private func automationSecondaryButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
    }
}

private struct PreferenceStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let suffix: String?

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.allowsFloats = false
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    init(_ title: String, value: Binding<Int>, in range: ClosedRange<Int>, step: Int = 1, suffix: String? = nil) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.suffix = suffix
    }

    var body: some View {
        PreferenceRow(title) {
            HStack(spacing: 10) {
                TextField("", value: $value, formatter: Self.integerFormatter)
                    .textFieldStyle(PlainTextFieldStyle())
                    .multilineTextAlignment(.trailing)
                    .font(.system(.body, design: .monospaced))
                    .preferenceValueFieldFrame(width: 76)
                    .onChange(of: value) { newValue in
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
                if let suffix {
                    Text(suffix)
                        .foregroundColor(.secondary)
                }
                Stepper("", value: $value, in: range, step: step)
                    .labelsHidden()
            }
        }
    }
}

private struct PreferenceDoubleField: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    var body: some View {
        TextField("", value: $value, formatter: Self.decimalFormatter)
            .textFieldStyle(PlainTextFieldStyle())
            .multilineTextAlignment(.trailing)
            .font(.system(.body, design: .monospaced))
            .preferenceValueFieldFrame(width: 76)
            .onChange(of: value) { newValue in
                value = min(max(newValue, range.lowerBound), range.upperBound)
            }
    }
}

private struct PreferencePicker<Selection: Hashable, Content: View>: View {
    @Binding var selection: Selection
    let width: CGFloat
    let content: Content

    init(selection: Binding<Selection>, width: CGFloat, @ViewBuilder content: () -> Content) {
        self._selection = selection
        self.width = width
        self.content = content()
    }

    var body: some View {
        Picker(selection: $selection) {
            content
        } label: {
            EmptyView()
        }
        .labelsHidden()
        .pickerStyle(MenuPickerStyle())
        .fixedSize()
        .frame(width: width, alignment: .leading)
    }
}

private struct PreferenceValueFieldFrame: ViewModifier {
    let width: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .frame(width: width)
    }
}

private extension View {
    func preferenceValueFieldFrame(width: CGFloat) -> some View {
        modifier(PreferenceValueFieldFrame(width: width))
    }
}

private struct HotKeyRecorderControl: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var modifierFlags: Int

    func makeNSView(context: Context) -> HotKeyRecorderNSView {
        let view = HotKeyRecorderNSView()
        view.onCapture = { keyCode, modifierFlags in
            self.keyCode = keyCode
            self.modifierFlags = modifierFlags
        }
        return view
    }

    func updateNSView(_ view: HotKeyRecorderNSView, context: Context) {
        view.keyCode = keyCode
        view.modifierFlags = modifierFlags
        view.onCapture = { keyCode, modifierFlags in
            self.keyCode = keyCode
            self.modifierFlags = modifierFlags
        }
        view.refresh()
    }
}

private final class HotKeyRecorderNSView: NSView {
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

    fileprivate static func keyName(for keyCode: Int) -> String {
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

private func HotKeyRecorderDisplayString(keyCode: Int, modifierFlags: Int) -> String {
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
    return parts + HotKeyRecorderNSView.keyName(for: keyCode)
}

func CMHotKeyDisplayStringForDebug(keyCode: Int, modifierFlags: Int) -> String {
    HotKeyRecorderDisplayString(keyCode: keyCode, modifierFlags: modifierFlags)
}

func CMShortcutsPreferenceSnapshotForDebug() -> [String: Any] {
    let defaults = UserDefaults.standard

    let clipEnabled = defaults.object(forKey: CMPrefHotKeyEnabledKey) as? Bool ?? true
    let clipKeyCode = clipEnabled ? defaults.object(forKey: CMPrefHotKeyKeyCodeKey) as? Int ?? 9 : -1
    let clipModifierFlags = clipEnabled
        ? defaults.object(forKey: CMPrefHotKeyModifierFlagsKey) as? Int
            ?? Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
        : 0

    let snippetsEnabled = defaults.object(forKey: CMPrefSnippetsHotKeyEnabledKey) as? Bool ?? true
    let snippetsKeyCode = snippetsEnabled ? defaults.object(forKey: CMPrefSnippetsHotKeyKeyCodeKey) as? Int ?? 11 : -1
    let snippetsModifierFlags = snippetsEnabled
        ? defaults.object(forKey: CMPrefSnippetsHotKeyModifierFlagsKey) as? Int
            ?? Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
        : 0

    let historyDisplay = HotKeyRecorderDisplayString(
        keyCode: 9,
        modifierFlags: Int(NSEvent.ModifierFlags([.command, .control]).rawValue)
    )
    return [
        "paneTitle": NSLocalizedString("1366.title", tableName: "Preferences", bundle: .main, value: "Shortcuts", comment: ""),
        "sectionTitle": NSLocalizedString("1366.title", tableName: "Preferences", bundle: .main, value: "Shortcuts", comment: ""),
        "rows": [
            [
                "title": NSLocalizedString("1371.title", tableName: "Preferences", bundle: .main, value: "ClipMenu:", comment: ""),
                "display": HotKeyRecorderDisplayString(keyCode: clipKeyCode, modifierFlags: clipModifierFlags)
            ],
            [
                "title": NSLocalizedString("1372.title", tableName: "Preferences", bundle: .main, value: "Snippets menu:", comment: ""),
                "display": HotKeyRecorderDisplayString(keyCode: snippetsKeyCode, modifierFlags: snippetsModifierFlags)
            ]
        ],
        "visibleRowTitles": [
            NSLocalizedString("1371.title", tableName: "Preferences", bundle: .main, value: "ClipMenu:", comment: ""),
            NSLocalizedString("1372.title", tableName: "Preferences", bundle: .main, value: "Snippets menu:", comment: "")
        ],
        "hiddenHistoryShortcutDisplay": historyDisplay,
        "reservedHistoryBadge": CMShortcutReservedHistoryBadgeTitle(historyDisplay: historyDisplay)
    ]
}

func CMMenuPreferencesSnapshotForDebug() -> [String: Any] {
    let defaults = UserDefaults.standard

    let maxTitleLength = CMNormalizedLegacyMenuTitleLength(
        defaults.object(forKey: CMPrefMaxMenuItemTitleLengthKey) as? Int ?? 20
    )
    let inlineItems = CMNormalizedLegacyMenuInlineItemsCount(
        defaults.object(forKey: CMPrefNumberOfItemsPlaceInlineKey) as? Int ?? 0
    )
    let folderItems = CMNormalizedLegacyMenuFolderItemsCount(
        defaults.object(forKey: CMPrefNumberOfItemsPlaceInsideFolderKey) as? Int ?? 10
    )
    let markWithNumbers = defaults.object(forKey: CMPrefMenuItemsAreMarkedWithNumbersKey) as? Bool ?? true
    let titleStartsWithZero = defaults.object(forKey: CMPrefMenuItemsTitleStartWithZeroKey) as? Bool ?? false
    let numericKeyEquivalents = defaults.object(forKey: CMPrefAddNumericKeyEquivalentsKey) as? Bool ?? false
    let showLabels = defaults.object(forKey: CMPrefShowLabelsInMenuKey) as? Bool ?? true
    let clearHistoryItem = defaults.object(forKey: CMPrefAddClearHistoryMenuItemKey) as? Bool ?? true
    let alertBeforeClear = defaults.object(forKey: CMPrefShowAlertBeforeClearHistoryKey) as? Bool ?? true
    let showTooltips = defaults.object(forKey: CMPrefShowToolTipOnMenuItemKey) as? Bool ?? true
    let maxTooltipLength = CMNormalizedLegacyMenuTooltipLength(
        defaults.object(forKey: CMPrefMaxLengthOfToolTipKey) as? Int ?? 200
    )
    let changeFontSize = defaults.object(forKey: CMPrefChangeFontSizeKey) as? Bool ?? false
    let howToChangeFontSize = CMNormalizedMenuLegacyFontSizingMode(
        defaults.object(forKey: CMPrefHowToChangeFontSizeKey) as? Int ?? 0
    )
    let selectedFontSize = CMNormalizedMenuLegacyFontSize(
        defaults.object(forKey: CMPrefSelectedFontSizeKey) as? Int ?? 16
    )
    let previewFirstIndex = titleStartsWithZero ? 0 : 1
    let previewHistorySource = NSLocalizedString("This is a very long history clip title that wraps past the visible menu limit.", comment: "")
    let previewSnippetSource = NSLocalizedString("Reusable snippet for previews", comment: "")
    let previewHeaders = showLabels
        ? [NSLocalizedString("History", comment: ""), NSLocalizedString("Snippets", comment: "")]
        : []
    let previewHistoryRowTitle = CMMenuPreviewNumberedTitle(
        CMMenuPreviewTrimmedTitle(previewHistorySource, limit: maxTitleLength),
        listNumber: previewFirstIndex,
        markWithNumbers: markWithNumbers
    )
    let previewSnippetRowTitle = CMMenuPreviewNumberedTitle(
        CMMenuPreviewTrimmedTitle(previewSnippetSource, limit: maxTitleLength),
        listNumber: previewFirstIndex,
        markWithNumbers: markWithNumbers
    )
    let previewHistoryKeyEquivalent = CMMenuPreviewKeyEquivalent(
        index: 0,
        markWithNumbers: markWithNumbers,
        startsFromZero: titleStartsWithZero
    )
    let previewTooltip = CMMenuPreviewTooltip(
        text: previewHistorySource,
        maxLength: maxTooltipLength,
        showTooltips: showTooltips
    )

    let legacyMenuCharacterUnitLabel = NSLocalizedString("1173.title", tableName: "Preferences", bundle: .main, value: "chars", comment: "")
    let legacyToolTipCharacterUnitLabel = NSLocalizedString("1259.title", tableName: "Preferences", bundle: .main, value: "chars", comment: "")
    let legacyPointUnitLabel = NSLocalizedString("742.title", tableName: "Preferences", bundle: .main, value: "pt", comment: "")

    return [
        "paneTitle": NSLocalizedString("Menu", comment: ""),
        "sectionTitles": [
            NSLocalizedString("Layout", comment: ""),
            NSLocalizedString("Menu Items", comment: ""),
            NSLocalizedString("Tooltips", comment: ""),
            NSLocalizedString("Font", comment: "")
        ],
        "layout": [
            "controlTitles": [
                NSLocalizedString("703.title", tableName: "Preferences", bundle: .main, value: "Number of characters in the menu:", comment: ""),
                NSLocalizedString("1028.title", tableName: "Preferences", bundle: .main, value: "Number of items place inline:", comment: ""),
                NSLocalizedString("1034.title", tableName: "Preferences", bundle: .main, value: "Number of items place inside a folder:", comment: "")
            ],
            "unitTitles": [
                legacyMenuCharacterUnitLabel,
                NSLocalizedString("1175.title", tableName: "Preferences", bundle: .main, value: "items", comment: ""),
                NSLocalizedString("1177.title", tableName: "Preferences", bundle: .main, value: "items", comment: "")
            ],
            "values": [
                "maxTitleLength": maxTitleLength,
                "inlineItems": inlineItems,
                "folderItems": folderItems
            ]
        ],
        "menuRowPreview": [
            "title": NSLocalizedString("Current Menu Row Preview", comment: ""),
            "detail": NSLocalizedString("Menu rows reflect numbering, labels, key equivalents, and tooltip trimming from the active settings.", comment: ""),
            "badges": [
                markWithNumbers
                    ? (titleStartsWithZero ? NSLocalizedString("Numbered from 0", comment: "") : NSLocalizedString("Numbered from 1", comment: ""))
                    : NSLocalizedString("Titles only", comment: ""),
                CMMenuNumericShortcutsBadge(enabled: numericKeyEquivalents),
                CMMenuLabelsBadge(shown: showLabels),
                CMMenuTooltipsBadge(enabled: showTooltips)
            ],
            "headers": previewHeaders,
            "historyRowTitle": previewHistoryRowTitle,
            "historyRowKeyEquivalent": previewHistoryKeyEquivalent,
            "snippetFolderTitle": "QA",
            "snippetRowTitle": previewSnippetRowTitle,
            "tooltipPreview": previewTooltip as Any
        ],
        "menuItems": [
            "toggleTitles": [
                NSLocalizedString("706.title", tableName: "Preferences", bundle: .main, value: "Mark menu items with numbers", comment: ""),
                NSLocalizedString("705.title", tableName: "Preferences", bundle: .main, value: "Menu items' title starts with 0", comment: ""),
                NSLocalizedString("743.title", tableName: "Preferences", bundle: .main, value: "Add key equivalents to numeric keys", comment: ""),
                NSLocalizedString("1044.title", tableName: "Preferences", bundle: .main, value: "Show labels to indicate item types", comment: ""),
                NSLocalizedString("701.title", tableName: "Preferences", bundle: .main, value: "Add a menu item to clear clipboard history", comment: ""),
                NSLocalizedString("702.title", tableName: "Preferences", bundle: .main, value: "Show alert panel before clear history", comment: "")
            ],
            "states": [
                "markWithNumbers": markWithNumbers,
                "titleStartsWithZero": titleStartsWithZero,
                "numericKeyEquivalents": numericKeyEquivalents,
                "showLabels": showLabels,
                "clearHistoryItem": clearHistoryItem,
                "alertBeforeClear": alertBeforeClear
            ],
            "controlStates": [
                "titleStartsWithZeroEnabled": markWithNumbers,
                "alertBeforeClearEnabled": clearHistoryItem
            ]
        ],
        "tooltips": [
            "toggleTitle": NSLocalizedString("1157.title", tableName: "Preferences", bundle: .main, value: "Show tool tip on a menu item", comment: ""),
            "maxLengthTitle": NSLocalizedString("1256.title", tableName: "Preferences", bundle: .main, value: "Max length of tool tip string:", comment: ""),
            "unitTitle": legacyToolTipCharacterUnitLabel,
            "showTooltips": showTooltips,
            "maxTooltipLength": maxTooltipLength,
            "maxLengthEnabled": showTooltips
        ],
        "font": [
            "toggleTitle": NSLocalizedString("744.title", tableName: "Preferences", bundle: .main, value: "Change font size in the menu", comment: ""),
            "unitTitle": legacyPointUnitLabel,
            "changeFontSize": changeFontSize,
            "howToChangeFontSize": howToChangeFontSize,
            "selectedSize": selectedFontSize,
            "modeSelectorEnabled": changeFontSize,
            "sizePickerEnabled": changeFontSize && howToChangeFontSize == 1,
            "sizeOptions": CMMenuLegacyFontSizeOptions().map(String.init),
            "pickerModes": [
                NSLocalizedString("1238.title", tableName: "Preferences", bundle: .main, value: "Fit to the icon size", comment: ""),
                NSLocalizedString("1239.title", tableName: "Preferences", bundle: .main, value: "Select:", comment: "")
            ]
        ]
    ]
}

func CMMenuLegacyFontSizeOptions() -> [Int] {
    [9, 16, 32, 48]
}

func CMNormalizedMenuLegacyFontSizingMode(_ value: Int) -> Int {
    value == 1 ? 1 : 0
}

func CMNormalizedLegacyMenuTooltipLength(_ value: Int) -> Int {
    max(1, value)
}

func CMNormalizedLegacyMenuTitleLength(_ value: Int) -> Int {
    max(1, value)
}

func CMNormalizedLegacyMenuFolderItemsCount(_ value: Int) -> Int {
    max(1, value)
}

func CMNormalizedLegacyMenuInlineItemsCount(_ value: Int) -> Int {
    max(0, value)
}

func CMNormalizedMenuLegacyFontSize(_ value: Int) -> Int {
    let options = CMMenuLegacyFontSizeOptions()
    guard let nearest = options.min(by: { abs($0 - value) < abs($1 - value) }) else {
        return 16
    }
    return nearest
}

func CMTypeLegacyMenuIconSizeOptions() -> [Int] {
    [16, 32, 48]
}

func CMNormalizedTypeLegacyMenuIconSize(_ value: Int) -> Int {
    let options = CMTypeLegacyMenuIconSizeOptions()
    guard let nearest = options.min(by: { abs($0 - value) < abs($1 - value) }) else {
        return 16
    }
    return nearest
}

func CMNormalizedLegacyThumbnailDimension(_ value: Int) -> Int {
    max(1, value)
}

func CMNormalizedTypeFileIconSelectionTag(_ value: Int) -> Int {
    value == 1 ? 1 : 0
}

func CMNormalizedMenuIconFileTypeValue(_ value: String?, defaultValue: String, selectionTag: Int = 0) -> String {
    let trimmedValue = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedValue.isEmpty else { return defaultValue }

    if CMNormalizedTypeFileIconSelectionTag(selectionTag) == 1 {
        let fourCharValue = String(trimmedValue.prefix(4))
        if fourCharValue.count < 4 {
            return fourCharValue.padding(toLength: 4, withPad: " ", startingAt: 0)
        }
        return fourCharValue
    }

    return trimmedValue
}

func CMNormalizedStatusItemSelectionTag(_ value: Int) -> Int {
    (0...12).contains(value) ? value : 1
}

func CMLegacyAutosaveDelayOptions() -> [Int] {
    [1800, 60, 300, 600, 3600, 10800, 21600, 43200, 86400, 0]
}

func CMNormalizedLegacyAutosaveDelay(_ value: Int) -> Int {
    let options = CMLegacyAutosaveDelayOptions()
    guard let nearest = options.min(by: { abs($0 - value) < abs($1 - value) }) else {
        return 1800
    }
    return nearest
}

func CMNormalizedLegacyObserveInterval(_ value: Double) -> Double {
    min(max(value, 0.0), 1.0)
}

func CMNormalizedLegacyMaxHistorySize(_ value: Int) -> Int {
    max(value, 1)
}

func CMNormalizedLegacyExportSeparatorTag(_ value: Int) -> Int {
    (0...5).contains(value) ? value : 1
}

func CMNormalizedLegacyExportHistoryAsSingleFileValue(_ value: Any?) -> Bool {
    if let boolValue = value as? Bool {
        return boolValue
    }
    if let intValue = value as? Int {
        switch intValue {
        case 1:
            return true
        case 0:
            return false
        default:
            return true
        }
    }
    if let numberValue = value as? NSNumber {
        switch numberValue.intValue {
        case 1:
            return true
        case 0:
            return false
        default:
            return true
        }
    }
    return true
}

func CMNormalizedLegacyReorderClipsAfterPastingValue(_ value: Any?) -> Bool {
    if let boolValue = value as? Bool {
        return boolValue
    }
    if let intValue = value as? Int {
        switch intValue {
        case 1:
            return true
        case 0:
            return false
        default:
            return true
        }
    }
    if let numberValue = value as? NSNumber {
        switch numberValue.intValue {
        case 1:
            return true
        case 0:
            return false
        default:
            return true
        }
    }
    return true
}

func CMNormalizedLegacySnippetPosition(_ value: Int) -> Int {
    CMPositionOfSnippets(rawValue: value)?.rawValue ?? CMPositionOfSnippets.belowClips.rawValue
}

func CMMenuPreviewTrimmedTitle(_ text: String, limit: Int) -> String {
    let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let nsString = stripped as NSString
    let firstLine: NSString
    if nsString.length > 0 {
        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0
        nsString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: 0, length: 0))
        firstLine = nsString.substring(to: lineEnd == nsString.length ? nsString.length : contentsEnd) as NSString
    } else {
        firstLine = ""
    }
    let normalizedLimit = max(3, CMNormalizedLegacyMenuTitleLength(limit))
    if firstLine.length > normalizedLimit {
        let end = max(0, normalizedLimit - 3)
        return firstLine.substring(to: end) + "..."
    }
    return firstLine as String
}

func CMMenuPreviewNumberedTitle(_ title: String, listNumber: Int, markWithNumbers: Bool) -> String {
    guard markWithNumbers else { return title }
    return "\(listNumber). \(title)"
}

func CMMenuPreviewKeyEquivalent(index: Int, markWithNumbers: Bool, startsFromZero: Bool) -> String {
    guard markWithNumbers, index >= 0, index < 10 else { return "" }
    let shortcut = startsFromZero ? index : index + 1
    return shortcut == 10 ? "0" : "\(shortcut)"
}

func CMMenuPreviewTooltip(text: String, maxLength: Int, showTooltips: Bool) -> String? {
    guard showTooltips else { return nil }
    let normalizedLength = CMNormalizedLegacyMenuTooltipLength(maxLength)
    let nsString = text as NSString
    return nsString.length > normalizedLength ? nsString.substring(to: normalizedLength) : text
}

func CMGeneralPasteBehaviorBadgeTitle(inputPasteCommand: Bool) -> String {
    inputPasteCommand
        ? NSLocalizedString("Auto-paste on", comment: "")
        : NSLocalizedString("Auto-paste off", comment: "")
}

func CMGeneralSortOrderBadgeTitle(sortByLastUsed: Bool) -> String {
    sortByLastUsed
        ? NSLocalizedString("Sort by Last Used", comment: "")
        : NSLocalizedString("Sort by Date Created", comment: "")
}

func CMGeneralQuitPersistenceBadgeTitle(saveHistoryOnQuit: Bool) -> String {
    saveHistoryOnQuit
        ? NSLocalizedString("Quit saves history", comment: "")
        : NSLocalizedString("Quit skips save", comment: "")
}

func CMTypeThumbnailDimensionBadgeTitles(width: Int, height: Int, pixelLabel: String) -> [String] {
    [
        String(format: NSLocalizedString("Width %d %@", comment: ""), width, pixelLabel),
        String(format: NSLocalizedString("Height %d %@", comment: ""), height, pixelLabel)
    ]
}

func CMTypeThumbnailSummaryTitle(width: Int, height: Int) -> String {
    String(
        format: NSLocalizedString("Image thumbnails: %d x %d px", comment: ""),
        width,
        height
    )
}

func CMTypeIconSizeBadgeTitle(size: Int, pixelLabel: String) -> String {
    String(format: NSLocalizedString("Size %d %@", comment: ""), size, pixelLabel)
}

func CMTypeFileIconMappingHighlightsForDebug(defaults: UserDefaults = .standard) -> [[String: Any]] {
    MenuIconMappingSection.allCases.compactMap { section in
        guard let option = section.options.first else { return nil }
        let preference = CMNormalizedMenuIconTypePreference(option: option, defaults: defaults)
        return [
            "sectionTitle": section.title,
            "title": option.title,
            "mode": preference.selectionTag == 1
                ? NSLocalizedString("File Type Code", comment: "")
                : NSLocalizedString("File Extension", comment: ""),
            "value": preference.fileType,
            "isDefault": preference.selectionTag == option.defaultSelectionTag && preference.fileType == option.defaultFileType
        ]
    }
}

func CMTypePreferencesSnapshotForDebug() -> [String: Any] {
    let defaults = UserDefaults.standard
    let storeTypes = StoreTypeOption.normalizedStoreTypes(from: defaults.dictionary(forKey: CMPrefStoreTypesKey))
    let enabledStoreTypeTitles = StoreTypeOption.all
        .filter { storeTypes[$0.id] ?? true }
        .map(\.title)
    let disabledStoreTypeTitles = StoreTypeOption.all
        .filter { !(storeTypes[$0.id] ?? true) }
        .map(\.title)

    let thumbnailWidth = CMNormalizedLegacyThumbnailDimension(
        defaults.object(forKey: CMPrefThumbnailWidthKey) as? Int ?? 100
    )
    let thumbnailHeight = CMNormalizedLegacyThumbnailDimension(
        defaults.object(forKey: CMPrefThumbnailHeightKey) as? Int ?? 32
    )
    let showIcons = defaults.object(forKey: CMPrefShowIconInTheMenuKey) as? Bool ?? true
    let menuIconSize = CMNormalizedTypeLegacyMenuIconSize(
        defaults.object(forKey: CMPrefMenuIconSizeKey) as? Int ?? 16
    )
    let pixelLabel = CMModernPixelUnitTitle()

    let customMappingCount = MenuIconTypeOption.all.reduce(into: 0) { count, option in
        let preference = CMNormalizedMenuIconTypePreference(option: option, defaults: defaults)
        let savedTag = preference.selectionTag
        let savedFileType = preference.fileType
        if savedTag != option.defaultSelectionTag || savedFileType != option.defaultFileType {
            count += 1
        }
    }

    let hfsMappingCount = MenuIconTypeOption.all.reduce(into: 0) { count, option in
        let savedTag = CMNormalizedMenuIconTypePreference(option: option, defaults: defaults).selectionTag
        if savedTag == 1 {
            count += 1
        }
    }

    let fileTypeMappings = MenuIconTypeOption.all.map { option -> [String: Any] in
        let preference = CMNormalizedMenuIconTypePreference(option: option, defaults: defaults)
        let selectionTag = preference.selectionTag
        let fileType = preference.fileType
        let trimmedValue = fileType.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayValue = trimmedValue.isEmpty ? option.defaultFileType : trimmedValue
        return [
            "title": option.title,
            "selectionTag": selectionTag,
            "mode": selectionTag == 1
                ? NSLocalizedString("File Type Code", comment: "")
                : NSLocalizedString("File Extension", comment: ""),
            "modeOptions": [
                NSLocalizedString("963.title", tableName: "Preferences", bundle: .main, value: "File extension", comment: ""),
                NSLocalizedString("962.title", tableName: "Preferences", bundle: .main, value: "File type code", comment: "")
            ],
            "value": fileType,
            "isDefault": selectionTag == option.defaultSelectionTag && fileType == option.defaultFileType,
            "resetHelp": NSLocalizedString("Reset", comment: ""),
            "summary": selectionTag == 1
                ? String(format: NSLocalizedString("Currently resolving %@ icons with HFS code '%@'.", comment: ""), option.id, displayValue)
                : String(format: NSLocalizedString("Currently resolving %@ icons with file extension '%@'.", comment: ""), option.id, displayValue)
        ]
    }

    let storeTypeRows = StoreTypeOption.all.map { option -> [String: Any] in
        let enabled = storeTypes[option.id] ?? true
        return [
            "title": option.title,
            "enabled": enabled
        ]
    }

    return [
        "paneTitle": NSLocalizedString("1086.label", tableName: "Preferences", bundle: .main, value: "Type", comment: ""),
        "storeTypes": [
            "sectionTitle": NSLocalizedString("1088.title", tableName: "Preferences", bundle: .main, value: "Select clipboard types to store:", comment: ""),
            "enabledCount": enabledStoreTypeTitles.count,
            "disabledCount": disabledStoreTypeTitles.count,
            "rows": storeTypeRows,
            "rowTitles": StoreTypeOption.all.map(\.title),
            "enabledTitles": enabledStoreTypeTitles,
            "disabledTitles": disabledStoreTypeTitles,
            "checkAllVisible": true,
            "checkAllTitle": NSLocalizedString("1066.title", tableName: "Preferences", bundle: .main, value: "Check All", comment: "")
        ],
        "images": [
            "sectionTitle": NSLocalizedString("Images", comment: ""),
            "toggleTitle": NSLocalizedString("737.title", tableName: "Preferences", bundle: .main, value: "Show Image", comment: ""),
            "controlTitles": [
                NSLocalizedString("737.title", tableName: "Preferences", bundle: .main, value: "Show Image", comment: ""),
                NSLocalizedString("707.title", tableName: "Preferences", bundle: .main, value: "Width:", comment: ""),
                NSLocalizedString("708.title", tableName: "Preferences", bundle: .main, value: "Height:", comment: "")
            ],
            "unitTitle": NSLocalizedString("711.title", tableName: "Preferences", bundle: .main, value: "pixel", comment: ""),
            "previewTitle": NSLocalizedString("Current Thumbnail Frame", comment: ""),
            "states": [
                "thumbnailWidth": thumbnailWidth,
                "thumbnailHeight": thumbnailHeight
            ],
            "summaryTitle": CMTypeThumbnailSummaryTitle(width: thumbnailWidth, height: thumbnailHeight),
            "dimensionBadges": CMTypeThumbnailDimensionBadgeTitles(width: thumbnailWidth, height: thumbnailHeight, pixelLabel: pixelLabel)
        ],
        "icons": [
            "sectionTitle": NSLocalizedString("Icons", comment: ""),
            "toggleTitle": NSLocalizedString("934.title", tableName: "Preferences", bundle: .main, value: "Show Icon in the Menu", comment: ""),
            "controlTitles": [
                NSLocalizedString("934.title", tableName: "Preferences", bundle: .main, value: "Show Icon in the Menu", comment: ""),
                NSLocalizedString("933.title", tableName: "Preferences", bundle: .main, value: "Icon size:", comment: "")
            ],
            "unitTitle": NSLocalizedString("711.title", tableName: "Preferences", bundle: .main, value: "pixel", comment: ""),
            "previewTitle": NSLocalizedString("Current Icon Size", comment: ""),
            "showIcons": showIcons,
            "sizeOptions": CMTypeLegacyMenuIconSizeOptions().map(String.init),
            "sizeBadge": CMTypeIconSizeBadgeTitle(size: menuIconSize, pixelLabel: pixelLabel)
        ],
        "fileTypeIcons": [
            "sectionTitle": NSLocalizedString("File Type Icons", comment: ""),
            "editorEnabled": showIcons,
            "customMappingCount": customMappingCount,
            "hfsMappingCount": hfsMappingCount,
            "rowTitles": MenuIconTypeOption.all.map(\.title),
            "groupedSections": MenuIconMappingSection.allCases.map { section in
                [
                    "title": section.title,
                    "rowTitles": section.options.map(\.title)
                ]
            },
            "mappings": fileTypeMappings
        ]
    ]
}

func CMSnippetPreferencesSnapshotForDebug() -> [String: Any] {
    let defaults = UserDefaults.standard
    let position = CMNormalizedLegacySnippetPosition(
        defaults.object(forKey: CMPrefPositionOfSnippetsKey) as? Int ?? CMPositionOfSnippets.belowClips.rawValue
    )

    let hiddenLabel = NSLocalizedString("907.title", tableName: "Preferences", bundle: .main, value: "None", comment: "")
    let aboveLabel = NSLocalizedString("908.title", tableName: "Preferences", bundle: .main, value: "Above the clipboard history", comment: "")
    let belowLabel = NSLocalizedString("909.title", tableName: "Preferences", bundle: .main, value: "Below the clipboard history", comment: "")

    let options = SnippetPositionCardOption.allCases.map { option -> [String: Any] in
        [
            "title": option.title(hidden: hiddenLabel, above: aboveLabel, below: belowLabel),
            "detail": option.detail,
            "selected": option.rawValue == position,
            "previewRows": option.previewRows.map(\.rawValue)
        ]
    }
    return [
        "paneTitle": NSLocalizedString("Snippets", comment: ""),
        "sectionTitle": NSLocalizedString("Snippets", comment: ""),
        "rowLabel": NSLocalizedString("903.title", tableName: "Preferences", bundle: .main, value: "The position to show snippets in ClipMenu:", comment: ""),
        "pickerTitles": [
            hiddenLabel,
            aboveLabel,
            belowLabel
        ],
        "selectedPosition": position,
        "options": options
    ]
}

func CMUpdatesPreferencesSnapshotForDebug() -> [String: Any] {
    let defaults = UserDefaults.standard
    let automaticChecks = defaults.object(forKey: CMEnableAutomaticCheckKey) as? Bool ?? true
    let preReleases = defaults.object(forKey: CMEnableAutomaticCheckPreReleaseKey) as? Bool ?? false
    let interval = defaults.object(forKey: CMUpdateCheckIntervalKey) as? Int ?? 86400
    let automaticallyInstallUpdates = defaults.object(forKey: CMAutomaticallyInstallUpdatesKey) as? Bool ?? false
    let coordinator = UpdateCoordinator.shared
    let intervalOptions = CMVisibleUpdateIntervalOptions()
    let visibleIntervalSelection = CMVisibleUpdateIntervalSelectionValue(for: interval)
    let showsImportedIntervalNotice = intervalOptions.contains(where: { $0.value == interval }) == false
    let feedStatusTitle: String = {
        guard coordinator.feedURL != nil else {
            return NSLocalizedString("Unavailable", comment: "")
        }
        return preReleases
            ? NSLocalizedString("Pre-release", comment: "")
            : NSLocalizedString("Stable", comment: "")
    }()

    let checkingStatusTitle: String = {
        if coordinator.isChecking {
            return NSLocalizedString("Checking now", comment: "")
        }
        return automaticChecks
            ? NSLocalizedString("Automatic checks on", comment: "")
            : NSLocalizedString("Manual only", comment: "")
    }()

    let lastCheckedDisplay = coordinator.lastCheckDate.map { date in
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    } ?? CMUpdatesNeverCheckedDisplayTitle()
    let availability = CMUpdatePreferencesAvailabilityReport(
        automaticChecks: automaticChecks,
        feedURLPresent: coordinator.feedURL != nil,
        isChecking: coordinator.isChecking
    )
    let workflowStages = CMUpdatesWorkflowStages(
        automaticChecks: automaticChecks,
        preReleases: preReleases,
        interval: interval,
        coordinator: coordinator
    )

    return [
        "paneTitle": NSLocalizedString("Updates", comment: ""),
        "statusActionTitle": NSLocalizedString("1331.title", tableName: "Preferences", bundle: .main, value: "Check Now", comment: ""),
        "sectionTitles": [
            NSLocalizedString("Updates", comment: ""),
            NSLocalizedString("Status", comment: "")
        ],
        "controlTitles": [
            NSLocalizedString("1337.title", tableName: "Preferences", bundle: .main, value: "Automatically check for updates:", comment: ""),
            NSLocalizedString("1426.title", tableName: "Preferences", bundle: .main, value: "Include pre-releases", comment: ""),
            NSLocalizedString("Automatically download and install updates in the future", comment: ""),
            NSLocalizedString("1279.title", tableName: "Preferences", bundle: .main, value: "Time interval", comment: ""),
            NSLocalizedString("1331.title", tableName: "Preferences", bundle: .main, value: "Check Now", comment: "")
        ],
        "intervalTitles": intervalOptions.map(\.title),
        "workflowStages": workflowStages.map(\.debugDictionary),
        "states": [
            "automaticChecks": automaticChecks,
            "preReleases": preReleases,
            "automaticallyInstallUpdates": automaticallyInstallUpdates,
            "interval": interval,
            "visibleIntervalSelection": visibleIntervalSelection,
            "showsImportedIntervalNotice": showsImportedIntervalNotice,
            "importedIntervalNoticeTitle": showsImportedIntervalNotice ? CMImportedUpdateIntervalNoticeTitle(for: interval) : "",
            "feedStatusTitle": feedStatusTitle,
            "checkingStatusTitle": checkingStatusTitle,
            "lastCheckedDisplay": lastCheckedDisplay,
            "isChecking": coordinator.isChecking,
            "hasFeedURL": coordinator.feedURL != nil,
            "availability": availability
        ]
    ]
}

func CMActionPreferencesSnapshotForDebug() -> [String: Any] {
    let defaults = UserDefaults.standard
    let store = ActionFileStore.shared
    let inspectorState = ActionInspectorState.shared

    let enableActions = defaults.object(forKey: CMPrefEnableActionKey) as? Bool ?? true
    let invokeImmediately = defaults.object(forKey: CMPrefInvokeActionImmediatelyKey) as? Bool ?? false
    let options = ActionBehaviorOption.options(from: store)

    func behaviorTitle(for defaultsKey: String) -> String {
        let optionID = ActionBehaviorOption.id(for: defaults.object(forKey: defaultsKey), options: options)
        return options.first(where: { $0.id == optionID })?.title ?? ActionBehaviorOption.none.title
    }

    func flattenedNodeCount(in nodes: [ActionNode]) -> Int {
        nodes.reduce(0) { partialResult, node in
            partialResult + 1 + flattenedNodeCount(in: node.children)
        }
    }

    func availableActionsSummary(for kind: ReservedActionKind) -> String {
        switch kind {
        case .builtin:
            return NSLocalizedString("Browse built-in actions before adding them to the runtime menu.", comment: "")
        case .bundled:
            return NSLocalizedString("Review bundled JavaScript actions shipped with ClipMenu.", comment: "")
        case .user:
            return NSLocalizedString("Inspect user-installed JavaScript actions that can be added to the runtime menu.", comment: "")
        }
    }

    func actionMenuSummary() -> String {
        NSLocalizedString("Arrange the runtime action menu with folders, drag and drop, and inspector-based renaming.", comment: "")
    }

    func actionInspectorTitle(for context: ActionInspectorSnapshot) -> String {
        context.pane == .action
            ? NSLocalizedString("Selected Action", comment: "")
            : NSLocalizedString("Available Action Details", comment: "")
    }

    func actionInspectorOriginBadge(for context: ActionInspectorSnapshot) -> String {
        context.pane == .action
            ? NSLocalizedString("1232.title", tableName: "Preferences", bundle: .main, value: "Action Menu", comment: "")
            : NSLocalizedString("Available Actions", comment: "")
    }

    func actionInspectorSummary(for context: ActionInspectorSnapshot) -> String {
        if context.pane == .action {
            return NSLocalizedString("Rename and inspect the live menu item currently selected in the editable action tree.", comment: "")
        }
        return NSLocalizedString("Preview the selected built-in or JavaScript action before adding it to the runtime menu.", comment: "")
    }

    let flattenedReservedCount = flattenedNodeCount(in: store.reservedNodes)
    let flattenedActionCount = flattenedNodeCount(in: store.actionNodes)
    let inspectorSnapshot = inspectorState.currentSnapshot(store: store)
    let actionMenuCountSummary = "\(flattenedActionCount) \(NSLocalizedString("1171.title", tableName: "Preferences", bundle: .main, value: "items", comment: ""))"

    var report: [String: Any] = [
        "paneTitle": NSLocalizedString("Action", comment: ""),
        "sectionTitles": [
            NSLocalizedString("1305.title", tableName: "Preferences", bundle: .main, value: "Behavior", comment: ""),
            NSLocalizedString("1223.title", tableName: "Preferences", bundle: .main, value: "Modifier key + Click behaviors on history menu items", comment: ""),
            NSLocalizedString("Available Actions", comment: ""),
            NSLocalizedString("1232.title", tableName: "Preferences", bundle: .main, value: "Action Menu", comment: "")
        ],
        "behavior": [
            "toggleTitles": [
                NSLocalizedString("756.title", tableName: "Preferences", bundle: .main, value: "Enable Action", comment: ""),
                NSLocalizedString("757.title", tableName: "Preferences", bundle: .main, value: "Invoke an action immediately if only one action was registered", comment: "")
            ],
            "states": [
                "enableActions": enableActions,
                "invokeImmediately": invokeImmediately
            ],
            "controlStates": [
                "invokeImmediatelyEnabled": enableActions,
                "modifierBehaviorControlsEnabled": enableActions
            ]
            ],
            "modifierRows": [
            [
                "title": NSLocalizedString("1190.title", tableName: "Preferences", bundle: .main, value: "Control + Click:", comment: ""),
                "selectionTitle": behaviorTitle(for: CMPrefContorlClickBehaviorKey)
            ],
            [
                "title": NSLocalizedString("1209.title", tableName: "Preferences", bundle: .main, value: "Shift + Click:", comment: ""),
                "selectionTitle": behaviorTitle(for: CMPrefShiftClickBehaviorKey)
            ],
            [
                "title": NSLocalizedString("1215.title", tableName: "Preferences", bundle: .main, value: "Option + Click:", comment: ""),
                "selectionTitle": behaviorTitle(for: CMPrefOptionClickBehaviorKey)
            ],
            [
                "title": NSLocalizedString("1221.title", tableName: "Preferences", bundle: .main, value: "Command + Click:", comment: ""),
                "selectionTitle": behaviorTitle(for: CMPrefCommandClickBehaviorKey)
            ]
        ],
        "availableActions": [
            "sourceTitle": store.reservedKind.title,
            "sourceTitles": ReservedActionKind.allCases.map(\.title),
            "countSummary": "\(flattenedReservedCount) \(NSLocalizedString("1171.title", tableName: "Preferences", bundle: .main, value: "items", comment: ""))",
            "summary": availableActionsSummary(for: store.reservedKind),
            "selectedName": store.currentReservedInspectorNode()?.nodeTitle as Any,
            "isEnabled": true,
            "emptyStates": [
                "builtin": [
                    "title": CMActionReservedEmptyStateTitle(for: .builtin),
                    "message": CMActionReservedEmptyStateMessage(for: .builtin)
                ],
                "bundled": [
                    "title": CMActionReservedEmptyStateTitle(for: .bundled),
                    "message": CMActionReservedEmptyStateMessage(for: .bundled)
                ],
                "user": [
                    "title": CMActionReservedEmptyStateTitle(for: .user),
                    "message": CMActionReservedEmptyStateMessage(for: .user)
                ]
            ]
        ],
        "actionMenu": [
            "countSummary": actionMenuCountSummary,
            "summary": actionMenuSummary(),
            "selectedPath": store.currentSelectedActionNodePath() as Any,
            "isEnabled": true,
            "emptyState": [
                "title": CMActionMenuEmptyStateTitle(),
                "message": CMActionMenuEmptyStateMessage()
            ],
            "toolbarButtonIconSources": [
                "add": "legacyTemplate",
                "addFolder": "systemSymbol",
                "remove": "legacyTemplate",
                "moveUp": "systemSymbol",
                "moveDown": "systemSymbol"
            ],
            "toolbarButtonsEnabled": [
                "add": store.selectedReservedNodeID != nil,
                "addFolder": true,
                "remove": store.selectedActionNodeID != nil,
                "moveUp": store.canMoveSelectedActionNodeUp(),
                "moveDown": store.canMoveSelectedActionNodeDown()
            ]
        ]
    ]

    if let inspectorSnapshot {
        var inspectorReport: [String: Any] = [
            "title": actionInspectorTitle(for: inspectorSnapshot),
            "originBadge": actionInspectorOriginBadge(for: inspectorSnapshot),
            "summary": actionInspectorSummary(for: inspectorSnapshot),
            "pane": inspectorSnapshot.pane.rawValue,
            "name": inspectorSnapshot.node.nodeTitle,
            "type": CMActionInspectorTypeTitle(for: inspectorSnapshot.node),
            "isEditable": inspectorSnapshot.pane == .action
        ]
        inspectorReport["path"] = CMActionInspectorPath(for: inspectorSnapshot.node) as Any
        report["inspector"] = inspectorReport
    } else {
        report["inspector"] = NSNull()
    }

    return report
}

func CMGeneralPreferencesSnapshotForDebug() -> [String: Any] {
    let defaults = UserDefaults.standard

    let inputPasteCommand = defaults.object(forKey: CMPrefInputPasteCommandKey) as? Bool ?? true
    let reorderClipsAfterPasting = CMNormalizedLegacyReorderClipsAfterPastingValue(
        defaults.object(forKey: CMPrefReorderClipsAfterPasting)
    )
    let saveHistoryOnQuit = defaults.object(forKey: CMPrefSaveHistoryOnQuitKey) as? Bool ?? true
    let exportHistoryAsSingleFile = CMNormalizedLegacyExportHistoryAsSingleFileValue(
        defaults.object(forKey: CMPrefExportHistoryAsSingleFileKey)
    )
    let exportSeparator = CMNormalizedLegacyExportSeparatorTag(
        defaults.object(forKey: CMPrefTagOfSeparatorForExportHistoryToFileKey) as? Int ?? 1
    )
    let showStatusItem = CMNormalizedStatusItemSelectionTag(
        defaults.object(forKey: CMPrefShowStatusItemKey) as? Int ?? 1
    )
    let maxHistorySize = CMNormalizedLegacyMaxHistorySize(
        defaults.object(forKey: CMPrefMaxHistorySizeKey) as? Int ?? 20
    )
    let autosaveDelay = CMNormalizedLegacyAutosaveDelay(
        defaults.object(forKey: CMPrefAutosaveDelayKey) as? Int ?? 1800
    )
    let timeInterval = CMNormalizedLegacyObserveInterval(
        defaults.object(forKey: CMPrefTimeIntervalKey) as? Double ?? 0.75
    )

    let excludedApps = (defaults.array(forKey: CMPrefExcludeAppsKey) ?? [])
        .compactMap(ExcludedApp.init(defaultsObject:))
        .map(\.name)

    let excludedAppsSurfaceSummaryText: String = {
        let count = excludedApps.count
        if count == 0 {
            return NSLocalizedString("No applications are currently excluded from clipboard capture.", comment: "")
        }
        if count == 1 {
            return excludedApps[0]
        }
        let names = Array(excludedApps.prefix(2))
        if count == 2 {
            return names.joined(separator: ", ")
        }
        return String(
            format: NSLocalizedString("%1$@, %2$@, and %3$d more", comment: ""),
            names.first ?? "",
            names.dropFirst().first ?? "",
            count - 2
        )
    }()

    let excludedAppsSurfaceBadges: [String] = [
        excludedApps.count == 1
            ? NSLocalizedString("1 app", comment: "")
            : String(format: NSLocalizedString("%d apps", comment: ""), excludedApps.count),
        excludedApps.isEmpty
            ? NSLocalizedString("Capture open to all apps", comment: "")
            : NSLocalizedString("Capture filtered by app", comment: "")
    ]

    let excludedAppsSurfacePreviewTitles: [String] = {
        let preview = Array(excludedApps.prefix(3))
        guard excludedApps.count > 3 else { return preview }
        return preview + [
            String(format: NSLocalizedString("%d more", comment: ""), excludedApps.count - 3)
        ]
    }()
    let selectedStatusItemOption = StatusItemOption(rawValue: CMNormalizedStatusItemSelectionTag(showStatusItem)) ?? .default

    return [
        "paneTitle": NSLocalizedString("General", comment: ""),
        "sectionTitles": [
            NSLocalizedString("Startup", comment: ""),
            NSLocalizedString("1275.title", tableName: "Preferences", bundle: .main, value: "Clipboard History", comment: ""),
            NSLocalizedString("1277.title", tableName: "Preferences", bundle: .main, value: "Appearance", comment: "")
        ],
        "startup": [
            "toggleTitles": [
                NSLocalizedString("768.title", tableName: "Preferences", bundle: .main, value: "Launch on Login", comment: ""),
                NSLocalizedString("Do not ask about startup launch", comment: "")
            ]
        ],
        "clipboardHistory": [
            "excludedAppsSurface": [
                "title": NSLocalizedString("1451.title", tableName: "Preferences", bundle: .main, value: "Exclude Apps", comment: ""),
                "summaryText": excludedAppsSurfaceSummaryText,
                "badges": excludedAppsSurfaceBadges,
                "previewTitles": excludedAppsSurfacePreviewTitles,
                "actionTitle": NSLocalizedString("1448.title", tableName: "Preferences", bundle: .main, value: "Define Exclude Options...", comment: "")
            ],
            "controlTitles": [
                NSLocalizedString("690.title", tableName: "Preferences", bundle: .main, value: "Input \"⌘ + V\" after menu item selection", comment: ""),
                NSLocalizedString("1417.title", tableName: "Preferences", bundle: .main, value: "Sort history order by:", comment: ""),
                NSLocalizedString("1446.title", tableName: "Preferences", bundle: .main, value: "Exclude Applications", comment: ""),
                NSLocalizedString("1047.title", tableName: "Preferences", bundle: .main, value: "Save clipboard history on quit", comment: ""),
                NSLocalizedString("1380.title", tableName: "Preferences", bundle: .main, value: "Export clipboard history as:", comment: ""),
                NSLocalizedString("1396.title", tableName: "Preferences", bundle: .main, value: "separator:", comment: ""),
                NSLocalizedString("1390.title", tableName: "Preferences", bundle: .main, value: "Export...", comment: ""),
                NSLocalizedString("1164.title", tableName: "Preferences", bundle: .main, value: "Max clipboard history size:", comment: ""),
                NSLocalizedString("1281.title", tableName: "Preferences", bundle: .main, value: "Autosaving clipboard history:", comment: ""),
                NSLocalizedString("686.title", tableName: "Preferences", bundle: .main, value: "Time interval to observe the clipboard:", comment: "")
            ],
            "sortOrderTitles": [
                NSLocalizedString("1422.title", tableName: "Preferences", bundle: .main, value: "Last Used", comment: ""),
                NSLocalizedString("1421.title", tableName: "Preferences", bundle: .main, value: "Date Created", comment: "")
            ],
            "exportModeTitles": [
                NSLocalizedString("1384.title", tableName: "Preferences", bundle: .main, value: "Single file", comment: ""),
                NSLocalizedString("1385.title", tableName: "Preferences", bundle: .main, value: "Multiple files", comment: "")
            ],
            "separatorTitles": [
                NSLocalizedString("LF", comment: ""),
                NSLocalizedString("CR+LF", comment: ""),
                NSLocalizedString("CR", comment: ""),
                NSLocalizedString("Tab", comment: ""),
                NSLocalizedString("Space", comment: ""),
                NSLocalizedString("None", comment: "")
            ],
            "autosaveIntervalTitles": [
                NSLocalizedString("1289.title", tableName: "Preferences", bundle: .main, value: "Every 30 minutes", comment: ""),
                NSLocalizedString("1286.title", tableName: "Preferences", bundle: .main, value: "Every minute", comment: ""),
                NSLocalizedString("1287.title", tableName: "Preferences", bundle: .main, value: "Every 5 minutes", comment: ""),
                NSLocalizedString("1290.title", tableName: "Preferences", bundle: .main, value: "Every 10 minutes", comment: ""),
                NSLocalizedString("1291.title", tableName: "Preferences", bundle: .main, value: "Every hour", comment: ""),
                NSLocalizedString("1292.title", tableName: "Preferences", bundle: .main, value: "Every 3 hours", comment: ""),
                NSLocalizedString("1293.title", tableName: "Preferences", bundle: .main, value: "Every 6 hours", comment: ""),
                NSLocalizedString("1294.title", tableName: "Preferences", bundle: .main, value: "Every 12 hours", comment: ""),
                NSLocalizedString("1295.title", tableName: "Preferences", bundle: .main, value: "Every day", comment: ""),
                NSLocalizedString("1285.title", tableName: "Preferences", bundle: .main, value: "Never", comment: "")
            ],
            "states": [
                "inputPasteCommand": inputPasteCommand,
                "sortByLastUsed": reorderClipsAfterPasting,
                "saveHistoryOnQuit": saveHistoryOnQuit,
                "exportHistoryAsSingleFile": exportHistoryAsSingleFile,
                "exportSeparator": exportSeparator,
                "maxHistorySize": maxHistorySize,
                "autosaveDelay": autosaveDelay,
                "timeInterval": timeInterval,
                "excludedApps": excludedApps
            ]
        ],
        "appearance": [
            "controlTitle": NSLocalizedString("1316.title", tableName: "Preferences", bundle: .main, value: "Status Bar icon style:", comment: ""),
            "selectedStatusItemTitle": selectedStatusItemOption.title,
            "selectedStatusItemPreviewSource": selectedStatusItemOption == .none ? "systemSymbol" : "legacyArtwork",
            "gallerySections": StatusItemGallerySection.allCases.map { section in
                [
                    "title": section.title,
                    "optionTitles": section.options.map(\.title),
                    "selectedTitle": section.options.first(where: { $0 == selectedStatusItemOption })?.title as Any
                ]
            }
        ]
    ]
}

private let CMPrefStoreTypesKey = "storeTypes"
private let CMPrefExcludeAppsKey = "excludeApps"
private let kCMBundleIdentifierKey = "bundleIdentifier"
private let kCMNameKey = "name"

private struct StoreTypeOption: Identifiable {
    let id: String
    let title: String

    static let all: [StoreTypeOption] = [
        StoreTypeOption(id: "String", title: NSLocalizedString("1097.title", tableName: "Preferences", bundle: .main, value: "Plain Text", comment: "")),
        StoreTypeOption(id: "RTF", title: NSLocalizedString("1098.title", tableName: "Preferences", bundle: .main, value: "Rich Text Format (RTF)", comment: "")),
        StoreTypeOption(id: "PDF", title: NSLocalizedString("1099.title", tableName: "Preferences", bundle: .main, value: "PDF", comment: "")),
        StoreTypeOption(id: "Filenames", title: NSLocalizedString("1100.title", tableName: "Preferences", bundle: .main, value: "Filenames", comment: "")),
        StoreTypeOption(id: "URL", title: NSLocalizedString("1101.title", tableName: "Preferences", bundle: .main, value: "URL", comment: "")),
        StoreTypeOption(id: "TIFF", title: NSLocalizedString("1102.title", tableName: "Preferences", bundle: .main, value: "TIFF Image", comment: "")),
        StoreTypeOption(id: "PICT", title: NSLocalizedString("1103.title", tableName: "Preferences", bundle: .main, value: "PICT Image", comment: "")),
        StoreTypeOption(id: "RTFD", title: NSLocalizedString("1104.title", tableName: "Preferences", bundle: .main, value: "Rich Text Format Directory (RTFD)", comment: ""))
    ]

    static var defaults: [String: Bool] {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, true) })
    }

    static func normalizedStoreTypes(from rawStoreTypes: [String: Any]?) -> [String: Bool] {
        var storeTypes = defaults
        guard let rawStoreTypes else { return storeTypes }

        for (key, value) in rawStoreTypes {
            guard let id = id(forStoreTypeKey: key),
                  let enabled = boolValue(value) else {
                continue
            }
            storeTypes[id] = enabled
        }

        return storeTypes
    }

    private static func boolValue(_ value: Any) -> Bool? {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return nil
    }

    private static func id(forStoreTypeKey key: String) -> String? {
        if all.contains(where: { $0.id == key }) {
            return key
        }

        switch key {
        case NSPasteboard.PasteboardType.string.rawValue, "NSStringPboardType":
            return "String"
        case NSPasteboard.PasteboardType.rtf.rawValue, "NSRTFPboardType":
            return "RTF"
        case NSPasteboard.PasteboardType.rtfd.rawValue, "NSRTFDPboardType":
            return "RTFD"
        case NSPasteboard.PasteboardType.pdf.rawValue, "NSPDFPboardType":
            return "PDF"
        case NSPasteboard.PasteboardType("NSFilenamesPboardType").rawValue, "public.file-url":
            return "Filenames"
        case NSPasteboard.PasteboardType("NSURLPboardType").rawValue, "public.url":
            return "URL"
        case NSPasteboard.PasteboardType.tiff.rawValue, "NSTIFFPboardType":
            return "TIFF"
        case NSPasteboard.PasteboardType("Apple PICT pasteboard type").rawValue, "NSPICTPboardType":
            return "PICT"
        default:
            return nil
        }
    }
}

private struct ExcludedApp: Identifiable, Equatable {
    let bundleIdentifier: String
    var name: String

    var id: String { bundleIdentifier }

    var dictionary: [String: String] {
        [
            kCMBundleIdentifierKey: bundleIdentifier,
            kCMNameKey: name
        ]
    }

    init(bundleIdentifier: String, name: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
    }

    init?(defaultsObject: Any) {
        let dictionary: [String: Any]
        if let swiftDictionary = defaultsObject as? [String: Any] {
            dictionary = swiftDictionary
        } else if let nsDictionary = defaultsObject as? NSDictionary {
            var bridged: [String: Any] = [:]
            for (key, value) in nsDictionary {
                guard let key = key as? String else { continue }
                bridged[key] = value
            }
            dictionary = bridged
        } else {
            return nil
        }

        guard let bundleIdentifier = dictionary[kCMBundleIdentifierKey] as? String,
              !bundleIdentifier.isEmpty else {
            return nil
        }

        self.bundleIdentifier = bundleIdentifier
        self.name = (dictionary[kCMNameKey] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? bundleIdentifier
    }
}

private struct AvailableRunningApp: Identifiable {
    let bundleIdentifier: String
    let name: String
    let icon: NSImage

    var id: String { bundleIdentifier }
}

private func CMAvailableRunningAppsForExclusion(
    excluding excludedApps: [ExcludedApp]
) -> [AvailableRunningApp] {
    NSWorkspace.shared.runningApplications
        .filter { app in
            app.bundleIdentifier != nil
                && !excludedApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier })
        }
        .compactMap { app in
            guard let bundleIdentifier = app.bundleIdentifier,
                  let name = app.localizedName,
                  let appURL = app.bundleURL else {
                return nil
            }

            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            return AvailableRunningApp(bundleIdentifier: bundleIdentifier, name: name, icon: icon)
        }
}

private final class RecordingPreferencesStore: ObservableObject {
    static let shared = RecordingPreferencesStore()

    @Published var storeTypes: [String: Bool] = [:]
    @Published var excludedApps: [ExcludedApp] = []
    @Published private(set) var hasPendingExcludedAppChanges = false

    private var persistedStoreTypes: [String: Bool] = [:]
    private var persistedExcludedApps: [ExcludedApp] = []

    init() {
        reload()
    }

    func reload() {
        let defaults = UserDefaults.standard
        storeTypes = StoreTypeOption.normalizedStoreTypes(from: defaults.dictionary(forKey: CMPrefStoreTypesKey))
        persistedStoreTypes = storeTypes

        let loadedExcludedApps = (defaults.array(forKey: CMPrefExcludeAppsKey) ?? [])
            .compactMap(ExcludedApp.init(defaultsObject:))
        excludedApps = loadedExcludedApps
        persistedExcludedApps = loadedExcludedApps
        hasPendingExcludedAppChanges = false
    }

    func binding(for option: StoreTypeOption) -> Binding<Bool> {
        Binding(
            get: { self.storeTypes[option.id] ?? true },
            set: { newValue in
                self.storeTypes[option.id] = newValue
            }
        )
    }

    var allStoreTypesEnabled: Bool {
        StoreTypeOption.all.allSatisfy { storeTypes[$0.id] ?? true }
    }

    func enableAllStoreTypes() {
        for option in StoreTypeOption.all {
            storeTypes[option.id] = true
        }
    }

    func addRunningApp(_ app: AvailableRunningApp) {
        addExcludedApp(ExcludedApp(bundleIdentifier: app.bundleIdentifier, name: app.name))
    }

    func addAppsFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.resolvesAliases = true
        panel.prompt = NSLocalizedString("Add", comment: "")
        panel.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first

        let completion: (NSApplication.ModalResponse) -> Void = { [weak self, weak panel] response in
            guard response == .OK, let panel else { return }
            self?.addApps(from: panel.urls)
        }

        if let window = NSApp.keyWindow ?? NSApp.mainWindow,
           window.isVisible {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else if let preferencesWindow = SwiftUIPreferencesWindowController.shared.window,
                  preferencesWindow.isVisible {
            panel.beginSheetModal(for: preferencesWindow, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    private func addApps(from urls: [URL]) {
        for url in urls {
            guard let bundle = Bundle(url: url),
                  let identifier = bundle.bundleIdentifier else {
                continue
            }
            guard let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String else {
                continue
            }
            addExcludedApp(ExcludedApp(bundleIdentifier: identifier, name: name))
        }
    }

    func remove(_ app: ExcludedApp) {
        excludedApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
        updatePendingExcludedAppChanges()
    }

    private func addExcludedApp(_ app: ExcludedApp) {
        guard !excludedApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) else { return }
        excludedApps.append(app)
        updatePendingExcludedAppChanges()
    }

    func applyStoreTypes() {
        UserDefaults.standard.set(storeTypes, forKey: CMPrefStoreTypesKey)
        persistedStoreTypes = storeTypes
    }

    func revertStoreTypes() {
        storeTypes = persistedStoreTypes
    }

    func applyExcludedApps() {
        UserDefaults.standard.set(excludedApps.map(\.dictionary), forKey: CMPrefExcludeAppsKey)
        persistedExcludedApps = excludedApps
        hasPendingExcludedAppChanges = false
    }

    func revertExcludedApps() {
        excludedApps = persistedExcludedApps
        hasPendingExcludedAppChanges = false
    }

    private func updatePendingExcludedAppChanges() {
        hasPendingExcludedAppChanges = excludedApps != persistedExcludedApps
    }
}

#if DEBUG
func CMExcludedApplicationsEditorSnapshotForDebug() -> [String: Any] {
    let store = RecordingPreferencesStore.shared
    let runningApps = CMAvailableRunningAppsForExclusion(excluding: store.excludedApps)
    let listHeader = NSLocalizedString(
        "612.headerCell.title",
        tableName: "Preferences",
        bundle: .main,
        value: "Name",
        comment: ""
    )

    let overviewDetail: String = {
        if store.excludedApps.isEmpty {
            return NSLocalizedString(
                "Keep clipboard capture open to every app, or add exceptions for tools ClipMenu should ignore.",
                comment: ""
            )
        }
        return NSLocalizedString(
            "Review which apps are blocked from clipboard capture and keep their draft changes isolated until you choose Done.",
            comment: ""
        )
    }()

    let summaryLine: String = {
        let count = store.excludedApps.count
        if count == 0 {
            return NSLocalizedString("No applications excluded", comment: "")
        }
        if count == 1 {
            return NSLocalizedString("1 application excluded", comment: "")
        }
        return String(format: NSLocalizedString("%d applications excluded", comment: ""), count)
    }()

    let runningAppsBadgeText: String = {
        if runningApps.isEmpty {
            return NSLocalizedString("No running app suggestions", comment: "")
        }
        if runningApps.count == 1 {
            return NSLocalizedString("1 running app ready", comment: "")
        }
        return String(format: NSLocalizedString("%d running apps ready", comment: ""), runningApps.count)
    }()

    let selectionScopeBadgeText = store.excludedApps.isEmpty
        ? NSLocalizedString("Capture open to all apps", comment: "")
        : NSLocalizedString("Capture filtered by app", comment: "")

    var snapshot: [String: Any] = [
        "title": NSLocalizedString("1451.title", tableName: "Preferences", bundle: .main, value: "Exclude Apps", comment: ""),
        "overviewDetail": overviewDetail,
        "overviewBadges": [
            summaryLine,
            runningAppsBadgeText,
            selectionScopeBadgeText
        ],
        "listTitle": NSLocalizedString("1459.title", tableName: "Preferences", bundle: .main, value: "Exclude these applications:", comment: ""),
        "listHeaderTitle": listHeader,
        "sidebarTitle": NSLocalizedString("Add Applications", comment: ""),
        "sidebarDetail": NSLocalizedString("Add running apps quickly, or choose any app bundle manually.", comment: ""),
        "sidebarBadges": [
            runningAppsBadgeText,
            NSLocalizedString("Other… from /Applications", comment: "")
        ],
        "addActionTitle": NSLocalizedString("Add", comment: ""),
        "addActionDetail": NSLocalizedString("Choose a running app or browse for another bundle.", comment: ""),
        "footerButtons": [
            NSLocalizedString("1456.title", tableName: "Preferences", bundle: .main, value: "Cancel", comment: ""),
            NSLocalizedString("1454.title", tableName: "Preferences", bundle: .main, value: "Done", comment: "")
        ],
        "state": [
            "excludedCount": store.excludedApps.count,
            "excludedNames": store.excludedApps.map(\.name),
            "runningAppSuggestionCount": runningApps.count,
            "runningAppSuggestionNames": runningApps.prefix(4).map(\.name),
            "hasPendingChanges": store.hasPendingExcludedAppChanges
        ]
    ]

    if store.excludedApps.isEmpty {
        snapshot["emptyState"] = [
            "title": NSLocalizedString("No Excluded Applications", comment: ""),
            "detail": NSLocalizedString(
                "Add running apps or choose app bundles to stop ClipMenu from recording them.",
                comment: ""
            )
        ]
    }

    return snapshot
}
#endif

func CMReloadRecordingPreferences() {
    RecordingPreferencesStore.shared.reload()
}

func CMModernLocalizationIsJapanese() -> Bool {
    if let languages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
       let firstLanguage = languages.first,
       firstLanguage.hasPrefix("ja") {
        return true
    }
    if let firstPreferredLanguage = Locale.preferredLanguages.first,
       firstPreferredLanguage.hasPrefix("ja") {
        return true
    }
    return Bundle.main.preferredLocalizations.first?.hasPrefix("ja") == true
}

func CMLocalizedModernString(_ english: String, japanese: String) -> String {
    if CMModernLocalizationIsJapanese() {
        return japanese
    }
    return NSLocalizedString(english, comment: "")
}

private func CMMenuInlineChipTitle(_ count: Int) -> String {
    CMLocalizedModernString("\(count) inline", japanese: "\(count)個をインライン")
}

private func CMMenuPerFolderChipTitle(_ count: Int) -> String {
    CMLocalizedModernString("\(count) per folder", japanese: "\(count)個/フォルダ")
}

private func CMMenuNumericShortcutsBadge(enabled: Bool) -> String {
    CMLocalizedModernString(
        enabled ? "Numeric shortcuts on" : "Numeric shortcuts off",
        japanese: enabled ? "数字ショートカットオン" : "数字ショートカットオフ"
    )
}

private func CMMenuLabelsBadge(shown: Bool) -> String {
    CMLocalizedModernString(
        shown ? "Labels shown" : "Labels hidden",
        japanese: shown ? "ラベル表示" : "ラベル非表示"
    )
}

private func CMMenuClearHistoryBadge(shown: Bool) -> String {
    CMLocalizedModernString(
        shown ? "Clear History shown" : "Clear History hidden",
        japanese: shown ? "履歴消去表示" : "履歴消去非表示"
    )
}

private func CMMenuClearConfirmationBadge(enabled: Bool) -> String {
    CMLocalizedModernString(
        enabled ? "Confirm before clear" : "Clear without confirm",
        japanese: enabled ? "確認して消去" : "確認なしで消去"
    )
}

private func CMMenuTooltipsBadge(enabled: Bool) -> String {
    CMLocalizedModernString(
        enabled ? "Tooltips On" : "Tooltips Off",
        japanese: enabled ? "ツールチップオン" : "ツールチップオフ"
    )
}

private func CMMenuFontSizingBadge(enabled: Bool) -> String {
    CMLocalizedModernString(
        enabled ? "Font sizing on" : "Font sizing off",
        japanese: enabled ? "フォントサイズ変更オン" : "フォントサイズ変更オフ"
    )
}

private func CMMenuFontSizingPromptDetail() -> String {
    CMLocalizedModernString(
        "Turn font sizing on to customize the menu text size.",
        japanese: "メニューテキストのサイズを調整するには、フォントサイズ変更を有効にします。"
    )
}

private func CMTrimTrailingShortcutPunctuation(_ title: String) -> String {
    var result = title
    while let last = result.last, last == ":" || last == "：" {
        result.removeLast()
    }
    return result
}

private func CMVisibleShortcutBadgeTitle(label: String, keyCode: Int, modifierFlags: Int) -> String {
    let trimmedLabel = CMTrimTrailingShortcutPunctuation(label)
    let separator = CMModernLocalizationIsJapanese() ? " " : ": "
    return "\(trimmedLabel)\(separator)\(HotKeyRecorderDisplayString(keyCode: keyCode, modifierFlags: modifierFlags))"
}

func CMShortcutReservedHistoryBadgeTitle(historyDisplay: String) -> String {
    let label = CMTrimTrailingShortcutPunctuation(NSLocalizedString("History menu:", comment: ""))
    let separator = CMModernLocalizationIsJapanese() ? " " : ": "
    return "\(label)\(separator)\(historyDisplay)"
}

private func CMPreferencesSearchPlaceholder() -> String {
    NSLocalizedString("Search", comment: "")
}

private func CMSnippetEditorSearchPlaceholder() -> String {
    NSLocalizedString("876.placeholderString", tableName: "Preferences", bundle: .main, value: "All", comment: "")
}

private let CMSnippetEditorFolderGroupIdentifier = "GROUPS"

private func CMSnippetEditorFolderGroupHeader() -> String {
    NSLocalizedString("Groups", comment: "")
}

private func CMSnippetEditorOverviewTitle() -> String {
    NSLocalizedString("Snippet Library", comment: "")
}

private func CMPreferencesOriginalIconsBadgeTitle() -> String {
    NSLocalizedString("Original icons", comment: "")
}

private func CMPreferencesSidebarLeadSummary() -> String {
    NSLocalizedString("Legacy behavior, refreshed pane by pane.", comment: "")
}

private func CMPreferencesEmptySelectionTitle() -> String {
    NSLocalizedString("Select a Settings Area", comment: "")
}

private func CMPreferencesEmptySelectionDetail() -> String {
    NSLocalizedString("Choose a category from the sidebar.", comment: "")
}

private func CMActionBuiltInSourceLabel() -> String {
    NSLocalizedString("755.labels[0]", tableName: "Preferences", bundle: .main, value: "Built-in", comment: "")
}

private func CMActionBundledSourceLabel() -> String {
    NSLocalizedString("755.labels[1]", tableName: "Preferences", bundle: .main, value: "JavaScript", comment: "")
}

private func CMActionUserSourceLabel() -> String {
    NSLocalizedString("755.labels[2]", tableName: "Preferences", bundle: .main, value: "User's", comment: "")
}

private func CMActionReservedEmptyStateTitle(for kind: ReservedActionKind) -> String {
    switch kind {
    case .builtin:
        return NSLocalizedString("No Built-in Actions", comment: "")
    case .bundled:
        return NSLocalizedString("No JavaScript Actions", comment: "")
    case .user:
        return NSLocalizedString("No User JavaScript Actions", comment: "")
    }
}

private func CMActionReservedEmptyStateMessage(for kind: ReservedActionKind) -> String {
    switch kind {
    case .builtin:
        return NSLocalizedString("No built-in actions are available right now.", comment: "")
    case .bundled:
        return NSLocalizedString("No bundled JavaScript actions were found.", comment: "")
    case .user:
        return NSLocalizedString("Add JavaScript actions under Application Support to make them available here.", comment: "")
    }
}

private func CMActionMenuEmptyStateTitle() -> String {
    NSLocalizedString("Action Menu is Empty", comment: "")
}

private func CMActionMenuEmptyStateMessage() -> String {
    NSLocalizedString("Add an action or folder to build the runtime action menu.", comment: "")
}

private func CMUpdatesNeverCheckedDisplayTitle() -> String {
    NSLocalizedString("Never checked", comment: "")
}

private func CMModernPixelUnitTitle() -> String {
    NSLocalizedString("pixel", comment: "")
}

private func CMUnsavedChangesBadgeTitle() -> String {
    NSLocalizedString("Unsaved Changes", comment: "")
}

private func CMStartupLaunchSummaryText(loginItemEnabled: Bool, supportsLoginItem: Bool) -> String {
    if !supportsLoginItem {
        return CMLocalizedModernString(
            "Startup launch control is unavailable on this system configuration.",
            japanese: "このシステム構成では起動時設定を変更できません。"
        )
    }
    if loginItemEnabled {
        return CMLocalizedModernString(
            "ClipMenu will be requested at login after you close Preferences.",
            japanese: "ClipMenu はログイン時に起動するよう設定され、環境設定を閉じたときに適用されます。"
        )
    }
    return CMLocalizedModernString(
        "ClipMenu stays manual at sign-in unless you enable launch at login.",
        japanese: "ログイン時に起動を有効にしない限り、ClipMenu は手動起動のままです。"
    )
}

func CMStageRecordingStoreType(_ id: String, enabled: Bool) {
    RecordingPreferencesStore.shared.storeTypes[id] = enabled
}

func CMApplyRecordingStoreTypes() {
    RecordingPreferencesStore.shared.applyStoreTypes()
}

func CMRevertRecordingStoreTypes() {
    RecordingPreferencesStore.shared.revertStoreTypes()
}

func CMStageExcludedAppForTesting(bundleIdentifier: String, name: String) {
    RecordingPreferencesStore.shared.excludedApps.append(
        ExcludedApp(bundleIdentifier: bundleIdentifier, name: name)
    )
}

func CMCurrentExcludedAppsDictionaries() -> [[String: String]] {
    RecordingPreferencesStore.shared.excludedApps.map(\.dictionary)
}

func CMApplyExcludedApps() {
    RecordingPreferencesStore.shared.applyExcludedApps()
}

func CMRevertExcludedApps() {
    RecordingPreferencesStore.shared.revertExcludedApps()
}

func CMReloadActionPreferences() {
    ActionFileStore.shared.reload()
}

func CMAddActionFolderForTesting() {
    ActionFileStore.shared.addFolder()
}

func CMAddReservedActionForTesting() {
    ActionFileStore.shared.addTestBuiltinAction()
}

func CMAddSelectedReservedActionForTesting() {
    ActionFileStore.shared.addSelectedReservedNode()
}

func CMRemoveSelectedActionNodeForTesting() {
    ActionFileStore.shared.removeSelectedActionNode()
}

@discardableResult
func CMSelectActionPreferenceNodeForTesting(path: String) -> Bool {
    let didSelect = ActionFileStore.shared.selectActionNode(path: path)
    if didSelect {
        ActionInspectorState.shared.activePane = .action
    }
    return didSelect
}

func CMCommitActionPreferences() {
    ActionFileStore.shared.commitPendingChanges()
}

func CMCommittedActionNodesData() -> Data? {
    ActionFileStore.shared.committedNodesData()
}

func CMCurrentActionPreferenceTitles() -> [String] {
    ActionFileStore.shared.actionNodes.map(\.nodeTitle)
}

func CMCurrentActionPreferencePaths() -> [String] {
    ActionFileStore.shared.currentActionNodePaths()
}

func CMCurrentExpandedActionPreferencePaths() -> [String] {
    ActionFileStore.shared.currentExpandedActionNodePaths(
        ids: ActionTreePresentationState.shared.expandedActionNodeIDs
    )
}

func CMCurrentExpandedReservedPreferencePaths() -> [String] {
    ActionFileStore.shared.currentExpandedReservedNodePaths(
        ids: ActionTreePresentationState.shared.expandedReservedNodeIDs
    )
}

func CMSetExpandedActionPreferencePathsForTesting(_ paths: [String]) {
    ActionTreePresentationState.shared.expandedActionNodeIDs =
        ActionFileStore.shared.actionNodeIDs(forPaths: paths)
}

func CMSetExpandedReservedPreferencePathsForTesting(_ paths: [String]) {
    ActionTreePresentationState.shared.expandedReservedNodeIDs =
        ActionFileStore.shared.reservedNodeIDs(forPaths: paths)
}

@discardableResult
func CMToggleExpandedActionPreferencePathForTesting(path: String) -> Bool {
    guard let nodeID = ActionFileStore.shared.actionNodeID(path: path) else {
        return false
    }

    if ActionTreePresentationState.shared.expandedActionNodeIDs.contains(nodeID) {
        ActionTreePresentationState.shared.expandedActionNodeIDs.remove(nodeID)
    } else {
        ActionTreePresentationState.shared.expandedActionNodeIDs.insert(nodeID)
    }
    return true
}

@discardableResult
func CMToggleExpandedReservedPreferencePathForTesting(path: String) -> Bool {
    guard let nodeID = ActionFileStore.shared.reservedNodeID(path: path) else {
        return false
    }

    if ActionTreePresentationState.shared.expandedReservedNodeIDs.contains(nodeID) {
        ActionTreePresentationState.shared.expandedReservedNodeIDs.remove(nodeID)
    } else {
        ActionTreePresentationState.shared.expandedReservedNodeIDs.insert(nodeID)
    }
    return true
}

func CMCurrentSelectedActionPreferencePath() -> String? {
    ActionFileStore.shared.currentSelectedActionNodePath()
}

@discardableResult
func CMSelectReservedActionPreferenceNodeForTesting(path: String) -> Bool {
    let didSelect = ActionFileStore.shared.selectReservedNode(path: path)
    if didSelect {
        ActionInspectorState.shared.activePane = .reserved
    }
    return didSelect
}

func CMCurrentActionInspectorSnapshotForTesting() -> [String: Any]? {
    guard let snapshot = ActionInspectorState.shared.currentSnapshot() else {
        return nil
    }

    var report: [String: Any] = [
        "pane": snapshot.pane.rawValue,
        "name": snapshot.node.nodeTitle,
        "type": CMActionInspectorTypeTitle(for: snapshot.node),
        "isEditable": snapshot.pane == .action
    ]
    report["path"] = CMActionInspectorPath(for: snapshot.node) ?? NSNull()
    report["rowSubtitle"] = CMActionNodeRowSubtitle(for: snapshot.node)
    report["rowBadgeTitle"] = CMActionNodeRowBadgeTitle(for: snapshot.node) ?? NSNull()
    return report
}

func CMTestActionInspectorNameEditForTesting(_ value: String) -> [String: Any]? {
    guard let before = CMCurrentActionInspectorSnapshotForTesting() else {
        return nil
    }
    let replaced = FocusablePlainTextField.debugReplaceText(value, for: "action-inspector-name")
    let committed = FocusablePlainTextField.debugAttemptCommit(for: "action-inspector-name") ?? false
    let after = CMCurrentActionInspectorSnapshotForTesting() ?? [:]
    return [
        "before": before,
        "replacementApplied": replaced,
        "commitSucceeded": committed,
        "after": after
    ]
}

@discardableResult
func CMMoveActionNodeForTesting(sourcePath: String, destinationParentPath: String?, insertionIndex: Int?) -> Bool {
    ActionFileStore.shared.moveActionNodeForTesting(
        sourcePath: sourcePath,
        destinationParentPath: destinationParentPath,
        insertionIndex: insertionIndex
    )
}

@discardableResult
func CMInsertReservedActionForTesting(reservedPath: String, destinationParentPath: String?, insertionIndex: Int?) -> Bool {
    ActionFileStore.shared.insertReservedActionForTesting(
        reservedPath: reservedPath,
        destinationParentPath: destinationParentPath,
        insertionIndex: insertionIndex
    )
}

func CMCurrentUserReservedActionTitles() -> [String] {
    ActionFileStore.shared.userReservedActionTitles()
}

func CMCurrentBundledReservedActionTitles() -> [String] {
    ActionFileStore.shared.bundledReservedActionTitles()
}

@discardableResult
func CMSetReservedActionKindForTesting(_ kind: String) -> Bool {
    switch kind.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "builtin":
        ActionFileStore.shared.reservedKind = .builtin
        return true
    case "bundled", "javascript", "script", "scripts":
        ActionFileStore.shared.reservedKind = .bundled
        return true
    case "user", "users", "user's":
        ActionFileStore.shared.reservedKind = .user
        return true
    default:
        return false
    }
}

@discardableResult
func CMAddUserReservedActionForTesting(path: String) -> Bool {
    ActionFileStore.shared.addUserReservedAction(path: path)
}

private struct StoreTypePreferencesViewContent: View {
    @ObservedObject private var store = RecordingPreferencesStore.shared

    private let legacyStoreTypesSectionTitle = NSLocalizedString(
        "1088.title",
        tableName: "Preferences",
        bundle: .main,
        value: "Select clipboard types to store:",
        comment: ""
    )

    var body: some View {
        PreferenceSection(legacyStoreTypesSectionTitle) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Spacer(minLength: 0)

                    Button(NSLocalizedString("1066.title", tableName: "Preferences", bundle: .main, value: "Check All", comment: "")) {
                        store.enableAllStoreTypes()
                    }
                    .controlSize(.small)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(StoreTypeOption.all) { option in
                        storeTypeToggleCard(option: option)
                    }
                }
            }
        }
        .onAppear(perform: store.reload)
    }

    private func storeTypeToggleCard(option: StoreTypeOption) -> some View {
        return Toggle(isOn: store.binding(for: option)) {
            Text(option.title)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.checkbox)
        .padding(.vertical, 1)
    }
}

private struct ExcludedApplicationsPreferenceControl: View {
    @ObservedObject private var store = RecordingPreferencesStore.shared
    @State private var isPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("1451.title", tableName: "Preferences", bundle: .main, value: "Exclude Apps", comment: ""))
                .font(.subheadline.weight(.semibold))

            Text(summaryText)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)

            Text("\(countBadgeText) • \(selectionScopeBadgeText)")
                .font(.caption)
                .foregroundColor(.secondary)

            if !store.excludedApps.isEmpty {
                Text(appPreviewText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Button(NSLocalizedString("1448.title", tableName: "Preferences", bundle: .main, value: "Define Exclude Options...", comment: "")) {
                store.reload()
                isPresented = true
            }
            .fixedSize()
        }
        .frame(maxWidth: 320, alignment: .leading)
        .sheet(isPresented: $isPresented) {
            ExcludedApplicationsEditorSheet(store: store, isPresented: $isPresented)
        }
        .onAppear(perform: store.reload)
    }

    private var countBadgeText: String {
        let count = store.excludedApps.count
        return count == 1
            ? NSLocalizedString("1 app", comment: "")
            : String(format: NSLocalizedString("%d apps", comment: ""), count)
    }

    private var summaryText: String {
        let count = store.excludedApps.count
        if count == 0 {
            return NSLocalizedString("No applications are currently excluded from clipboard capture.", comment: "")
        }
        if count == 1 {
            return store.excludedApps[0].name
        }
        let names = store.excludedApps.prefix(2).map(\.name)
        if count == 2 {
            return names.joined(separator: ", ")
        }
        return String(
            format: NSLocalizedString("%1$@, %2$@, and %3$d more", comment: ""),
            names.first ?? "",
            names.dropFirst().first ?? "",
            count - 2
        )
    }

    private var selectionScopeBadgeText: String {
        store.excludedApps.isEmpty
            ? NSLocalizedString("Capture open to all apps", comment: "")
            : NSLocalizedString("Capture filtered by app", comment: "")
    }

    private var appPreviewText: String {
        let preview = Array(store.excludedApps.prefix(3).map(\.name))
        if store.excludedApps.count > 3 {
            return preview.joined(separator: ", ")
                + ", "
                + String(format: NSLocalizedString("%d more", comment: ""), store.excludedApps.count - 3)
        }
        return preview.joined(separator: ", ")
    }
}

private struct ExcludedApplicationsEditorSheet: View {
    @ObservedObject var store: RecordingPreferencesStore
    @Binding var isPresented: Bool
    @State private var didApplyChanges = false

    private var runningApps: [AvailableRunningApp] {
        CMAvailableRunningAppsForExclusion(excluding: store.excludedApps)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("1459.title", tableName: "Preferences", bundle: .main, value: "Exclude these applications:", comment: ""))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    excludedAppList
                }
                addAppsSidebar
            }

            HStack {
                Spacer()
                Button(NSLocalizedString("1456.title", tableName: "Preferences", bundle: .main, value: "Cancel", comment: "")) {
                    store.revertExcludedApps()
                    isPresented = false
                }
                Button(NSLocalizedString("1454.title", tableName: "Preferences", bundle: .main, value: "Done", comment: "")) {
                    didApplyChanges = true
                    store.applyExcludedApps()
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 620, height: 360)
        .onDisappear {
            if !didApplyChanges {
                store.revertExcludedApps()
            }
        }
    }

    private var addAppsSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("Add Applications", comment: ""))
                    .font(.subheadline.weight(.semibold))

                Text(NSLocalizedString("Add running apps quickly, or choose any app bundle manually.", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Menu {
                if runningApps.isEmpty {
                    Text(NSLocalizedString("No Running Applications", comment: ""))
                } else {
                    ForEach(runningApps) { app in
                        Button {
                            store.addRunningApp(app)
                        } label: {
                            Label {
                                Text(app.name)
                            } icon: {
                                Image(nsImage: app.icon)
                            }
                        }
                    }
                }
                Divider()
                Button(NSLocalizedString("Other...", comment: "")) {
                    store.addAppsFromPanel()
                }
            } label: {
                Text(NSLocalizedString("Add", comment: ""))
                    .frame(maxWidth: .infinity)
            }
            .menuStyle(.borderlessButton)

            if runningApps.isEmpty {
                Text(NSLocalizedString("No currently running apps are available to add.", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("Running now", comment: ""))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    ForEach(runningApps.prefix(4)) { app in
                        HStack(spacing: 8) {
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(app.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(width: 180, alignment: .topLeading)
    }

    private var excludedAppList: some View {
        VStack(spacing: 0) {
            excludedAppsListHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if store.excludedApps.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 26, weight: .regular))
                                .foregroundColor(.secondary)
                            Text(NSLocalizedString("No Excluded Applications", comment: ""))
                                .font(.headline)
                            Text(NSLocalizedString("Add running apps or choose app bundles to stop ClipMenu from recording them.", comment: ""))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        ForEach(store.excludedApps) { app in
                            HStack(spacing: 8) {
                                Image(nsImage: icon(for: app))
                                    .resizable()
                                    .frame(width: 18, height: 18)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(app.name)
                                        .lineLimit(1)
                                    Text(app.bundleIdentifier)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                Button {
                                    store.remove(app)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .buttonStyle(.plain)
                                .help(NSLocalizedString("Remove", comment: ""))
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(8)
            }
        }
        .frame(minWidth: 420, minHeight: 120, alignment: .topLeading)
        .background(Color(NSColor.textBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }

    private var excludedAppsListHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Text(legacyExcludedAppsNameHeader)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.75))

            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 1)
        }
    }

    private var legacyExcludedAppsNameHeader: String {
        NSLocalizedString("612.headerCell.title", tableName: "Preferences", bundle: .main, value: "Name", comment: "")
    }

    private func icon(for app: ExcludedApp) -> NSImage {
        if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == app.bundleIdentifier }),
           let url = runningApp.bundleURL {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(forFileType: "app")
    }

}

private struct GeneralPreferencesView: View {
    @AppStorage(CMPrefLoginItemKey) private var loginItem = false
    @AppStorage(CMPrefSuppressAlertForLoginItemKey) private var suppressLoginItemAlert = false
    @AppStorage(CMPrefInputPasteCommandKey) private var inputPasteCommand = true
    @AppStorage(CMPrefReorderClipsAfterPasting) private var reorderClipsAfterPasting = true
    @AppStorage(CMPrefSaveHistoryOnQuitKey) private var saveHistoryOnQuit = true
    @AppStorage(CMPrefExportHistoryAsSingleFileKey) private var exportHistoryAsSingleFile = true
    @AppStorage(CMPrefTagOfSeparatorForExportHistoryToFileKey) private var exportSeparator = 1
    @AppStorage(CMPrefShowStatusItemKey) private var showStatusItem = 1
    @AppStorage(CMPrefMaxHistorySizeKey) private var maxHistorySize = 20
    @AppStorage(CMPrefAutosaveDelayKey) private var autosaveDelay = 1800
    @AppStorage(CMPrefTimeIntervalKey) private var timeInterval = 0.75

    private let legacyLaunchOnLoginLabel = NSLocalizedString("768.title", tableName: "Preferences", bundle: .main, value: "Launch on Login", comment: "")
    private let legacySuppressStartupLaunchPromptLabel = NSLocalizedString("Do not ask about startup launch", comment: "")
    private let legacyInputPasteCommandLabel = NSLocalizedString("690.title", tableName: "Preferences", bundle: .main, value: "Input \"⌘ + V\" after menu item selection", comment: "")
    private let legacySortHistoryLabel = NSLocalizedString("1417.title", tableName: "Preferences", bundle: .main, value: "Sort history order by:", comment: "")
    private let legacyLastUsedLabel = NSLocalizedString("1422.title", tableName: "Preferences", bundle: .main, value: "Last Used", comment: "")
    private let legacyDateCreatedLabel = NSLocalizedString("1421.title", tableName: "Preferences", bundle: .main, value: "Date Created", comment: "")
    private let legacyExcludeApplicationsLabel = NSLocalizedString("1446.title", tableName: "Preferences", bundle: .main, value: "Exclude Applications", comment: "")
    private let legacySaveHistoryOnQuitLabel = NSLocalizedString("1047.title", tableName: "Preferences", bundle: .main, value: "Save clipboard history on quit", comment: "")
    private let legacyExportHistoryAsLabel = NSLocalizedString("1380.title", tableName: "Preferences", bundle: .main, value: "Export clipboard history as:", comment: "")
    private let legacySingleFileLabel = NSLocalizedString("1384.title", tableName: "Preferences", bundle: .main, value: "Single file", comment: "")
    private let legacyMultipleFilesLabel = NSLocalizedString("1385.title", tableName: "Preferences", bundle: .main, value: "Multiple files", comment: "")
    private let legacySeparatorLabel = NSLocalizedString("1396.title", tableName: "Preferences", bundle: .main, value: "separator:", comment: "")
    private let legacyExportButtonLabel = NSLocalizedString("1390.title", tableName: "Preferences", bundle: .main, value: "Export...", comment: "")
    private let legacyAutosaveHistoryLabel = NSLocalizedString("1281.title", tableName: "Preferences", bundle: .main, value: "Autosaving clipboard history:", comment: "")
    private let legacyEveryThirtyMinutesLabel = NSLocalizedString("1289.title", tableName: "Preferences", bundle: .main, value: "Every 30 minutes", comment: "")
    private let legacyEveryMinuteLabel = NSLocalizedString("1286.title", tableName: "Preferences", bundle: .main, value: "Every minute", comment: "")
    private let legacyEveryFiveMinutesLabel = NSLocalizedString("1287.title", tableName: "Preferences", bundle: .main, value: "Every 5 minutes", comment: "")
    private let legacyEveryTenMinutesLabel = NSLocalizedString("1290.title", tableName: "Preferences", bundle: .main, value: "Every 10 minutes", comment: "")
    private let legacyEveryHourLabel = NSLocalizedString("1291.title", tableName: "Preferences", bundle: .main, value: "Every hour", comment: "")
    private let legacyEveryThreeHoursLabel = NSLocalizedString("1292.title", tableName: "Preferences", bundle: .main, value: "Every 3 hours", comment: "")
    private let legacyEverySixHoursLabel = NSLocalizedString("1293.title", tableName: "Preferences", bundle: .main, value: "Every 6 hours", comment: "")
    private let legacyEveryTwelveHoursLabel = NSLocalizedString("1294.title", tableName: "Preferences", bundle: .main, value: "Every 12 hours", comment: "")
    private let legacyNeverLabel = NSLocalizedString("1285.title", tableName: "Preferences", bundle: .main, value: "Never", comment: "")
    private let legacyClipboardObserveIntervalLabel = NSLocalizedString("686.title", tableName: "Preferences", bundle: .main, value: "Time interval to observe the clipboard:", comment: "")
    private let legacySecondsLabel = NSLocalizedString("689.title", tableName: "Preferences", bundle: .main, value: "sec.", comment: "")
    private let legacyStatusBarIconStyleLabel = NSLocalizedString("1316.title", tableName: "Preferences", bundle: .main, value: "Status Bar icon style:", comment: "")

    private var exportSeparatorSelection: Binding<Int> {
        Binding(
            get: { CMNormalizedLegacyExportSeparatorTag(exportSeparator) },
            set: { exportSeparator = CMNormalizedLegacyExportSeparatorTag($0) }
        )
    }

    private var exportModeSelection: Binding<Bool> {
        Binding(
            get: { CMNormalizedLegacyExportHistoryAsSingleFileValue(exportHistoryAsSingleFile) },
            set: { exportHistoryAsSingleFile = $0 }
        )
    }

    private var reorderClipsAfterPastingSelection: Binding<Bool> {
        Binding(
            get: { CMNormalizedLegacyReorderClipsAfterPastingValue(reorderClipsAfterPasting) },
            set: { reorderClipsAfterPasting = $0 }
        )
    }

    private var observeIntervalSelection: Binding<Double> {
        Binding(
            get: { CMNormalizedLegacyObserveInterval(timeInterval) },
            set: { timeInterval = CMNormalizedLegacyObserveInterval($0) }
        )
    }

    private var maxHistorySizeSelection: Binding<Int> {
        Binding(
            get: { CMNormalizedLegacyMaxHistorySize(maxHistorySize) },
            set: { maxHistorySize = CMNormalizedLegacyMaxHistorySize($0) }
        )
    }

    private var excludedApps: [String] {
        (UserDefaults.standard.array(forKey: CMPrefExcludeAppsKey) ?? [])
            .compactMap(ExcludedApp.init(defaultsObject:))
            .map(\.name)
    }

    var body: some View {
        PreferencePane {
            PreferenceSection(NSLocalizedString("Startup", comment: "")) {
                PreferenceToggle(title: legacyLaunchOnLoginLabel, isOn: $loginItem)
                    .disabled(!LoginItemManager.supportsMainAppLoginItem)
                PreferenceToggle(title: legacySuppressStartupLaunchPromptLabel, isOn: $suppressLoginItemAlert)
                    .disabled(!LoginItemManager.supportsMainAppLoginItem)
            }
            PreferenceSection(legacyClipboardHistorySectionTitle) {
                PreferenceToggle(title: legacyInputPasteCommandLabel, isOn: $inputPasteCommand)
                if inputPasteCommand {
                    PasteAutomationPreferencesView()
                        .padding(.leading, 26)
                }
                PreferenceRow(legacySortHistoryLabel) {
                    PreferencePicker(selection: reorderClipsAfterPastingSelection, width: 170) {
                        Text(legacyLastUsedLabel).tag(true)
                        Text(legacyDateCreatedLabel).tag(false)
                    }
                }
                PreferenceRow(legacyExcludeApplicationsLabel) {
                    ExcludedApplicationsPreferenceControl()
                }
                PreferenceToggle(title: legacySaveHistoryOnQuitLabel, isOn: $saveHistoryOnQuit)
                VStack(alignment: .leading, spacing: 10) {
                    PreferenceRow(legacyExportHistoryAsLabel) {
                        PreferencePicker(selection: exportModeSelection, width: 170) {
                            Text(legacySingleFileLabel).tag(true)
                            Text(legacyMultipleFilesLabel).tag(false)
                        }
                    }
                    PreferenceRow(legacySeparatorLabel) {
                        PreferencePicker(selection: exportSeparatorSelection, width: 170) {
                            Text(NSLocalizedString("LF", comment: "")).tag(1)
                            Text(NSLocalizedString("CR+LF", comment: "")).tag(2)
                            Text(NSLocalizedString("CR", comment: "")).tag(3)
                            Text(NSLocalizedString("Tab", comment: "")).tag(4)
                            Text(NSLocalizedString("Space", comment: "")).tag(5)
                            Text(NSLocalizedString("None", comment: "")).tag(0)
                        }
                        .disabled(!exportHistoryAsSingleFile)
                    }
                    PreferenceRow("") {
                        Button(legacyExportButtonLabel) {
                            NSApp.sendAction(#selector(AppController.exportHistory(_:)), to: NSApp.delegate, from: nil)
                        }
                    }
                }
                PreferenceStepper(
                    NSLocalizedString("1164.title", tableName: "Preferences", bundle: .main, value: "Max clipboard history size:", comment: ""),
                    value: maxHistorySizeSelection,
                    in: 1...Int.max,
                    suffix: NSLocalizedString("1171.title", tableName: "Preferences", bundle: .main, value: "items", comment: "")
                )
                PreferenceRow(legacyAutosaveHistoryLabel) {
                    PreferencePicker(
                        selection: Binding(
                            get: { CMNormalizedLegacyAutosaveDelay(autosaveDelay) },
                            set: { autosaveDelay = CMNormalizedLegacyAutosaveDelay($0) }
                        ),
                        width: 190
                    ) {
                        Text(legacyEveryThirtyMinutesLabel).tag(1800)
                        Text(legacyEveryMinuteLabel).tag(60)
                        Text(legacyEveryFiveMinutesLabel).tag(300)
                        Text(legacyEveryTenMinutesLabel).tag(600)
                        Text(legacyEveryHourLabel).tag(3600)
                        Text(legacyEveryThreeHoursLabel).tag(10800)
                        Text(legacyEverySixHoursLabel).tag(21600)
                        Text(legacyEveryTwelveHoursLabel).tag(43200)
                        Text(NSLocalizedString("1295.title", tableName: "Preferences", bundle: .main, value: "Every day", comment: "")).tag(86400)
                        Text(legacyNeverLabel).tag(0)
                    }
                }
                PreferenceRow(legacyClipboardObserveIntervalLabel) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Text(NSLocalizedString("Faster", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Slider(value: observeIntervalSelection, in: 0.0...1.0)
                                .frame(maxWidth: 320)

                            Text(NSLocalizedString("Lighter", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            PreferenceDoubleField(value: observeIntervalSelection, range: 0.0...1.0)

                            Text(legacySecondsLabel)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            SnippetPlacementPreferenceSection()
            PreferenceSection(legacyAppearanceSectionTitle) {
                PreferenceRow(legacyStatusBarIconStyleLabel) {
                    StatusItemPreviewPicker(selection: $showStatusItem)
                }
            }
        }
        .onAppear(perform: normalizeStoredValues)
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            normalizeStoredValues()
        }
    }

    private func normalizeStoredValues() {
        let defaults = UserDefaults.standard
        let normalizedExportSeparator = CMNormalizedLegacyExportSeparatorTag(exportSeparator)
        if normalizedExportSeparator != exportSeparator {
            exportSeparator = normalizedExportSeparator
        }
        let normalizedExportMode = CMNormalizedLegacyExportHistoryAsSingleFileValue(exportHistoryAsSingleFile)
        if normalizedExportMode != exportHistoryAsSingleFile {
            exportHistoryAsSingleFile = normalizedExportMode
        }
        let normalizedSortOrder = CMNormalizedLegacyReorderClipsAfterPastingValue(reorderClipsAfterPasting)
        if normalizedSortOrder != reorderClipsAfterPasting {
            reorderClipsAfterPasting = normalizedSortOrder
        }
        let normalizedStatusItemTag = CMNormalizedStatusItemSelectionTag(showStatusItem)
        if normalizedStatusItemTag != showStatusItem {
            showStatusItem = normalizedStatusItemTag
        }
        let normalizedAutosaveDelay = CMNormalizedLegacyAutosaveDelay(autosaveDelay)
        if normalizedAutosaveDelay != autosaveDelay {
            autosaveDelay = normalizedAutosaveDelay
        }
        let normalizedMaxHistorySize = CMNormalizedLegacyMaxHistorySize(maxHistorySize)
        if normalizedMaxHistorySize != maxHistorySize {
            maxHistorySize = normalizedMaxHistorySize
        }
        let normalizedObserveInterval = CMNormalizedLegacyObserveInterval(
            defaults.object(forKey: CMPrefTimeIntervalKey) as? Double ?? timeInterval
        )
        if abs(normalizedObserveInterval - timeInterval) > 0.0001 {
            timeInterval = normalizedObserveInterval
        }
    }

    private var legacyClipboardHistorySectionTitle: String {
        NSLocalizedString("1275.title", tableName: "Preferences", bundle: .main, value: "Clipboard History", comment: "")
    }

    private var legacyAppearanceSectionTitle: String {
        NSLocalizedString("1277.title", tableName: "Preferences", bundle: .main, value: "Appearance", comment: "")
    }

    private var selectedStatusItemOption: StatusItemOption {
        StatusItemOption(rawValue: CMNormalizedStatusItemSelectionTag(showStatusItem)) ?? .default
    }
}

private struct StatusItemPreviewPicker: View {
    @Binding var selection: Int

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Picker("", selection: $selection) {
                ForEach(StatusItemOption.allCases) { option in
                    Text(option.title).tag(option.tag)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 220, alignment: .leading)

            statusMenuBarPreview(option: selectedOption)
        }
        .frame(maxWidth: 420, alignment: .leading)
    }

    private func statusMenuBarPreview(option: StatusItemOption) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(option == .none ? Color.clear : Color(NSColor.separatorColor).opacity(0.6))
                .frame(width: 4, height: 4)
            StatusItemPreviewImage(option: option)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(NSColor.separatorColor).opacity(0.55))
                .frame(width: 24, height: 4)
        }
        .padding(.vertical, 1)
    }

    private var selectedOption: StatusItemOption {
        StatusItemOption(rawValue: CMNormalizedStatusItemSelectionTag(selection)) ?? .default
    }
}

private enum StatusItemGallerySection: String, CaseIterable, Identifiable {
    case classic
    case scissors1
    case diagonal
    case scissors2

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic:
            return NSLocalizedString("Classic Styles", comment: "")
        case .scissors1:
            return NSLocalizedString("Scissors 1 Styles", comment: "")
        case .diagonal:
            return NSLocalizedString("Diagonal Styles", comment: "")
        case .scissors2:
            return NSLocalizedString("Scissors 2 Styles", comment: "")
        }
    }

    var detail: String {
        switch self {
        case .classic:
            return NSLocalizedString("Hidden, standard, and full color menu bar styles.", comment: "")
        case .scissors1:
            return NSLocalizedString("The first scissors set, in monochrome and color left and right variants.", comment: "")
        case .diagonal:
            return NSLocalizedString("Compact diagonal variants for a lighter menu bar presence.", comment: "")
        case .scissors2:
            return NSLocalizedString("The second scissors set, in monochrome and color left and right variants.", comment: "")
        }
    }

    var options: [StatusItemOption] {
        StatusItemOption.allCases.filter { $0.gallerySection == self }
    }
}

private struct StatusItemPreviewImage: View {
    let option: StatusItemOption

    var body: some View {
        Group {
            if option == .none {
                Image(systemName: "eye.slash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
            } else if let image = option.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "scissors")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 26, height: 26)
    }
}

private enum StatusItemOption: Int, CaseIterable, Identifiable {
    case none = 0
    case `default` = 1
    case original = 2
    case scissors1Left = 3
    case scissors1Right = 4
    case scissors1LeftColor = 5
    case scissors1RightColor = 6
    case diagonal = 7
    case diagonalColor = 8
    case scissors2Left = 9
    case scissors2Right = 10
    case scissors2LeftColor = 11
    case scissors2RightColor = 12

    var id: Int { rawValue }
    var tag: Int { rawValue }

    var title: String {
        switch self {
        case .none:
            return NSLocalizedString("None", comment: "")
        case .default:
            return NSLocalizedString("Default", comment: "")
        case .original:
            return NSLocalizedString("Original", comment: "")
        case .scissors1Left:
            return NSLocalizedString("Scissors 1 Left", comment: "")
        case .scissors1Right:
            return NSLocalizedString("Scissors 1 Right", comment: "")
        case .scissors1LeftColor:
            return NSLocalizedString("Scissors 1 Left Color", comment: "")
        case .scissors1RightColor:
            return NSLocalizedString("Scissors 1 Right Color", comment: "")
        case .diagonal:
            return NSLocalizedString("Diagonal", comment: "")
        case .diagonalColor:
            return NSLocalizedString("Diagonal Color", comment: "")
        case .scissors2Left:
            return NSLocalizedString("Scissors 2 Left", comment: "")
        case .scissors2Right:
            return NSLocalizedString("Scissors 2 Right", comment: "")
        case .scissors2LeftColor:
            return NSLocalizedString("Scissors 2 Left Color", comment: "")
        case .scissors2RightColor:
            return NSLocalizedString("Scissors 2 Right Color", comment: "")
        }
    }

    var imageName: String {
        switch self {
        case .none:
            return ""
        case .default:
            return "StatusMenuIcon"
        case .original:
            return "StatusMenuIconFirst"
        case .scissors1Left:
            return "StatusMenuIconByDaveUlrich-scissors1-bw-left"
        case .scissors1Right:
            return "StatusMenuIconByDaveUlrich-scissors1-bw-right"
        case .scissors1LeftColor:
            return "StatusMenuIconByDaveUlrich-scissors1-color-left"
        case .scissors1RightColor:
            return "StatusMenuIconByDaveUlrich-scissors1-color-right"
        case .diagonal:
            return "StatusMenuIconByDaveUlrich-diagonal-bw"
        case .diagonalColor:
            return "StatusMenuIconByDaveUlrich-diagonal-color"
        case .scissors2Left:
            return "StatusMenuIconByDaveUlrich-scissors2-bw-left"
        case .scissors2Right:
            return "StatusMenuIconByDaveUlrich-scissors2-bw-right"
        case .scissors2LeftColor:
            return "StatusMenuIconByDaveUlrich-scissors2-color-left"
        case .scissors2RightColor:
            return "StatusMenuIconByDaveUlrich-scissors2-color-right"
        }
    }

    var usesTemplateRendering: Bool {
        switch self {
        case .none:
            return true
        case .scissors1LeftColor, .scissors1RightColor, .diagonalColor, .scissors2LeftColor, .scissors2RightColor:
            return false
        default:
            return true
        }
    }

    var image: NSImage? {
        guard self != .none else { return nil }
        guard let image = NSImage(named: imageName) else { return nil }
        image.isTemplate = usesTemplateRendering
        return image
    }

    var previewRenderingLabel: String {
        self == .none
            ? NSLocalizedString("Hidden", comment: "")
            : (usesTemplateRendering ? NSLocalizedString("Template", comment: "") : NSLocalizedString("Color", comment: ""))
    }

    var previewCategoryLabel: String {
        switch self {
        case .none:
            return NSLocalizedString("Off", comment: "")
        case .default, .original:
            return NSLocalizedString("Classic", comment: "")
        case .diagonal, .diagonalColor:
            return NSLocalizedString("Diagonal", comment: "")
        default:
            return NSLocalizedString("Scissors", comment: "")
        }
    }

    var gallerySection: StatusItemGallerySection {
        switch self {
        case .none, .default, .original:
            return .classic
        case .scissors1Left, .scissors1Right, .scissors1LeftColor, .scissors1RightColor:
            return .scissors1
        case .diagonal, .diagonalColor:
            return .diagonal
        case .scissors2Left, .scissors2Right, .scissors2LeftColor, .scissors2RightColor:
            return .scissors2
        }
    }

}

private struct ShortcutsPreferencesView: View {
    @AppStorage(CMPrefHotKeyEnabledKey) private var hotKeyEnabled = true
    @AppStorage(CMPrefHotKeyKeyCodeKey) private var hotKeyKeyCode = 9
    @AppStorage(CMPrefHotKeyModifierFlagsKey) private var hotKeyModifierFlags = Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)
    @AppStorage(CMPrefSnippetsHotKeyEnabledKey) private var snippetsHotKeyEnabled = true
    @AppStorage(CMPrefSnippetsHotKeyKeyCodeKey) private var snippetsHotKeyKeyCode = 11
    @AppStorage(CMPrefSnippetsHotKeyModifierFlagsKey) private var snippetsHotKeyModifierFlags = Int(NSEvent.ModifierFlags([.command, .shift]).rawValue)

    var body: some View {
        PreferencePane {
            PreferenceSection(legacyShortcutsSectionTitle) {
                VStack(alignment: .leading, spacing: 10) {
                    ShortcutRecorderRow(
                        title: legacyClipMenuShortcutLabel,
                        detail: NSLocalizedString("Open the full ClipMenu popup at the pointer.", comment: ""),
                        keyCode: hotKeyCodeBinding,
                        modifierFlags: hotKeyModifierFlagsBinding
                    )
                    ShortcutRecorderRow(
                        title: legacySnippetsShortcutLabel,
                        detail: NSLocalizedString("Open the snippets-only menu when folders are available.", comment: ""),
                        keyCode: snippetsHotKeyCodeBinding,
                        modifierFlags: snippetsHotKeyModifierFlagsBinding
                    )
                }
            }
        }
    }

    private var legacyShortcutsSectionTitle: String {
        NSLocalizedString("1366.title", tableName: "Preferences", bundle: .main, value: "Shortcuts", comment: "")
    }

    private var legacyClipMenuShortcutLabel: String {
        NSLocalizedString("1371.title", tableName: "Preferences", bundle: .main, value: "ClipMenu:", comment: "")
    }

    private var legacySnippetsShortcutLabel: String {
        NSLocalizedString("1372.title", tableName: "Preferences", bundle: .main, value: "Snippets menu:", comment: "")
    }

    private var hotKeyCodeBinding: Binding<Int> {
        Binding(
            get: { hotKeyEnabled ? hotKeyKeyCode : -1 },
            set: { newValue in
                hotKeyKeyCode = newValue
                hotKeyEnabled = newValue >= 0 && hotKeyModifierFlags != 0
            }
        )
    }

    private var hotKeyModifierFlagsBinding: Binding<Int> {
        Binding(
            get: { hotKeyEnabled ? hotKeyModifierFlags : 0 },
            set: { newValue in
                hotKeyModifierFlags = newValue
                hotKeyEnabled = hotKeyKeyCode >= 0 && newValue != 0
            }
        )
    }

    private var snippetsHotKeyCodeBinding: Binding<Int> {
        Binding(
            get: { snippetsHotKeyEnabled ? snippetsHotKeyKeyCode : -1 },
            set: { newValue in
                snippetsHotKeyKeyCode = newValue
                snippetsHotKeyEnabled = newValue >= 0 && snippetsHotKeyModifierFlags != 0
            }
        )
    }

    private var snippetsHotKeyModifierFlagsBinding: Binding<Int> {
        Binding(
            get: { snippetsHotKeyEnabled ? snippetsHotKeyModifierFlags : 0 },
            set: { newValue in
                snippetsHotKeyModifierFlags = newValue
                snippetsHotKeyEnabled = snippetsHotKeyKeyCode >= 0 && newValue != 0
            }
        )
    }

    private var historyShortcutDisplay: String {
        HotKeyRecorderDisplayString(
            keyCode: 9,
            modifierFlags: Int(NSEvent.ModifierFlags([.command, .control]).rawValue)
        )
    }
}

private struct ShortcutRecorderRow: View {
    let title: String
    let detail: String
    @Binding var keyCode: Int
    @Binding var modifierFlags: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.body.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)

            HotKeyRecorderControl(
                keyCode: $keyCode,
                modifierFlags: $modifierFlags
            )
            .frame(width: 210, height: 28)

            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MenuPreferencesView: View {
    @AppStorage(CMPrefMaxMenuItemTitleLengthKey) private var maxTitleLength = 20
    @AppStorage(CMPrefNumberOfItemsPlaceInlineKey) private var inlineItems = 0
    @AppStorage(CMPrefNumberOfItemsPlaceInsideFolderKey) private var folderItems = 10
    @AppStorage(CMPrefMenuItemsAreMarkedWithNumbersKey) private var markWithNumbers = true
    @AppStorage(CMPrefMenuItemsTitleStartWithZeroKey) private var titleStartsWithZero = false
    @AppStorage(CMPrefAddNumericKeyEquivalentsKey) private var numericKeyEquivalents = false
    @AppStorage(CMPrefShowLabelsInMenuKey) private var showLabels = true
    @AppStorage(CMPrefAddClearHistoryMenuItemKey) private var clearHistoryItem = true
    @AppStorage(CMPrefShowAlertBeforeClearHistoryKey) private var alertBeforeClear = true
    @AppStorage(CMPrefShowToolTipOnMenuItemKey) private var showTooltips = true
    @AppStorage(CMPrefMaxLengthOfToolTipKey) private var maxTooltipLength = 200
    @AppStorage(CMPrefChangeFontSizeKey) private var changeFontSize = false
    @AppStorage(CMPrefHowToChangeFontSizeKey) private var howToChangeFontSize = 0
    @AppStorage(CMPrefSelectedFontSizeKey) private var selectedFontSize = 16

    private let legacyMenuCharacterCountLabel = NSLocalizedString("703.title", tableName: "Preferences", bundle: .main, value: "Number of characters in the menu:", comment: "")
    private let legacyMenuCharacterUnitLabel = NSLocalizedString("1173.title", tableName: "Preferences", bundle: .main, value: "chars", comment: "")
    private let legacyInlineItemsLabel = NSLocalizedString("1028.title", tableName: "Preferences", bundle: .main, value: "Number of items place inline:", comment: "")
    private let legacyInlineItemsUnitLabel = NSLocalizedString("1175.title", tableName: "Preferences", bundle: .main, value: "items", comment: "")
    private let legacyFolderItemsLabel = NSLocalizedString("1034.title", tableName: "Preferences", bundle: .main, value: "Number of items place inside a folder:", comment: "")
    private let legacyFolderItemsUnitLabel = NSLocalizedString("1177.title", tableName: "Preferences", bundle: .main, value: "items", comment: "")
    private let legacyMarkMenuItemsLabel = NSLocalizedString("706.title", tableName: "Preferences", bundle: .main, value: "Mark menu items with numbers", comment: "")
    private let legacyStartWithZeroLabel = NSLocalizedString("705.title", tableName: "Preferences", bundle: .main, value: "Menu items' title starts with 0", comment: "")
    private let legacyNumericKeyEquivalentsLabel = NSLocalizedString("743.title", tableName: "Preferences", bundle: .main, value: "Add key equivalents to numeric keys", comment: "")
    private let legacyShowLabelsLabel = NSLocalizedString("1044.title", tableName: "Preferences", bundle: .main, value: "Show labels to indicate item types", comment: "")
    private let legacyClearHistoryMenuItemLabel = NSLocalizedString("701.title", tableName: "Preferences", bundle: .main, value: "Add a menu item to clear clipboard history", comment: "")
    private let legacyAlertBeforeClearLabel = NSLocalizedString("702.title", tableName: "Preferences", bundle: .main, value: "Show alert panel before clear history", comment: "")
    private let legacyShowTooltipsLabel = NSLocalizedString("1157.title", tableName: "Preferences", bundle: .main, value: "Show tool tip on a menu item", comment: "")
    private let legacyToolTipMaxLengthLabel = NSLocalizedString("1256.title", tableName: "Preferences", bundle: .main, value: "Max length of tool tip string:", comment: "")
    private let legacyToolTipCharacterUnitLabel = NSLocalizedString("1259.title", tableName: "Preferences", bundle: .main, value: "chars", comment: "")
    private let legacyChangeFontSizeLabel = NSLocalizedString("744.title", tableName: "Preferences", bundle: .main, value: "Change font size in the menu", comment: "")
    private let legacyFitToIconSizeLabel = NSLocalizedString("1238.title", tableName: "Preferences", bundle: .main, value: "Fit to the icon size", comment: "")
    private let legacySelectFontSizeLabel = NSLocalizedString("1239.title", tableName: "Preferences", bundle: .main, value: "Select:", comment: "")
    private let legacyPointUnitLabel = NSLocalizedString("742.title", tableName: "Preferences", bundle: .main, value: "pt", comment: "")

    private var normalizedTooltipLength: Int {
        CMNormalizedLegacyMenuTooltipLength(maxTooltipLength)
    }

    private var normalizedTitleLength: Int {
        CMNormalizedLegacyMenuTitleLength(maxTitleLength)
    }

    private var normalizedTitleLengthBinding: Binding<Int> {
        Binding(
            get: { normalizedTitleLength },
            set: { maxTitleLength = CMNormalizedLegacyMenuTitleLength($0) }
        )
    }

    private var normalizedInlineItems: Int {
        CMNormalizedLegacyMenuInlineItemsCount(inlineItems)
    }

    private var normalizedInlineItemsBinding: Binding<Int> {
        Binding(
            get: { normalizedInlineItems },
            set: { inlineItems = CMNormalizedLegacyMenuInlineItemsCount($0) }
        )
    }

    private var normalizedFolderItems: Int {
        CMNormalizedLegacyMenuFolderItemsCount(folderItems)
    }

    private var normalizedFolderItemsBinding: Binding<Int> {
        Binding(
            get: { normalizedFolderItems },
            set: { folderItems = CMNormalizedLegacyMenuFolderItemsCount($0) }
        )
    }

    private var normalizedTooltipLengthBinding: Binding<Int> {
        Binding(
            get: { normalizedTooltipLength },
            set: { maxTooltipLength = CMNormalizedLegacyMenuTooltipLength($0) }
        )
    }

    var body: some View {
        PreferencePane {
            PreferenceSection(NSLocalizedString("Layout", comment: "")) {
                menuConfigurationSurface {
                    VStack(alignment: .leading, spacing: 10) {
                        PreferenceStepper(
                            legacyMenuCharacterCountLabel,
                            value: normalizedTitleLengthBinding,
                            in: 1...Int.max,
                            suffix: legacyMenuCharacterUnitLabel
                        )
                        PreferenceStepper(
                            legacyInlineItemsLabel,
                            value: normalizedInlineItemsBinding,
                            in: 0...Int.max,
                            suffix: legacyInlineItemsUnitLabel
                        )
                        PreferenceStepper(
                            legacyFolderItemsLabel,
                            value: normalizedFolderItemsBinding,
                            in: 1...Int.max,
                            suffix: legacyFolderItemsUnitLabel
                        )
                    }
                }
            }
            PreferenceSection(NSLocalizedString("Menu Items", comment: "")) {
                menuRowPreviewSurface
                menuConfigurationSurface {
                    VStack(alignment: .leading, spacing: 10) {
                        menuToggleCard(
                            title: legacyMarkMenuItemsLabel,
                            detail: CMLocalizedModernString(
                                "Prefix menu rows with numbered titles.",
                                japanese: "メニュー行の先頭に番号を付けます。"
                            ),
                            systemImage: "list.ordered",
                            tint: .accentColor,
                            isOn: $markWithNumbers
                        )
                        menuToggleCard(
                            title: legacyStartWithZeroLabel,
                            detail: CMLocalizedModernString(
                                "Switch numbering from `1.` to `0.`.",
                                japanese: "番号表示を `1.` から `0.` に切り替えます。"
                            ),
                            systemImage: "0.circle",
                            tint: .secondary,
                            isOn: $titleStartsWithZero,
                            disabled: !markWithNumbers
                        )
                        menuToggleCard(
                            title: legacyNumericKeyEquivalentsLabel,
                            detail: CMLocalizedModernString(
                                "Use number keys to select visible menu items.",
                                japanese: "数字キーで表示中のメニュー項目を選択できるようにします。"
                            ),
                            systemImage: "number",
                            tint: .green,
                            isOn: $numericKeyEquivalents
                        )
                    }
                }
                menuConfigurationSurface {
                    VStack(alignment: .leading, spacing: 10) {
                        menuToggleCard(
                            title: legacyShowLabelsLabel,
                            detail: NSLocalizedString("Show or hide the History and Snippets section labels in the menu.", comment: ""),
                            systemImage: "tag",
                            tint: .blue,
                            isOn: $showLabels
                        )
                        menuToggleCard(
                            title: legacyClearHistoryMenuItemLabel,
                            detail: NSLocalizedString("Keep the explicit Clear History command visible in the main status menu.", comment: ""),
                            systemImage: "trash",
                            tint: .orange,
                            isOn: $clearHistoryItem
                        )
                        menuToggleCard(
                            title: legacyAlertBeforeClearLabel,
                            detail: NSLocalizedString("Ask for confirmation before clearing unless suppression has been chosen.", comment: ""),
                            systemImage: "exclamationmark.bubble",
                            tint: .secondary,
                            isOn: $alertBeforeClear,
                            disabled: !clearHistoryItem
                        )
                    }
                }
            }
            PreferenceSection(NSLocalizedString("Tooltips", comment: "")) {
                menuConfigurationSurface {
                    VStack(alignment: .leading, spacing: 10) {
                        menuToggleCard(
                            title: legacyShowTooltipsLabel,
                            detail: NSLocalizedString("Preview long or multiline content without changing the stored clipboard payload.", comment: ""),
                            systemImage: showTooltips ? "message" : "message.slash",
                            tint: showTooltips ? .blue : .secondary,
                            isOn: $showTooltips
                        )

                        PreferenceStepper(
                            legacyToolTipMaxLengthLabel,
                            value: normalizedTooltipLengthBinding,
                            in: 1...Int.max,
                            step: 10,
                            suffix: legacyToolTipCharacterUnitLabel
                        )
                        .disabled(!showTooltips)
                    }
                }
            }
            PreferenceSection(NSLocalizedString("Font", comment: "")) {
                menuConfigurationSurface {
                    VStack(alignment: .leading, spacing: 10) {
                        menuToggleCard(
                            title: legacyChangeFontSizeLabel,
                            detail: NSLocalizedString("Choose whether menu titles follow the icon size or a fixed point size.", comment: ""),
                            systemImage: "textformat.size",
                            tint: changeFontSize ? .accentColor : .secondary,
                            isOn: $changeFontSize
                        )

                        Picker(selection: normalizedFontSizingModeBinding) {
                            Text(legacyFitToIconSizeLabel).tag(0)
                            Text(legacySelectFontSizeLabel).tag(1)
                        } label: {
                            EmptyView()
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 220, alignment: .leading)
                        .disabled(!changeFontSize)

                        HStack(spacing: 10) {
                            PreferencePicker(selection: normalizedSelectedFontSizeBinding, width: 120) {
                                ForEach(Self.fontSizeOptions, id: \.self) { size in
                                    Text("\(size)").tag(size)
                                }
                            }
                            Text(legacyPointUnitLabel)
                                .foregroundColor(.secondary)
                        }
                        .disabled(!changeFontSize || normalizedFontSizingMode != 1)
                    }
                }
            }
        }
        .onAppear(perform: normalizeMenuPreferencesIfNeeded)
    }

    private static let fontSizeOptions = CMMenuLegacyFontSizeOptions()

    private var normalizedFontSizingMode: Int {
        CMNormalizedMenuLegacyFontSizingMode(howToChangeFontSize)
    }

    private var normalizedFontSizingModeBinding: Binding<Int> {
        Binding(
            get: { normalizedFontSizingMode },
            set: { howToChangeFontSize = CMNormalizedMenuLegacyFontSizingMode($0) }
        )
    }

    private var normalizedSelectedFontSize: Int {
        CMNormalizedMenuLegacyFontSize(selectedFontSize)
    }

    private var normalizedSelectedFontSizeBinding: Binding<Int> {
        Binding(
            get: { normalizedSelectedFontSize },
            set: { selectedFontSize = CMNormalizedMenuLegacyFontSize($0) }
        )
    }

    private var previewHistorySource: String {
        NSLocalizedString("This is a very long history clip title that wraps past the visible menu limit.", comment: "")
    }

    private var previewSnippetSource: String {
        NSLocalizedString("Reusable snippet for previews", comment: "")
    }

    private var previewHeaders: [String] {
        showLabels
            ? [NSLocalizedString("History", comment: ""), NSLocalizedString("Snippets", comment: "")]
            : []
    }

    private var previewHistoryRowTitle: String {
        CMMenuPreviewNumberedTitle(
            CMMenuPreviewTrimmedTitle(previewHistorySource, limit: normalizedTitleLength),
            listNumber: titleStartsWithZero ? 0 : 1,
            markWithNumbers: markWithNumbers
        )
    }

    private var previewSnippetRowTitle: String {
        CMMenuPreviewNumberedTitle(
            CMMenuPreviewTrimmedTitle(previewSnippetSource, limit: normalizedTitleLength),
            listNumber: titleStartsWithZero ? 0 : 1,
            markWithNumbers: markWithNumbers
        )
    }

    private var previewHistoryKeyEquivalent: String {
        CMMenuPreviewKeyEquivalent(
            index: 0,
            markWithNumbers: markWithNumbers,
            startsFromZero: titleStartsWithZero
        )
    }

    private var previewTooltip: String? {
        CMMenuPreviewTooltip(
            text: previewHistorySource,
            maxLength: normalizedTooltipLength,
            showTooltips: showTooltips
        )
    }

    private var menuRowPreviewBadges: [String] {
        [
            markWithNumbers
                ? (titleStartsWithZero ? NSLocalizedString("Numbered from 0", comment: "") : NSLocalizedString("Numbered from 1", comment: ""))
                : NSLocalizedString("Titles only", comment: ""),
            CMMenuNumericShortcutsBadge(enabled: numericKeyEquivalents),
            CMMenuLabelsBadge(shown: showLabels),
            CMMenuTooltipsBadge(enabled: showTooltips)
        ]
    }

    private var menuRowPreviewSurface: some View {
        VStack(alignment: .leading, spacing: 4) {
            if previewHeaders.count == 2 {
                previewHeaderRow(title: previewHeaders[0])
            }
            previewMenuRow(title: previewHistoryRowTitle, keyEquivalent: previewHistoryKeyEquivalent)
            if let previewTooltip {
                Text(previewTooltip)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.leading, 24)
            }
            if previewHeaders.count == 2 {
                previewHeaderRow(title: previewHeaders[1])
            }
            previewFolderRow(title: "QA")
            previewMenuRow(title: previewSnippetRowTitle, keyEquivalent: "", indented: true)
        }
    }

    private func menuConfigurationSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
    }

    private func previewHeaderRow(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func previewFolderRow(title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(title)
                .font(.caption)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func previewMenuRow(title: String, keyEquivalent: String, indented: Bool = false) -> some View {
        HStack(spacing: 8) {
            if indented {
                Color.clear
                    .frame(width: 12, height: 1)
            }
            Text(title)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 8)
            if !keyEquivalent.isEmpty {
                Text(keyEquivalent)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func menuToggleCard(
        title: String,
        detail: String,
        systemImage: String,
        tint: Color,
        isOn: Binding<Bool>,
        disabled: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.body)
                    .foregroundColor(disabled ? .secondary : .primary)

                Spacer(minLength: 12)

                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(disabled)
            }

            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .opacity(disabled ? 0.75 : 1)
    }

    private func normalizeMenuPreferencesIfNeeded() {
        let normalizedTitleLength = CMNormalizedLegacyMenuTitleLength(maxTitleLength)
        if maxTitleLength != normalizedTitleLength {
            maxTitleLength = normalizedTitleLength
        }
        let normalizedInlineItems = CMNormalizedLegacyMenuInlineItemsCount(inlineItems)
        if inlineItems != normalizedInlineItems {
            inlineItems = normalizedInlineItems
        }
        let normalizedFolderItems = CMNormalizedLegacyMenuFolderItemsCount(folderItems)
        if folderItems != normalizedFolderItems {
            folderItems = normalizedFolderItems
        }
        let normalizedTooltipLength = CMNormalizedLegacyMenuTooltipLength(maxTooltipLength)
        if maxTooltipLength != normalizedTooltipLength {
            maxTooltipLength = normalizedTooltipLength
        }
        let normalizedMode = CMNormalizedMenuLegacyFontSizingMode(howToChangeFontSize)
        if howToChangeFontSize != normalizedMode {
            howToChangeFontSize = normalizedMode
        }
        let normalized = CMNormalizedMenuLegacyFontSize(selectedFontSize)
        if selectedFontSize != normalized {
            selectedFontSize = normalized
        }
    }
}

private struct IconPreferencesViewContent: View {
    @AppStorage(CMPrefShowImageInTheMenuKey) private var showImages = true
    @AppStorage(CMPrefThumbnailWidthKey) private var thumbnailWidth = 100
    @AppStorage(CMPrefThumbnailHeightKey) private var thumbnailHeight = 32
    @AppStorage(CMPrefShowIconInTheMenuKey) private var showIcons = true
    @AppStorage(CMPrefMenuIconSizeKey) private var menuIconSize = 16

    private let legacyShowImageLabel = NSLocalizedString("737.title", tableName: "Preferences", bundle: .main, value: "Show Image", comment: "")
    private let legacyThumbnailWidthLabel = NSLocalizedString("707.title", tableName: "Preferences", bundle: .main, value: "Width:", comment: "")
    private let legacyThumbnailHeightLabel = NSLocalizedString("708.title", tableName: "Preferences", bundle: .main, value: "Height:", comment: "")
    private let legacyThumbnailPixelLabel = NSLocalizedString("711.title", tableName: "Preferences", bundle: .main, value: "pixel", comment: "")
    private let legacyShowIconLabel = NSLocalizedString("934.title", tableName: "Preferences", bundle: .main, value: "Show Icon in the Menu", comment: "")
    private let legacyIconSizeLabel = NSLocalizedString("933.title", tableName: "Preferences", bundle: .main, value: "Icon size:", comment: "")
    private static let menuIconSizeOptions = CMTypeLegacyMenuIconSizeOptions()

    var body: some View {
        PreferenceSection(NSLocalizedString("Images", comment: "")) {
            imageInlinePreviewStrip
            PreferenceToggle(title: legacyShowImageLabel, isOn: $showImages)
            PreferenceStepper(
                legacyThumbnailWidthLabel,
                value: normalizedThumbnailWidthBinding,
                in: 1...Int.max,
                suffix: legacyThumbnailPixelLabel
            )
            .disabled(!showImages)
            PreferenceStepper(
                legacyThumbnailHeightLabel,
                value: normalizedThumbnailHeightBinding,
                in: 1...Int.max,
                suffix: legacyThumbnailPixelLabel
            )
            .disabled(!showImages)
        }
        PreferenceSection(NSLocalizedString("Icons", comment: "")) {
            iconInlinePreviewStrip
            PreferenceToggle(title: legacyShowIconLabel, isOn: $showIcons)
            PreferenceRow(legacyIconSizeLabel) {
                HStack(spacing: 10) {
                    PreferencePicker(selection: normalizedMenuIconSizeBinding, width: 120) {
                        ForEach(Self.menuIconSizeOptions, id: \.self) { option in
                            Text(String(option)).tag(option)
                        }
                    }
                    Text(legacyThumbnailPixelLabel)
                        .foregroundColor(.secondary)
                }
                .disabled(!showIcons)
            }
        }
        PreferenceSection(NSLocalizedString("File Type Icons", comment: "")) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(MenuIconTypeOption.all) { option in
                    MenuIconTypeRow(option: option)
                }
            }
        }
        .disabled(!showIcons)
        .onAppear(perform: normalizeTypeIconPreferencesIfNeeded)
    }

    private var imageInlinePreviewStrip: some View {
        HStack(alignment: .center, spacing: 14) {
            previewCanvas {
                let previewSize = scaledThumbnailPreviewSize
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(showImages ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08))
                    .frame(width: previewSize.width, height: previewSize.height)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(showImages ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.24), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: showImages ? "photo" : "eye.slash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(showImages ? .accentColor : .secondary)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(CMTypeThumbnailSummaryTitle(width: normalizedThumbnailWidth, height: normalizedThumbnailHeight))
                    .font(.subheadline.weight(.semibold))
                Text(
                    CMTypeThumbnailDimensionBadgeTitles(
                        width: normalizedThumbnailWidth,
                        height: normalizedThumbnailHeight,
                        pixelLabel: CMModernPixelUnitTitle()
                    ).joined(separator: " • ")
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var iconInlinePreviewStrip: some View {
        HStack(alignment: .center, spacing: 14) {
            previewCanvas {
                Image(systemName: showIcons ? "doc.on.doc.fill" : "eye.slash")
                    .font(.system(size: scaledMenuIconPreviewSize, weight: .semibold))
                    .foregroundColor(showIcons ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("Current Icon Size", comment: ""))
                    .font(.subheadline.weight(.semibold))
                Text(
                    [
                        CMTypeIconSizeBadgeTitle(size: normalizedMenuIconSize, pixelLabel: CMModernPixelUnitTitle()),
                        showIcons ? NSLocalizedString("Icons On", comment: "") : NSLocalizedString("Icons Off", comment: "")
                    ].joined(separator: " • ")
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private func previewCanvas<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            content()
        }
        .frame(width: 112, height: 72)
    }

    private var normalizedMenuIconSize: Int {
        CMNormalizedTypeLegacyMenuIconSize(menuIconSize)
    }

    private var normalizedThumbnailWidth: Int {
        CMNormalizedLegacyThumbnailDimension(thumbnailWidth)
    }

    private var normalizedThumbnailHeight: Int {
        CMNormalizedLegacyThumbnailDimension(thumbnailHeight)
    }

    private var normalizedThumbnailWidthBinding: Binding<Int> {
        Binding(
            get: { normalizedThumbnailWidth },
            set: { thumbnailWidth = CMNormalizedLegacyThumbnailDimension($0) }
        )
    }

    private var normalizedThumbnailHeightBinding: Binding<Int> {
        Binding(
            get: { normalizedThumbnailHeight },
            set: { thumbnailHeight = CMNormalizedLegacyThumbnailDimension($0) }
        )
    }

    private var normalizedMenuIconSizeBinding: Binding<Int> {
        Binding(
            get: { normalizedMenuIconSize },
            set: { menuIconSize = CMNormalizedTypeLegacyMenuIconSize($0) }
        )
    }

    private var scaledThumbnailPreviewSize: CGSize {
        let width = CGFloat(max(normalizedThumbnailWidth, 1))
        let height = CGFloat(max(normalizedThumbnailHeight, 1))
        let maxWidth: CGFloat = 80
        let maxHeight: CGFloat = 40
        let scale = min(maxWidth / width, maxHeight / height, 1)
        return CGSize(width: max(width * scale, 24), height: max(height * scale, 18))
    }

    private var scaledMenuIconPreviewSize: CGFloat {
        min(max(CGFloat(normalizedMenuIconSize), 12), 32)
    }

    private func normalizeTypeIconPreferencesIfNeeded() {
        let normalizedWidth = CMNormalizedLegacyThumbnailDimension(thumbnailWidth)
        if normalizedWidth != thumbnailWidth {
            thumbnailWidth = normalizedWidth
        }

        let normalizedHeight = CMNormalizedLegacyThumbnailDimension(thumbnailHeight)
        if normalizedHeight != thumbnailHeight {
            thumbnailHeight = normalizedHeight
        }

        let normalizedMenuIconSize = CMNormalizedTypeLegacyMenuIconSize(menuIconSize)
        if normalizedMenuIconSize != menuIconSize {
            menuIconSize = normalizedMenuIconSize
        }

        for option in MenuIconTypeOption.all {
            let storedTag = UserDefaults.standard.object(forKey: option.tagKey) as? Int ?? option.defaultSelectionTag
            let normalizedTag = CMNormalizedTypeFileIconSelectionTag(storedTag)
            if normalizedTag != storedTag {
                UserDefaults.standard.set(normalizedTag, forKey: option.tagKey)
            }
        }
    }
}

private enum MenuIconMappingSection: String, CaseIterable, Identifiable {
    case textAndDocuments
    case filesAndLinks
    case images

    var id: String { rawValue }

    var title: String {
        switch self {
        case .textAndDocuments:
            return NSLocalizedString("Text and Documents", comment: "")
        case .filesAndLinks:
            return NSLocalizedString("Files and Links", comment: "")
        case .images:
            return NSLocalizedString("Images", comment: "")
        }
    }

    var detail: String {
        switch self {
        case .textAndDocuments:
            return NSLocalizedString("Control the icons used for text-rich and document-style clipboard content.", comment: "")
        case .filesAndLinks:
            return NSLocalizedString("Choose how file lists and URLs identify themselves in the menu.", comment: "")
        case .images:
            return NSLocalizedString("Set fallback icon rules for image clip types when thumbnails are not used.", comment: "")
        }
    }

    var options: [MenuIconTypeOption] {
        switch self {
        case .textAndDocuments:
            return MenuIconTypeOption.all.filter { ["String", "RTF", "RTFD", "PDF"].contains($0.id) }
        case .filesAndLinks:
            return MenuIconTypeOption.all.filter { ["Filenames", "URL"].contains($0.id) }
        case .images:
            return MenuIconTypeOption.all.filter { ["TIFF", "PICT"].contains($0.id) }
        }
    }
}

private struct MenuIconTypeOption: Identifiable {
    let id: String
    let title: String
    let tagKey: String
    let fileTypeKey: String
    let defaultSelectionTag: Int
    let defaultFileType: String

    static let all = [
        MenuIconTypeOption(
            id: "String",
            title: NSLocalizedString("959.title", tableName: "Preferences", bundle: .main, value: "Plain Text:", comment: ""),
            tagKey: CMPrefMenuIconOfFileTypeTagForStringKey,
            fileTypeKey: CMPrefMenuIconOfFileTypeForStringKey,
            defaultSelectionTag: 1,
            defaultFileType: "TEXT"
        ),
        MenuIconTypeOption(
            id: "RTF",
            title: NSLocalizedString("965.title", tableName: "Preferences", bundle: .main, value: "RTF:", comment: ""),
            tagKey: CMPrefMenuIconOfFileTypeTagForRTFKey,
            fileTypeKey: CMPrefMenuIconOfFileTypeForRTFKey,
            defaultSelectionTag: 0,
            defaultFileType: "rtf"
        ),
        MenuIconTypeOption(
            id: "RTFD",
            title: NSLocalizedString("971.title", tableName: "Preferences", bundle: .main, value: "RTFD:", comment: ""),
            tagKey: CMPrefMenuIconOfFileTypeTagForRTFDKey,
            fileTypeKey: CMPrefMenuIconOfFileTypeForRTFDKey,
            defaultSelectionTag: 0,
            defaultFileType: "rtfd"
        ),
        MenuIconTypeOption(
            id: "PDF",
            title: NSLocalizedString("977.title", tableName: "Preferences", bundle: .main, value: "PDF:", comment: ""),
            tagKey: CMPrefMenuIconOfFileTypeTagForPDFKey,
            fileTypeKey: CMPrefMenuIconOfFileTypeForPDFKey,
            defaultSelectionTag: 0,
            defaultFileType: "pdf"
        ),
        MenuIconTypeOption(
            id: "Filenames",
            title: NSLocalizedString("983.title", tableName: "Preferences", bundle: .main, value: "Filenames:", comment: ""),
            tagKey: CMPrefMenuIconOfFileTypeTagForFilenamesKey,
            fileTypeKey: CMPrefMenuIconOfFileTypeForFilenamesKey,
            defaultSelectionTag: 1,
            defaultFileType: "clpu"
        ),
        MenuIconTypeOption(
            id: "URL",
            title: NSLocalizedString("989.title", tableName: "Preferences", bundle: .main, value: "URL:", comment: ""),
            tagKey: CMPrefMenuIconOfFileTypeTagForURLKey,
            fileTypeKey: CMPrefMenuIconOfFileTypeForURLKey,
            defaultSelectionTag: 1,
            defaultFileType: "gurl"
        ),
        MenuIconTypeOption(
            id: "TIFF",
            title: NSLocalizedString("995.title", tableName: "Preferences", bundle: .main, value: "TIFF:", comment: ""),
            tagKey: CMPrefMenuIconOfFileTypeTagForTIFFKey,
            fileTypeKey: CMPrefMenuIconOfFileTypeForTIFFKey,
            defaultSelectionTag: 0,
            defaultFileType: "tiff"
        ),
        MenuIconTypeOption(
            id: "PICT",
            title: NSLocalizedString("1001.title", tableName: "Preferences", bundle: .main, value: "PICT:", comment: ""),
            tagKey: CMPrefMenuIconOfFileTypeTagForPICTKey,
            fileTypeKey: CMPrefMenuIconOfFileTypeForPICTKey,
            defaultSelectionTag: 0,
            defaultFileType: "pict"
        )
    ]
}

private func CMNormalizedMenuIconTypePreference(
    option: MenuIconTypeOption,
    defaults: UserDefaults = .standard
) -> (selectionTag: Int, fileType: String) {
    let selectionTag = CMNormalizedTypeFileIconSelectionTag(
        defaults.object(forKey: option.tagKey) as? Int ?? option.defaultSelectionTag
    )
    let fileType = CMNormalizedMenuIconFileTypeValue(
        defaults.string(forKey: option.fileTypeKey),
        defaultValue: option.defaultFileType,
        selectionTag: selectionTag
    )
    return (selectionTag, fileType)
}

private struct MenuIconTypeRow: View {
    let option: MenuIconTypeOption
    @State private var selectionTag: Int
    @State private var fileType: String

    init(option: MenuIconTypeOption) {
        self.option = option
        let defaults = UserDefaults.standard
        let preference = CMNormalizedMenuIconTypePreference(option: option, defaults: defaults)
        _selectionTag = State(
            initialValue: preference.selectionTag
        )
        _fileType = State(initialValue: preference.fileType)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(option.title)
                .font(.body)
                .frame(width: 120, alignment: .trailing)

            Picker("", selection: $selectionTag) {
                Text(NSLocalizedString("963.title", tableName: "Preferences", bundle: .main, value: "File extension", comment: "")).tag(0)
                Text(NSLocalizedString("962.title", tableName: "Preferences", bundle: .main, value: "File type code", comment: "")).tag(1)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 160, alignment: .leading)

            TextField("", text: $fileType)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .frame(width: 128)

            Button(NSLocalizedString("Reset", comment: "")) {
                resetToDefaults()
            }
            .controlSize(.small)
            .disabled(isDefaultMapping)

            Spacer(minLength: 0)
        }
        .onChange(of: selectionTag) { _ in save() }
        .onChange(of: fileType) { _ in save() }
        .onAppear(perform: normalizeStoredStateIfNeeded)
    }

    private var isDefaultMapping: Bool {
        normalizedSelectionTag == option.defaultSelectionTag && normalizedFileType == option.defaultFileType
    }

    private func resetToDefaults() {
        selectionTag = option.defaultSelectionTag
        fileType = option.defaultFileType
        save()
    }

    private func save() {
        let normalizedFileType = self.normalizedFileType
        if normalizedFileType != fileType {
            fileType = normalizedFileType
        }
        UserDefaults.standard.set(normalizedSelectionTag, forKey: option.tagKey)
        UserDefaults.standard.set(normalizedFileType, forKey: option.fileTypeKey)
    }

    private var normalizedSelectionTag: Int {
        CMNormalizedTypeFileIconSelectionTag(selectionTag)
    }

    private var normalizedFileType: String {
        CMNormalizedMenuIconFileTypeValue(fileType, defaultValue: option.defaultFileType)
    }

    private func normalizeStoredStateIfNeeded() {
        let normalized = normalizedSelectionTag
        if normalized != selectionTag {
            selectionTag = normalized
        }
        let normalizedFileType = self.normalizedFileType
        if normalizedFileType != fileType {
            fileType = normalizedFileType
        }
    }
}

private let CMActionNodeTitleKey = "nodeTitle"
private let CMActionNodeIsLeafKey = "isLeaf"
private let CMActionNodeChildrenKey = "children"
private let CMActionNodeActionKey = "action"
private let CMActionTypeKey = "type"
private let CMBuiltinActionType = "builtin"
private let CMJavaScriptActionType = "js"

private enum ReservedActionKind: Int, CaseIterable, Identifiable {
    case builtin
    case bundled
    case user

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .builtin:
            return CMActionBuiltInSourceLabel()
        case .bundled:
            return CMActionBundledSourceLabel()
        case .user:
            return CMActionUserSourceLabel()
        }
    }
}

private struct ActionNode: Identifiable, Codable, Equatable {
    var id = UUID()
    var nodeTitle: String
    var action: [String: String]?
    var children: [ActionNode]

    var isLeaf: Bool { action != nil }

    private enum CodingKeys: String, CodingKey {
        case nodeTitle
        case isLeaf
        case children
        case action
    }

    init(nodeTitle: String, action: [String: String]? = nil, children: [ActionNode] = []) {
        self.nodeTitle = nodeTitle
        self.action = action
        self.children = children
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodeTitle = try container.decode(String.self, forKey: .nodeTitle)
        if let decodedAction = try container.decodeIfPresent([String: LossyActionString].self, forKey: .action) {
            action = normalizedActionDictionary(decodedAction.mapValues { $0.value })
        } else {
            action = nil
        }
        children = try container.decodeIfPresent([ActionNode].self, forKey: .children) ?? []

        let decodedIsLeaf = try container.decodeIfPresent(Bool.self, forKey: .isLeaf) ?? (action != nil)
        if !decodedIsLeaf {
            action = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodeTitle, forKey: .nodeTitle)
        try container.encode(isLeaf, forKey: .isLeaf)
        if !isLeaf {
            try container.encode(children, forKey: .children)
        }
        if let action {
            try container.encode(action, forKey: .action)
        }
    }

    func copyWithNewIDs() -> ActionNode {
        ActionNode(
            nodeTitle: nodeTitle,
            action: action,
            children: children.map { $0.copyWithNewIDs() }
        )
    }
}

private struct ActionNodeDragPayload: Codable {
    var actionNode: ActionNode?
    var sourceNodeID: UUID?
}

private enum ActionInspectorPane: String {
    case reserved
    case action
}

private struct ActionInspectorSnapshot {
    let pane: ActionInspectorPane
    let node: ActionNode
}

private final class ActionInspectorState: ObservableObject {
    static let shared = ActionInspectorState()

    @Published var activePane: ActionInspectorPane = .action

    func currentSnapshot(store: ActionFileStore = .shared) -> ActionInspectorSnapshot? {
        switch activePane {
        case .reserved:
            guard let node = store.currentReservedInspectorNode() else { return nil }
            return ActionInspectorSnapshot(pane: .reserved, node: node)
        case .action:
            guard let node = store.currentActionInspectorNode() else { return nil }
            return ActionInspectorSnapshot(pane: .action, node: node)
        }
    }
}

final class ActionTreePresentationState: ObservableObject {
    static let shared = ActionTreePresentationState()

    @Published var expandedReservedNodeIDs: Set<UUID> = []
    @Published var expandedActionNodeIDs: Set<UUID> = []
    private var reservedExpandedPathsByKind: [Int: [String]] = [:]

    func resetForTesting() {
        expandedReservedNodeIDs = []
        expandedActionNodeIDs = []
        reservedExpandedPathsByKind = [:]
    }

    fileprivate func snapshotReservedExpansion(for kind: ReservedActionKind, store: ActionFileStore = .shared) {
        reservedExpandedPathsByKind[kind.rawValue] = store.currentExpandedReservedNodePaths(
            ids: expandedReservedNodeIDs,
            kind: kind
        )
    }

    fileprivate func restoreReservedExpansion(for kind: ReservedActionKind, store: ActionFileStore = .shared) {
        let paths = reservedExpandedPathsByKind[kind.rawValue] ?? []
        expandedReservedNodeIDs = store.reservedNodeIDs(forPaths: paths)
    }
}

private func actionAncestorFolderIDs(for targetID: UUID, in nodes: [ActionNode]) -> [UUID]? {
    for node in nodes {
        if node.id == targetID {
            return node.isLeaf ? [] : [node.id]
        }
        if let descendants = actionAncestorFolderIDs(for: targetID, in: node.children) {
            return node.isLeaf ? descendants : [node.id] + descendants
        }
    }
    return nil
}

private struct ActionDropDestination {
    var parentID: UUID?
    var insertionIndex: Int?
}

private struct LossyActionString: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let integer = try? container.decode(Int.self) {
            value = String(integer)
        } else if let bool = try? container.decode(Bool.self) {
            value = bool ? "1" : "0"
        } else if let double = try? container.decode(Double.self) {
            value = String(double)
        } else {
            value = ""
        }
    }
}

private func actionDictionary(from object: Any?) -> [String: String]? {
    if let action = object as? [String: String] {
        return normalizedActionDictionary(action)
    }
    guard let dictionary = object as? NSDictionary else { return nil }

    var result: [String: String] = [:]
    for (key, value) in dictionary {
        guard let key = key as? String else { continue }
        if let value = value as? String {
            result[key] = value
        } else if let value = value as? NSNumber {
            result[key] = value.stringValue
        } else {
            result[key] = "\(value)"
        }
    }
    return result.isEmpty ? nil : normalizedActionDictionary(result)
}

private func normalizedActionDictionary(_ action: [String: String]) -> [String: String] {
    var normalized = action
    if normalized["name"] == "removeAction" {
        normalized["name"] = "remove:"
    }
    if normalized[CMActionTypeKey] == nil {
        if let path = normalized["path"], !path.isEmpty {
            normalized[CMActionTypeKey] = CMJavaScriptActionType
        } else if normalized["name"]?.isEmpty == false {
            normalized[CMActionTypeKey] = CMBuiltinActionType
        }
    }
    return normalized
}

private func CMActionNameCanEndEditing(_ value: String) -> Bool {
    !value.isEmpty
}

private func CMSnippetItemNameCanEndEditing(_ value: String) -> Bool {
    !value.isEmpty
}

private func CMBuiltinActionInspectorTitle(for action: [String: String]) -> String {
    switch action["name"] {
    case "pasteAsPlainText:":
        return NSLocalizedString("Paste as Plain Text", comment: "")
    case "pasteAsFilePath:":
        return NSLocalizedString("Paste as File Path", comment: "")
    case "pasteAsHFSFilePath:":
        return NSLocalizedString("Paste as HFS File Path", comment: "")
    case "removeAction", "removeAction:", "remove:":
        return NSLocalizedString("Remove", comment: "")
    default:
        return action["name"] ?? CMActionBuiltInSourceLabel()
    }
}

private func CMDefaultEnglishBuiltinActionTitle(for actionName: String) -> String? {
    switch actionName {
    case "pasteAsPlainText:":
        return "Paste as Plain Text"
    case "pasteAsFilePath:":
        return "Paste as File Path"
    case "pasteAsHFSFilePath:":
        return "Paste as HFS File Path"
    case "removeAction", "removeAction:", "remove:":
        return "Remove"
    default:
        return nil
    }
}

private func CMLocalizedBuiltinActionTitleIfDefault(_ node: ActionNode) -> String? {
    guard let action = node.action,
          action[CMActionTypeKey] == CMBuiltinActionType else {
        return nil
    }

    let localizedTitle = CMBuiltinActionInspectorTitle(for: action)
    guard let actionName = action["name"],
          let englishTitle = CMDefaultEnglishBuiltinActionTitle(for: actionName) else {
        return nil
    }

    if node.nodeTitle == englishTitle || node.nodeTitle == localizedTitle {
        return localizedTitle
    }

    return nil
}

private func CMLocalizeDefaultBuiltinActionTitles(in nodes: [ActionNode]) -> [ActionNode] {
    nodes.map { node in
        var localizedNode = node
        if let localizedTitle = CMLocalizedBuiltinActionTitleIfDefault(node) {
            localizedNode.nodeTitle = localizedTitle
        }
        if !node.children.isEmpty {
            localizedNode.children = CMLocalizeDefaultBuiltinActionTitles(in: node.children)
        }
        return localizedNode
    }
}

private func CMActionInspectorTypeTitle(for node: ActionNode) -> String {
    if !node.isLeaf {
        return NSLocalizedString("747.title", tableName: "Preferences", bundle: .main, value: "Folder", comment: "")
    }

    switch node.action?[CMActionTypeKey] {
    case CMBuiltinActionType:
        return CMActionBuiltInSourceLabel()
    case CMJavaScriptActionType:
        let scriptURL = URL(fileURLWithPath: node.action?["path"] ?? "")
        return CMIsUserScriptURL(scriptURL) ? CMActionUserSourceLabel() : CMActionBundledSourceLabel()
    default:
        return NSLocalizedString("Action", comment: "")
    }
}

private func CMActionInspectorPath(for node: ActionNode) -> String? {
    guard node.action?[CMActionTypeKey] == CMJavaScriptActionType,
          let path = node.action?["path"],
          !path.isEmpty else {
        return nil
    }
    return path
}

private func CMActionNodeRowSubtitle(for node: ActionNode) -> String {
    if !node.isLeaf {
        let count = node.children.count
        let unit = NSLocalizedString("1171.title", tableName: "Preferences", bundle: .main, value: "items", comment: "")
        return "\(count) \(unit)"
    }

    let action = node.action ?? [:]
    if action[CMActionTypeKey] == CMJavaScriptActionType {
        let scriptURL = URL(fileURLWithPath: action["path"] ?? "")
        if CMIsUserScriptURL(scriptURL) {
            return NSLocalizedString("User JavaScript action", comment: "")
        }
        if !scriptURL.lastPathComponent.isEmpty {
            return scriptURL.lastPathComponent
        }
        return NSLocalizedString("Bundled JavaScript action", comment: "")
    }

    return CMBuiltinActionInspectorTitle(for: action)
}

private func CMActionNodeRowBadgeTitle(for node: ActionNode) -> String? {
    if !node.isLeaf {
        return NSLocalizedString("747.title", tableName: "Preferences", bundle: .main, value: "Folder", comment: "")
    }

    let action = node.action ?? [:]
    if action[CMActionTypeKey] == CMJavaScriptActionType {
        let scriptURL = URL(fileURLWithPath: action["path"] ?? "")
        if CMIsUserScriptURL(scriptURL) {
            return CMActionUserSourceLabel()
        }
        return CMActionBundledSourceLabel()
    }

    return CMActionBuiltInSourceLabel()
}

private func CMIsUserScriptURL(_ url: URL) -> Bool {
    guard !url.path.isEmpty else { return false }
    let userPath = clipMenuApplicationSupportDirectory()
        .appendingPathComponent("script", isDirectory: true)
        .appendingPathComponent("action", isDirectory: true)
        .resolvingSymlinksInPath()
        .standardizedFileURL
        .path
    let candidatePath = url
        .resolvingSymlinksInPath()
        .standardizedFileURL
        .path
    return candidatePath.hasPrefix(userPath)
}

func CMUpdatePreferencesAvailabilityReport(
    automaticChecks: Bool,
    feedURLPresent: Bool,
    isChecking: Bool
) -> [String: Bool] {
    [
        "preReleasesEnabled": automaticChecks,
        "automaticallyInstallUpdatesEnabled": automaticChecks,
        "intervalEnabled": automaticChecks,
        "checkNowEnabled": automaticChecks && feedURLPresent && !isChecking
    ]
}

@objc(CMLegacyArchivedActionNode)
private final class LegacyArchivedActionNode: NSObject, NSCoding {
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
        action = actionDictionary(from: coder.decodeObject(forKey: CMActionNodeActionKey))
        super.init()
    }

    func encode(with coder: NSCoder) {}

    func actionNode() -> ActionNode {
        if isLeaf {
            return ActionNode(nodeTitle: nodeTitle, action: action)
        }

        return ActionNode(
            nodeTitle: nodeTitle,
            children: children
                .filter { $0 !== self }
                .map { $0.actionNode() }
        )
    }
}

private final class ActionFileStore: ObservableObject {
    static let shared = ActionFileStore()

    @Published var actionNodes: [ActionNode] = []
    @Published var builtinNodes: [ActionNode] = []
    @Published var bundledNodes: [ActionNode] = []
    @Published var usersNodes: [ActionNode] = []
    @Published var selectedActionNodeID: UUID?
    @Published var selectedReservedNodeID: UUID?
    @Published var reservedKind: ReservedActionKind = .builtin {
        didSet {
            ActionTreePresentationState.shared.snapshotReservedExpansion(for: oldValue, store: self)
            selectedReservedNodeID = reservedNodes.first?.id
            ActionTreePresentationState.shared.restoreReservedExpansion(for: reservedKind, store: self)
        }
    }
    @Published private(set) var hasPendingChanges = false
    private var committedActionNodes: [ActionNode] = []

    private var supportDirectory: URL {
        clipMenuApplicationSupportDirectory()
    }

    private var fileURL: URL {
        supportDirectory.appendingPathComponent("actions.plist")
    }

    private var legacyFileURL: URL {
        supportDirectory.appendingPathComponent("actionMenu.data")
    }

    private var bundledActionsURL: URL? {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("script/action", isDirectory: true),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        let developmentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("resource/script/action", isDirectory: true)
        if FileManager.default.fileExists(atPath: developmentURL.path) {
            return developmentURL
        }

        return nil
    }

    private var userActionsURL: URL {
        supportDirectory
            .appendingPathComponent("script", isDirectory: true)
            .appendingPathComponent("action", isDirectory: true)
    }

    var reservedNodes: [ActionNode] {
        switch reservedKind {
        case .builtin:
            return builtinNodes
        case .bundled:
            return bundledNodes
        case .user:
            return usersNodes
        }
    }

    func reservedNodes(for kind: ReservedActionKind) -> [ActionNode] {
        switch kind {
        case .builtin:
            return builtinNodes
        case .bundled:
            return bundledNodes
        case .user:
            return usersNodes
        }
    }

    init() {
        reload()
    }

    func reload() {
        prepareReservedActions()
        loadActionMenu()
        hasPendingChanges = false
    }

    func save() {
        commitPendingChanges()
        saveCommittedNodes()
    }

    func commitPendingChanges() {
        committedActionNodes = actionNodes
        hasPendingChanges = false
    }

    func committedNodesData() -> Data? {
        try? PropertyListEncoder().encode(committedActionNodes)
    }

    private func saveCommittedNodes() {
        do {
            let data = try PropertyListEncoder().encode(committedActionNodes)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            showActionSaveAlert(error)
        }
    }

    private func markPendingChanges() {
        hasPendingChanges = true
    }

    func addSelectedReservedNode() {
        guard let selected = findNode(with: selectedReservedNodeID, in: reservedNodes) else { return }
        let copy = selected.copyWithNewIDs()
        actionNodes.append(copy)
        selectedActionNodeID = copy.id
        markPendingChanges()
    }

    @discardableResult
    func addUserReservedAction(path: String) -> Bool {
        guard let selected = findUserReservedNode(path: path) else { return false }
        let copy = selected.copyWithNewIDs()
        actionNodes.append(copy)
        selectedActionNodeID = copy.id
        markPendingChanges()
        return true
    }

    func userReservedActionTitles() -> [String] {
        flattenedNodePaths(in: usersNodes)
    }

    func bundledReservedActionTitles() -> [String] {
        flattenedNodePaths(in: bundledNodes)
    }

    func addTestBuiltinAction() {
        let node = builtinAction(title: "Test Remove", name: "remove:")
        actionNodes.append(node)
        selectedActionNodeID = node.id
        markPendingChanges()
    }

    func addFolder() {
        let folder = ActionNode(nodeTitle: NSLocalizedString("untitled folder", comment: ""), children: [])
        if let selectedID = selectedActionNodeID,
           appendActionNode(folder, toFolder: selectedID, in: &actionNodes) {
            selectedActionNodeID = folder.id
        } else {
            actionNodes.append(folder)
            selectedActionNodeID = folder.id
        }
        markPendingChanges()
    }

    func actionDragProvider(for node: ActionNode) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.clipMenuActionNodeDrag.identifier,
            visibility: .ownProcess
        ) { completion in
            let payload = ActionNodeDragPayload(actionNode: node.copyWithNewIDs(), sourceNodeID: nil)
            let data = try? PropertyListEncoder().encode(payload)
            completion(data, nil)
            return nil
        }
        return provider
    }

    func actionMoveDragProvider(for node: ActionNode) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.clipMenuActionNodeDrag.identifier,
            visibility: .ownProcess
        ) { completion in
            let payload = ActionNodeDragPayload(actionNode: nil, sourceNodeID: node.id)
            let data = try? PropertyListEncoder().encode(payload)
            completion(data, nil)
            return nil
        }
        return provider
    }

    func acceptActionNodeDrop(_ providers: [NSItemProvider], destination: ActionDropDestination) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.clipMenuActionNodeDrag.identifier)
        }) else {
            return false
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.clipMenuActionNodeDrag.identifier) { [weak self] data, _ in
            guard let data,
                  let payload = try? PropertyListDecoder().decode(ActionNodeDragPayload.self, from: data) else {
                return
            }
            DispatchQueue.main.async {
                if let sourceNodeID = payload.sourceNodeID {
                    self?.moveActionNode(sourceNodeID, to: destination)
                    return
                }

                guard let node = payload.actionNode else { return }
                let copy = node.copyWithNewIDs()
                if self?.insertActionNode(copy, at: destination) == true {
                    self?.selectedActionNodeID = copy.id
                    self?.markPendingChanges()
                }
            }
        }
        return true
    }

    func removeSelectedActionNode() {
        guard let id = selectedActionNodeID else { return }
        let fallbackSelectionID = selectionAfterRemovingNode(with: id, in: actionNodes)
        _ = removeNode(with: id, from: &actionNodes)
        if let fallbackSelectionID,
           findNode(with: fallbackSelectionID, in: actionNodes) != nil {
            selectedActionNodeID = fallbackSelectionID
        } else {
            selectedActionNodeID = actionNodes.first?.id
        }
        markPendingChanges()
    }

    func moveSelectedActionNodeUp() {
        guard let id = selectedActionNodeID else { return }
        if moveNode(with: id, in: &actionNodes, offset: -1) {
            markPendingChanges()
        }
    }

    func moveSelectedActionNodeDown() {
        guard let id = selectedActionNodeID else { return }
        if moveNode(with: id, in: &actionNodes, offset: 1) {
            markPendingChanges()
        }
    }

    func canMoveSelectedActionNodeUp() -> Bool {
        canMoveNode(with: selectedActionNodeID, in: actionNodes, offset: -1)
    }

    func canMoveSelectedActionNodeDown() -> Bool {
        canMoveNode(with: selectedActionNodeID, in: actionNodes, offset: 1)
    }

    func binding(for id: UUID) -> Binding<String> {
        Binding(
            get: { self.findNode(with: id, in: self.actionNodes)?.nodeTitle ?? "" },
            set: { newValue in
                self.updateTitle(for: id, in: &self.actionNodes, title: newValue)
                self.markPendingChanges()
            }
        )
    }

    @discardableResult
    func selectActionNode(path: String) -> Bool {
        let normalizedPath = path
            .split(separator: "/")
            .map(String.init)
        guard let node = findNode(in: actionNodes, pathComponents: normalizedPath) else {
            return false
        }
        selectedActionNodeID = node.id
        return true
    }

    func currentSelectedActionNodePath() -> String? {
        selectedPath(for: selectedActionNodeID, in: actionNodes)?.joined(separator: "/")
    }

    @discardableResult
    func selectReservedNode(path: String) -> Bool {
        let normalizedPath = path
            .split(separator: "/")
            .map(String.init)
        guard let node = findNode(in: reservedNodes, pathComponents: normalizedPath) else {
            return false
        }
        selectedReservedNodeID = node.id
        if let ancestorIDs = actionAncestorFolderIDs(for: node.id, in: reservedNodes) {
            ActionTreePresentationState.shared.expandedReservedNodeIDs.formUnion(ancestorIDs)
        }
        return true
    }

    func currentActionNodePaths() -> [String] {
        flattenedNodePaths(in: actionNodes)
    }

    func actionNodeID(path: String) -> UUID? {
        let normalizedPath = path
            .split(separator: "/")
            .map(String.init)
        return findNode(in: actionNodes, pathComponents: normalizedPath)?.id
    }

    func actionNodeIDs(forPaths paths: [String]) -> Set<UUID> {
        Set(paths.compactMap(actionNodeID(path:)))
    }

    func reservedNodeID(path: String) -> UUID? {
        let normalizedPath = path
            .split(separator: "/")
            .map(String.init)
        return findNode(in: reservedNodes, pathComponents: normalizedPath)?.id
    }

    func reservedNodeIDs(forPaths paths: [String]) -> Set<UUID> {
        Set(paths.compactMap(reservedNodeID(path:)))
    }

    func currentExpandedActionNodePaths(ids: Set<UUID>) -> [String] {
        expandedNodePaths(in: actionNodes, expandedIDs: ids)
    }

    func currentExpandedReservedNodePaths(ids: Set<UUID>, kind: ReservedActionKind? = nil) -> [String] {
        let nodes = kind.map(reservedNodes(for:)) ?? reservedNodes
        return expandedNodePaths(in: nodes, expandedIDs: ids)
    }

    func currentActionInspectorNode() -> ActionNode? {
        findNode(with: selectedActionNodeID, in: actionNodes)
    }

    func currentReservedInspectorNode() -> ActionNode? {
        findNode(with: selectedReservedNodeID, in: reservedNodes)
    }

    @discardableResult
    func moveActionNodeForTesting(sourcePath: String, destinationParentPath: String?, insertionIndex: Int?) -> Bool {
        let sourceComponents = sourcePath.split(separator: "/").map(String.init)
        guard let sourceNode = findNode(in: actionNodes, pathComponents: sourceComponents) else {
            return false
        }

        let parentID: UUID?
        if let destinationParentPath {
            let destinationComponents = destinationParentPath.split(separator: "/").map(String.init)
            guard let parentNode = findNode(in: actionNodes, pathComponents: destinationComponents) else {
                return false
            }
            parentID = parentNode.id
        } else {
            parentID = nil
        }

        moveActionNode(
            sourceNode.id,
            to: ActionDropDestination(parentID: parentID, insertionIndex: insertionIndex)
        )
        return true
    }

    @discardableResult
    func insertReservedActionForTesting(reservedPath: String, destinationParentPath: String?, insertionIndex: Int?) -> Bool {
        let reservedComponents = reservedPath.split(separator: "/").map(String.init)
        guard let reservedNode = findNode(in: reservedNodes, pathComponents: reservedComponents) else {
            return false
        }

        let copy = reservedNode.copyWithNewIDs()
        let parentID: UUID?
        if let destinationParentPath {
            let destinationComponents = destinationParentPath.split(separator: "/").map(String.init)
            guard let parentNode = findNode(in: actionNodes, pathComponents: destinationComponents) else {
                return false
            }
            parentID = parentNode.id
        } else {
            parentID = nil
        }

        guard insertActionNode(
            copy,
            at: ActionDropDestination(parentID: parentID, insertionIndex: insertionIndex)
        ) else {
            return false
        }

        selectedActionNodeID = copy.id
        markPendingChanges()
        return true
    }

    private func prepareReservedActions() {
        ActionTreePresentationState.shared.snapshotReservedExpansion(for: reservedKind, store: self)

        builtinNodes = [
            builtinAction(title: NSLocalizedString("Paste as Plain Text", comment: ""), name: "pasteAsPlainText:"),
            builtinAction(title: NSLocalizedString("Paste as File Path", comment: ""), name: "pasteAsFilePath:"),
            builtinAction(title: NSLocalizedString("Paste as HFS File Path", comment: ""), name: "pasteAsHFSFilePath:"),
            builtinAction(title: NSLocalizedString("Remove", comment: ""), name: "remove:")
        ]

        bundledNodes = bundledActionsURL.map { makeScriptNodes(walking: $0) } ?? []
        usersNodes = makeScriptNodes(walking: userActionsURL)
        selectedReservedNodeID = selectedReservedNodeID ?? reservedNodes.first?.id
        ActionTreePresentationState.shared.restoreReservedExpansion(for: reservedKind, store: self)
    }

    private func findUserReservedNode(path: String) -> ActionNode? {
        let normalizedPath = path
            .split(separator: "/")
            .map(String.init)
        guard !normalizedPath.isEmpty else { return nil }
        return findNode(in: usersNodes, pathComponents: normalizedPath)
    }

    private func findNode(in nodes: [ActionNode], pathComponents: [String]) -> ActionNode? {
        guard let first = pathComponents.first else { return nil }
        guard let node = nodes.first(where: { $0.nodeTitle == first }) else { return nil }
        if pathComponents.count == 1 {
            return node
        }
        return findNode(in: node.children, pathComponents: Array(pathComponents.dropFirst()))
    }

    private func flattenedNodePaths(in nodes: [ActionNode], prefix: [String] = []) -> [String] {
        nodes.flatMap { node -> [String] in
            let path = prefix + [node.nodeTitle]
            let joinedPath = path.joined(separator: "/")
            if node.children.isEmpty {
                return [joinedPath]
            }
            return [joinedPath] + flattenedNodePaths(in: node.children, prefix: path)
        }
    }

    private func expandedNodePaths(
        in nodes: [ActionNode],
        prefix: [String] = [],
        expandedIDs: Set<UUID>
    ) -> [String] {
        nodes.flatMap { node -> [String] in
            let path = prefix + [node.nodeTitle]
            let joinedPath = path.joined(separator: "/")
            let currentPath = expandedIDs.contains(node.id) ? [joinedPath] : []
            return currentPath + expandedNodePaths(in: node.children, prefix: path, expandedIDs: expandedIDs)
        }
    }

    private func loadActionMenu() {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            guard let data = try? Data(contentsOf: fileURL) else {
                actionNodes = defaultActionMenu()
                actionNodes = CMLocalizeDefaultBuiltinActionTitles(in: actionNodes)
                committedActionNodes = actionNodes
                selectedActionNodeID = selectedActionNodeID ?? firstNodeID(in: actionNodes)
                return
            }
            guard let decoded = try? PropertyListDecoder().decode([ActionNode].self, from: data) else {
                actionNodes = []
                committedActionNodes = []
                selectedActionNodeID = nil
                return
            }
            if isEarlierGeneratedDefault(decoded) {
                actionNodes = defaultActionMenu()
            } else {
                actionNodes = decoded
            }
        } else if let legacyNodes = loadLegacyActionMenu() {
            actionNodes = legacyNodes
        } else {
            actionNodes = defaultActionMenu()
        }

        actionNodes = CMLocalizeDefaultBuiltinActionTitles(in: actionNodes)
        committedActionNodes = actionNodes
        selectedActionNodeID = selectedActionNodeID ?? firstNodeID(in: actionNodes)
    }

    private func loadLegacyActionMenu() -> [ActionNode]? {
        guard let data = try? Data(contentsOf: legacyFileURL) else { return nil }

        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            unarchiver.setClass(LegacyArchivedActionNode.self, forClassName: "ActionNode")
            unarchiver.setClass(LegacyArchivedActionNode.self, forClassName: "BaseNode")
            unarchiver.setClass(LegacyArchivedActionNode.self, forClassName: "CMLegacyArchivedActionNode")
            unarchiver.setClass(LegacyArchivedActionNode.self, forClassName: "CMLegacyRuntimeArchivedActionNode")
            defer { unarchiver.finishDecoding() }

            let decodedRoot = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
            let legacyNodes: [LegacyArchivedActionNode]
            if let nodes = decodedRoot as? [LegacyArchivedActionNode] {
                legacyNodes = nodes
            } else if let nodes = decodedRoot as? NSArray {
                legacyNodes = nodes.compactMap { $0 as? LegacyArchivedActionNode }
            } else {
                return nil
            }
            return legacyNodes.map { $0.actionNode() }
        } catch {
            NSLog("ClipMenu failed to migrate legacy actionMenu.data: \(error.localizedDescription)")
            return nil
        }
    }

    private func defaultActionMenu() -> [ActionNode] {
        [
            builtinAction(title: NSLocalizedString("Paste as Plain Text", comment: ""), name: "pasteAsPlainText:"),
            ActionNode(
                nodeTitle: NSLocalizedString("Case", comment: ""),
                children: [
                    "Case/Capitalize.js",
                    "Case/lowercase.js",
                    "Case/Title Case.js",
                    "Case/UPPERCASE.js"
                ].compactMap { bundledScriptNode(relativePath: $0, includeExtensionInTitle: true) }
            ),
            ActionNode(
                nodeTitle: NSLocalizedString("Trim", comment: ""),
                children: [
                    "Trim/LTrim.js",
                    "Trim/RTrim.js",
                    "Trim/Trim.js"
                ].compactMap { bundledScriptNode(relativePath: $0, includeExtensionInTitle: true) }
            ),
            builtinAction(title: NSLocalizedString("Remove", comment: ""), name: "remove:")
        ]
    }

    private func isEarlierGeneratedDefault(_ nodes: [ActionNode]) -> Bool {
        var builtinNames: [String] = []
        var scriptPaths: [String] = []
        for node in nodes {
            collectActionSignatures(from: node, builtinNames: &builtinNames, scriptPaths: &scriptPaths)
        }

        if builtinNames == ["pasteAsPlainText:", "remove:"],
           Set(scriptPaths) == Set([
                "Case/Capitalize.js",
                "Case/Title Case.js",
                "Case/UPPERCASE.js",
                "Case/lowercase.js",
                "Trim/LTrim.js",
                "Trim/RTrim.js",
                "Trim/Trim.js"
           ]) {
            return true
        }

        return builtinNames == ["pasteAsPlainText:", "pasteAsFilePath:", "pasteAsHFSFilePath:", "remove:"]
            && Set(scriptPaths) == Set(bundledScriptRelativePaths())
    }

    private func collectActionSignatures(from node: ActionNode, builtinNames: inout [String], scriptPaths: inout [String]) {
        if let action = node.action {
            switch action[CMActionTypeKey] {
            case CMBuiltinActionType:
                if let name = action["name"] {
                    builtinNames.append(name)
                }
            case CMJavaScriptActionType:
                if let path = action["path"],
                   let relativePath = bundledScriptRelativePath(from: path) {
                    scriptPaths.append(relativePath)
                }
            default:
                break
            }
            return
        }

        for child in node.children {
            collectActionSignatures(from: child, builtinNames: &builtinNames, scriptPaths: &scriptPaths)
        }
    }

    private func bundledScriptRelativePath(from path: String) -> String? {
        if let range = path.range(of: "/script/action/") {
            return String(path[range.upperBound...])
        }

        let scriptActionPrefix = "script/action/"
        if path.hasPrefix(scriptActionPrefix) {
            return String(path.dropFirst(scriptActionPrefix.count))
        }

        guard !path.hasPrefix("/"), path.hasSuffix(".js") else { return nil }
        return path
    }

    private func bundledScriptNode(relativePath: String, includeExtensionInTitle: Bool = false) -> ActionNode? {
        guard let root = bundledActionsURL else { return nil }
        let url = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let title = includeExtensionInTitle ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent
        return scriptAction(title: title, url: url)
    }

    private func bundledScriptRelativePaths() -> [String] {
        var scriptPaths: [String] = []
        var builtinNames: [String] = []
        for node in bundledNodes {
            collectActionSignatures(from: node, builtinNames: &builtinNames, scriptPaths: &scriptPaths)
        }
        return scriptPaths
    }

    private func makeScriptNodes(walking directoryURL: URL) -> [ActionNode] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { url -> ActionNode? in
            let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues?.isDirectory == true {
                return ActionNode(
                    nodeTitle: localizedScriptTitle(url.deletingPathExtension().lastPathComponent),
                    children: makeScriptNodes(walking: url)
                )
            }

            guard url.pathExtension == "js" else { return nil }
            return scriptAction(title: localizedScriptTitle(url.deletingPathExtension().lastPathComponent), url: url)
        }
    }

    private func builtinAction(title: String, name: String) -> ActionNode {
        ActionNode(
            nodeTitle: title,
            action: [
                CMActionTypeKey: CMBuiltinActionType,
                "name": name
            ]
        )
    }

    private func scriptAction(title: String, url: URL) -> ActionNode {
        ActionNode(
            nodeTitle: title,
            action: [
                CMActionTypeKey: CMJavaScriptActionType,
                "path": url.path
            ]
        )
    }

    private func localizedScriptTitle(_ title: String) -> String {
        NSLocalizedString(title, comment: "")
    }

    private func firstNodeID(in nodes: [ActionNode]) -> UUID? {
        for node in nodes {
            if node.isLeaf || node.children.isEmpty {
                return node.id
            }
            if let id = firstNodeID(in: node.children) {
                return id
            }
        }
        return nil
    }

    private func findNode(with id: UUID?, in nodes: [ActionNode]) -> ActionNode? {
        guard let id else { return nil }
        for node in nodes {
            if node.id == id {
                return node
            }
            if let found = findNode(with: id, in: node.children) {
                return found
            }
        }
        return nil
    }

    private func selectedPath(for id: UUID?, in nodes: [ActionNode], prefix: [String] = []) -> [String]? {
        guard let id else { return nil }
        for node in nodes {
            let path = prefix + [node.nodeTitle]
            if node.id == id {
                return path
            }
            if let found = selectedPath(for: id, in: node.children, prefix: path) {
                return found
            }
        }
        return nil
    }

    private func removeNode(with id: UUID, from nodes: inout [ActionNode]) -> Bool {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes.remove(at: index)
            return true
        }

        for index in nodes.indices {
            if removeNode(with: id, from: &nodes[index].children) {
                return true
            }
        }
        return false
    }

    private func selectionAfterRemovingNode(with id: UUID, in nodes: [ActionNode]) -> UUID? {
        let result = selectionAfterRemovingNodeResolution(with: id, in: nodes)
        return result.selectionID
    }

    private func selectionAfterRemovingNodeResolution(with id: UUID, in nodes: [ActionNode]) -> (found: Bool, selectionID: UUID?) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            if nodes.indices.contains(index + 1) {
                return (true, nodes[index + 1].id)
            }
            if index > 0 {
                return (true, nodes[index - 1].id)
            }
            return (true, nil)
        }

        for node in nodes {
            let childResult = selectionAfterRemovingNodeResolution(with: id, in: node.children)
            if childResult.found {
                return (true, childResult.selectionID ?? node.id)
            }
        }

        return (false, nil)
    }

    private func appendActionNode(_ node: ActionNode, toParent parentID: UUID) -> Bool {
        appendActionNode(node, toParent: parentID, at: nil, in: &actionNodes)
    }

    private func showActionSaveAlert(_ error: Error) {
        let alert = CMMakeActionSaveFailureAlert(error)
        CMShowAlert(
            alert,
            sheetFor: NSApp.keyWindow ?? NSApp.mainWindow ?? SwiftUIPreferencesWindowController.shared.window
        )
    }

    private func appendActionNode(_ node: ActionNode, toParent parentID: UUID, at insertionIndex: Int?, in nodes: inout [ActionNode]) -> Bool {
        for index in nodes.indices {
            if nodes[index].id == parentID {
                guard !nodes[index].isLeaf else { return false }
                let childIndex = resolvedInsertionIndex(insertionIndex, count: nodes[index].children.count)
                nodes[index].children.insert(node, at: childIndex)
                return true
            }
            if appendActionNode(node, toParent: parentID, at: insertionIndex, in: &nodes[index].children) {
                return true
            }
        }
        return false
    }

    private func appendActionNode(_ node: ActionNode, toFolder folderID: UUID, in nodes: inout [ActionNode]) -> Bool {
        for index in nodes.indices {
            if nodes[index].id == folderID {
                guard !nodes[index].isLeaf else { return false }
                nodes[index].children.append(node)
                return true
            }
            if appendActionNode(node, toFolder: folderID, in: &nodes[index].children) {
                return true
            }
        }
        return false
    }

    private func moveActionNode(_ id: UUID, to destination: ActionDropDestination) {
        if let parentID = destination.parentID,
           (id == parentID ||
            findNode(with: parentID, in: actionNodes) == nil ||
            node(with: id, contains: parentID, in: actionNodes)) {
            return
        }

        guard let sourceLocation = location(of: id, in: actionNodes) else { return }
        guard let node = extractNode(with: id, from: &actionNodes) else { return }

        let adjustedDestination = adjustedDropDestination(
            destination,
            afterRemovingSourceAt: sourceLocation
        )

        guard insertActionNode(node, at: adjustedDestination) else {
            _ = insertActionNode(node, at: ActionDropDestination(parentID: sourceLocation.parentID, insertionIndex: sourceLocation.index))
            return
        }
        selectedActionNodeID = node.id
        markPendingChanges()
    }

    private func insertActionNode(_ node: ActionNode, at destination: ActionDropDestination) -> Bool {
        if let parentID = destination.parentID {
            return appendActionNode(node, toParent: parentID, at: destination.insertionIndex, in: &actionNodes)
        }

        let insertionIndex = resolvedInsertionIndex(destination.insertionIndex, count: actionNodes.count)
        actionNodes.insert(node, at: insertionIndex)
        return true
    }

    private func extractNode(with id: UUID, from nodes: inout [ActionNode]) -> ActionNode? {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            return nodes.remove(at: index)
        }

        for index in nodes.indices {
            if let node = extractNode(with: id, from: &nodes[index].children) {
                return node
            }
        }
        return nil
    }

    private func node(with id: UUID, contains targetID: UUID, in nodes: [ActionNode]) -> Bool {
        guard let node = findNode(with: id, in: nodes) else { return false }
        return findNode(with: targetID, in: node.children) != nil
    }

    private func resolvedInsertionIndex(_ insertionIndex: Int?, count: Int) -> Int {
        min(max(insertionIndex ?? count, 0), count)
    }

    private func location(of id: UUID, in nodes: [ActionNode], parentID: UUID? = nil) -> (parentID: UUID?, index: Int)? {
        for (index, node) in nodes.enumerated() {
            if node.id == id {
                return (parentID, index)
            }
            if let childLocation = location(of: id, in: node.children, parentID: node.id) {
                return childLocation
            }
        }
        return nil
    }

    private func adjustedDropDestination(
        _ destination: ActionDropDestination,
        afterRemovingSourceAt sourceLocation: (parentID: UUID?, index: Int)
    ) -> ActionDropDestination {
        guard destination.parentID == sourceLocation.parentID,
              let insertionIndex = destination.insertionIndex,
              sourceLocation.index < insertionIndex else {
            return destination
        }

        return ActionDropDestination(
            parentID: destination.parentID,
            insertionIndex: insertionIndex - 1
        )
    }

    private func moveNode(with id: UUID, in nodes: inout [ActionNode], offset: Int) -> Bool {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            let destination = index + offset
            guard nodes.indices.contains(destination) else { return false }
            nodes.swapAt(index, destination)
            return true
        }

        for index in nodes.indices {
            if moveNode(with: id, in: &nodes[index].children, offset: offset) {
                return true
            }
        }
        return false
    }

    private func canMoveNode(with id: UUID?, in nodes: [ActionNode], offset: Int) -> Bool {
        guard let id else { return false }

        if let index = nodes.firstIndex(where: { $0.id == id }) {
            let destination = index + offset
            return nodes.indices.contains(destination)
        }

        for node in nodes {
            if canMoveNode(with: id, in: node.children, offset: offset) {
                return true
            }
        }
        return false
    }

    private func updateTitle(for id: UUID, in nodes: inout [ActionNode], title: String) {
        for index in nodes.indices {
            if nodes[index].id == id {
                nodes[index].nodeTitle = title
                return
            }
            updateTitle(for: id, in: &nodes[index].children, title: title)
        }
    }
}

private struct ActionPreferencesView: View {
    @AppStorage(CMPrefEnableActionKey) private var enableActions = true
    @AppStorage(CMPrefInvokeActionImmediatelyKey) private var invokeImmediately = false
    @StateObject private var store = ActionFileStore.shared
    @StateObject private var behaviorDraft = ActionBehaviorDraft.shared
    @StateObject private var inspectorState = ActionInspectorState.shared
    @StateObject private var presentationState = ActionTreePresentationState.shared
    @State private var focusedActionNameID: UUID?

    var body: some View {
        let behaviorOptions = ActionBehaviorOption.options(from: store)

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PreferenceSection(legacyBehaviorSectionTitle) {
                    PreferenceToggle(title: NSLocalizedString("756.title", tableName: "Preferences", bundle: .main, value: "Enable Action", comment: ""), isOn: $enableActions)
                    PreferenceToggle(title: NSLocalizedString("757.title", tableName: "Preferences", bundle: .main, value: "Invoke an action immediately if only one action was registered", comment: ""), isOn: $invokeImmediately)
                        .disabled(!enableActions)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(legacyModifierClickBehaviorsTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 10) {
                            modifierBehaviorPicker(
                                title: NSLocalizedString("1190.title", tableName: "Preferences", bundle: .main, value: "Control + Click:", comment: ""),
                                selection: $behaviorDraft.controlClickBehaviorID,
                                defaultsKey: CMPrefContorlClickBehaviorKey,
                                options: behaviorOptions
                            )
                            modifierBehaviorPicker(
                                title: NSLocalizedString("1209.title", tableName: "Preferences", bundle: .main, value: "Shift + Click:", comment: ""),
                                selection: $behaviorDraft.shiftClickBehaviorID,
                                defaultsKey: CMPrefShiftClickBehaviorKey,
                                options: behaviorOptions
                            )
                            modifierBehaviorPicker(
                                title: NSLocalizedString("1215.title", tableName: "Preferences", bundle: .main, value: "Option + Click:", comment: ""),
                                selection: $behaviorDraft.optionClickBehaviorID,
                                defaultsKey: CMPrefOptionClickBehaviorKey,
                                options: behaviorOptions
                            )
                            modifierBehaviorPicker(
                                title: NSLocalizedString("1221.title", tableName: "Preferences", bundle: .main, value: "Command + Click:", comment: ""),
                                selection: $behaviorDraft.commandClickBehaviorID,
                                defaultsKey: CMPrefCommandClickBehaviorKey,
                                options: behaviorOptions
                            )
                        }
                    }
                    .disabled(!enableActions)
                }

                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(NSLocalizedString("Available Actions", comment: ""))
                                .font(.headline)

                            Picker("", selection: $store.reservedKind) {
                                ForEach(ReservedActionKind.allCases) { kind in
                                    Text(kind.title).tag(kind)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(SegmentedPickerStyle())
                        }

                        ActionTreePanel(
                            title: "",
                            columnHeaderTitle: legacyAvailableActionsNameHeader,
                            nodes: store.reservedNodes,
                            selection: $store.selectedReservedNodeID,
                            editable: false,
                            expandedNodeIDs: $presentationState.expandedReservedNodeIDs,
                            dragProvider: store.actionDragProvider(for:),
                            onSelectionChange: { _ in
                                inspectorState.activePane = .reserved
                            },
                            emptyState: reservedEmptyState
                        )
                    }

                    actionToolbarCard
                        .padding(.top, 84)

                    VStack(alignment: .leading, spacing: 10) {
                        if let inspectorContext = inspectorContext {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(actionInspectorTitle(for: inspectorContext))
                                    .font(.headline)

                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    actionInspectorLabel(legacyActionNameLabel)
                                    if inspectorContext.pane == .action {
                                        FocusablePlainTextField(
                                            text: store.binding(for: inspectorContext.node.id),
                                            placeholder: "",
                                            font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                                            focusToken: focusedActionNameID == inspectorContext.node.id ? inspectorContext.node.id : nil,
                                            updatesContinuously: false,
                                            canEndEditing: CMActionNameCanEndEditing(_:),
                                            debugKey: "action-inspector-name"
                                        )
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(Color(NSColor.textBackgroundColor))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                        )
                                    } else {
                                        readOnlyInspectorField(inspectorContext.node.nodeTitle)
                                    }
                                }

                                actionInspectorValueRow(
                                    label: legacyActionTypeLabel,
                                    value: actionInspectorTypeTitle(for: inspectorContext.node)
                                )

                                if let path = actionInspectorPath(for: inspectorContext.node) {
                                    actionInspectorValueRow(
                                        label: legacyActionPathLabel,
                                        value: path,
                                        monospaced: true
                                    )
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(legacyActionMenuTitle)
                                .font(.headline)
                        }

                        ActionTreePanel(
                            title: "",
                            columnHeaderTitle: legacyActionMenuNameHeader,
                            nodes: store.actionNodes,
                            selection: $store.selectedActionNodeID,
                            editable: true,
                            expandedNodeIDs: $presentationState.expandedActionNodeIDs,
                            titleBinding: store.binding(for:),
                            dragProvider: store.actionMoveDragProvider(for:),
                            onSelectionChange: { _ in
                                inspectorState.activePane = .action
                            },
                            onDrop: { providers in
                                performAcceptActionNodeDrop(
                                    providers,
                                    destination: ActionDropDestination(parentID: nil, insertionIndex: nil)
                                )
                            },
                            onNodeDrop: { providers, destination in
                                performAcceptActionNodeDrop(providers, destination: destination)
                            },
                            emptyState: actionMenuEmptyState
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: 1080, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            store.reload()
            behaviorDraft.reload(from: behaviorOptions)
            inspectorState.activePane = .action
            reconcileExpandedReservedNodeIDs(resetIfEmpty: true)
            reconcileExpandedActionNodeIDs(resetIfEmpty: true)
        }
        .onChange(of: behaviorOptions) { newOptions in
            behaviorDraft.reload(from: newOptions)
        }
        .onChange(of: store.reservedNodes) { _ in
            reconcileExpandedReservedNodeIDs()
        }
        .onChange(of: store.selectedReservedNodeID) { _ in
            expandSelectedReservedNodePath()
        }
        .onChange(of: store.reservedKind) { _ in
            reconcileExpandedReservedNodeIDs()
        }
        .onChange(of: store.actionNodes) { _ in
            reconcileExpandedActionNodeIDs()
        }
        .onChange(of: store.selectedActionNodeID) { _ in
            expandSelectedActionNodePath()
        }
    }

    private func flattenedActionNodes(_ nodes: [ActionNode]) -> [ActionNode] {
        nodes + nodes.flatMap { flattenedActionNodes($0.children) }
    }

    @ViewBuilder
    private func modifierBehaviorPicker(
        title: String,
        selection: Binding<String>,
        defaultsKey: String,
        options: [ActionBehaviorOption]
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("", selection: selection) {
                ForEach(options) { option in
                    if option.isSeparator {
                        Divider()
                    } else {
                        Text(option.title).tag(option.id)
                    }
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: selection.wrappedValue) { newValue in
            ActionBehaviorDraft.shared.stageSelection(id: newValue, defaultsKey: defaultsKey, options: options)
        }
    }

    @ViewBuilder
    private func actionInspectorLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.secondary)
            .frame(width: 72, alignment: .trailing)
    }

    private var actionToolbarCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 8) {
                actionToolbarButton(
                    systemImage: "plus",
                    legacyImageName: "NSAddTemplate",
                    help: NSLocalizedString("Add", comment: ""),
                    disabled: store.selectedReservedNodeID == nil,
                    action: performAddSelectedReservedNode
                )
                actionToolbarButton(
                    systemImage: "folder.badge.plus",
                    help: NSLocalizedString("Add Folder", comment: ""),
                    action: performAddActionFolder
                )
                actionToolbarButton(
                    systemImage: "minus",
                    legacyImageName: "NSRemoveTemplate",
                    help: NSLocalizedString("Remove", comment: ""),
                    disabled: store.selectedActionNodeID == nil,
                    action: performRemoveSelectedActionNode
                )

                Divider()

                actionToolbarButton(systemImage: "arrow.up", help: NSLocalizedString("Move Up", comment: ""), disabled: !store.canMoveSelectedActionNodeUp(), action: performMoveSelectedActionNodeUp)
                actionToolbarButton(systemImage: "arrow.down", help: NSLocalizedString("Move Down", comment: ""), disabled: !store.canMoveSelectedActionNodeDown(), action: performMoveSelectedActionNodeDown)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func actionToolbarButton(
        systemImage: String,
        legacyImageName: String? = nil,
        help: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            actionToolbarIcon(legacyImageName: legacyImageName, fallbackSystemImage: systemImage)
                .frame(width: 18, height: 18)
        }
        .help(help)
        .disabled(disabled)
    }

    private func actionToolbarIcon(legacyImageName: String?, fallbackSystemImage: String) -> some View {
        Group {
            if let copiedImage = actionToolbarLegacyImage(named: legacyImageName) {
                Image(nsImage: copiedImage)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: fallbackSystemImage)
            }
        }
    }

    private func actionToolbarLegacyImage(named legacyImageName: String?) -> NSImage? {
        guard let legacyImageName,
              let sourceImage = NSImage(named: NSImage.Name(legacyImageName)),
              let copiedImage = sourceImage.copy() as? NSImage else {
            return nil
        }
        copiedImage.isTemplate = true
        return copiedImage
    }

    private func readOnlyInspectorField(_ value: String) -> some View {
        Text(value.isEmpty ? " " : value)
            .font(.body)
            .foregroundColor(.primary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func actionInspectorValueRow(label: String, value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            actionInspectorLabel(label)
            Text(value)
                .font(monospaced ? .system(.body, design: .monospaced) : .body)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var inspectorContext: ActionInspectorSnapshot? {
        inspectorState.currentSnapshot(store: store)
    }

    private func actionInspectorTitle(for context: ActionInspectorSnapshot) -> String {
        context.pane == .action
            ? NSLocalizedString("Selected Action", comment: "")
            : NSLocalizedString("Available Action Details", comment: "")
    }

    private func flattenedNodeCount(in nodes: [ActionNode]) -> Int {
        nodes.reduce(0) { partialResult, node in
            partialResult + 1 + flattenedNodeCount(in: node.children)
        }
    }

    private func performAddSelectedReservedNode() {
        endActionEditorEditing()
        store.addSelectedReservedNode()
        inspectorState.activePane = .action
        focusSelectedActionName()
    }

    private func performAddActionFolder() {
        endActionEditorEditing()
        store.addFolder()
        inspectorState.activePane = .action
        focusSelectedActionName()
    }

    private func performRemoveSelectedActionNode() {
        endActionEditorEditing()
        store.removeSelectedActionNode()
    }

    private func performMoveSelectedActionNodeUp() {
        endActionEditorEditing()
        store.moveSelectedActionNodeUp()
    }

    private func performMoveSelectedActionNodeDown() {
        endActionEditorEditing()
        store.moveSelectedActionNodeDown()
    }

    private func performAcceptActionNodeDrop(_ providers: [NSItemProvider], destination: ActionDropDestination) -> Bool {
        endActionEditorEditing()
        return store.acceptActionNodeDrop(providers, destination: destination)
    }

    private func endActionEditorEditing() {
        if let window = NSApp.keyWindow ?? NSApp.mainWindow,
           !window.makeFirstResponder(window) {
            window.endEditing(for: nil)
        }
    }

    private func focusSelectedActionName() {
        focusedActionNameID = nil
        let selectedID = store.selectedActionNodeID
        DispatchQueue.main.async {
            focusedActionNameID = selectedID
        }
    }

    private func reconcileExpandedReservedNodeIDs(resetIfEmpty: Bool = false) {
        let currentFolderIDs = Set(folderNodeIDs(in: store.reservedNodes))
        if resetIfEmpty && presentationState.expandedReservedNodeIDs.isEmpty {
            presentationState.expandedReservedNodeIDs = currentFolderIDs
        } else {
            presentationState.expandedReservedNodeIDs = presentationState.expandedReservedNodeIDs.intersection(currentFolderIDs)
        }
        expandSelectedReservedNodePath()
    }

    private func expandSelectedReservedNodePath() {
        guard let selectedID = store.selectedReservedNodeID,
              let ancestorIDs = actionAncestorFolderIDs(for: selectedID, in: store.reservedNodes) else {
            return
        }
        presentationState.expandedReservedNodeIDs.formUnion(ancestorIDs)
    }

    private func reconcileExpandedActionNodeIDs(resetIfEmpty: Bool = false) {
        let currentFolderIDs = Set(folderNodeIDs(in: store.actionNodes))
        if resetIfEmpty && presentationState.expandedActionNodeIDs.isEmpty {
            presentationState.expandedActionNodeIDs = currentFolderIDs
        } else {
            presentationState.expandedActionNodeIDs = presentationState.expandedActionNodeIDs.intersection(currentFolderIDs)
        }
        expandSelectedActionNodePath()
    }

    private func expandSelectedActionNodePath() {
        guard let selectedID = store.selectedActionNodeID,
              let ancestorIDs = actionAncestorFolderIDs(for: selectedID, in: store.actionNodes) else {
            return
        }
        presentationState.expandedActionNodeIDs.formUnion(ancestorIDs)
    }

    private func folderNodeIDs(in nodes: [ActionNode]) -> [UUID] {
        nodes.flatMap { node in
            node.isLeaf ? [] : [node.id] + folderNodeIDs(in: node.children)
        }
    }

    private func actionInspectorTypeTitle(for node: ActionNode) -> String {
        CMActionInspectorTypeTitle(for: node)
    }

    private func actionInspectorPath(for node: ActionNode) -> String? {
        CMActionInspectorPath(for: node)
    }

    private var legacyActionNameLabel: String {
        NSLocalizedString("752.title", tableName: "Preferences", bundle: .main, value: "Name:", comment: "")
    }

    private var legacyActionTypeLabel: String {
        NSLocalizedString("1086.label", tableName: "Preferences", bundle: .main, value: "Type", comment: "") + ":"
    }

    private var legacyActionPathLabel: String {
        NSLocalizedString("Path", comment: "") + ":"
    }

    private var legacyFolderLabel: String {
        NSLocalizedString("747.title", tableName: "Preferences", bundle: .main, value: "Folder", comment: "")
    }

    private var legacyItemsLabel: String {
        NSLocalizedString("1171.title", tableName: "Preferences", bundle: .main, value: "items", comment: "")
    }

    private var legacyAvailableActionsNameHeader: String {
        NSLocalizedString("612.headerCell.title", tableName: "Preferences", bundle: .main, value: "Name", comment: "")
    }

    private var legacyActionMenuNameHeader: String {
        NSLocalizedString("624.headerCell.title", tableName: "Preferences", bundle: .main, value: "Name", comment: "")
    }

    private var legacyModifierClickBehaviorsTitle: String {
        NSLocalizedString("1223.title", tableName: "Preferences", bundle: .main, value: "Modifier key + Click behaviors on history menu items", comment: "")
    }

    private var legacyBehaviorSectionTitle: String {
        NSLocalizedString("1305.title", tableName: "Preferences", bundle: .main, value: "Behavior", comment: "")
    }

    private var legacyActionMenuTitle: String {
        NSLocalizedString("1232.title", tableName: "Preferences", bundle: .main, value: "Action Menu", comment: "")
    }

    private var reservedEmptyState: ActionTreePanel.EmptyState {
        switch store.reservedKind {
        case .builtin:
            return .init(
                systemImage: "bolt.slash",
                title: CMActionReservedEmptyStateTitle(for: .builtin),
                message: CMActionReservedEmptyStateMessage(for: .builtin)
            )
        case .bundled:
            return .init(
                systemImage: "doc.text.magnifyingglass",
                title: CMActionReservedEmptyStateTitle(for: .bundled),
                message: CMActionReservedEmptyStateMessage(for: .bundled)
            )
        case .user:
            return .init(
                systemImage: "person.crop.circle.badge.xmark",
                title: CMActionReservedEmptyStateTitle(for: .user),
                message: CMActionReservedEmptyStateMessage(for: .user)
            )
        }
    }

    private var actionMenuEmptyState: ActionTreePanel.EmptyState {
        .init(
            systemImage: "list.bullet.rectangle",
            title: CMActionMenuEmptyStateTitle(),
            message: CMActionMenuEmptyStateMessage()
        )
    }
}

func CMFlushEditorStoresForTermination() {
    RecordingPreferencesStore.shared.applyStoreTypes()
    SnippetFileStore.shared.save()
    ActionFileStore.shared.save()
}

final class ActionBehaviorDraft: ObservableObject {
    static let shared = ActionBehaviorDraft()

    @Published var controlClickBehaviorID = ActionBehaviorOption.none.id
    @Published var shiftClickBehaviorID = ActionBehaviorOption.none.id
    @Published var optionClickBehaviorID = ActionBehaviorOption.none.id
    @Published var commandClickBehaviorID = ActionBehaviorOption.none.id

    private var pendingDefaults: [String: Any] = [:]

    fileprivate func reload(from options: [ActionBehaviorOption]) {
        controlClickBehaviorID = ActionBehaviorOption.id(
            for: pendingDefaults[CMPrefContorlClickBehaviorKey] ?? UserDefaults.standard.object(forKey: CMPrefContorlClickBehaviorKey),
            options: options
        )
        shiftClickBehaviorID = ActionBehaviorOption.id(
            for: pendingDefaults[CMPrefShiftClickBehaviorKey] ?? UserDefaults.standard.object(forKey: CMPrefShiftClickBehaviorKey),
            options: options
        )
        optionClickBehaviorID = ActionBehaviorOption.id(
            for: pendingDefaults[CMPrefOptionClickBehaviorKey] ?? UserDefaults.standard.object(forKey: CMPrefOptionClickBehaviorKey),
            options: options
        )
        commandClickBehaviorID = ActionBehaviorOption.id(
            for: pendingDefaults[CMPrefCommandClickBehaviorKey] ?? UserDefaults.standard.object(forKey: CMPrefCommandClickBehaviorKey),
            options: options
        )
    }

    fileprivate func stageSelection(id: String, defaultsKey: String, options: [ActionBehaviorOption]) {
        guard let option = options.first(where: { $0.id == id }),
              let defaultsObject = option.defaultsObject else {
            return
        }
        pendingDefaults[defaultsKey] = defaultsObject
    }

    func stageDefaultsObject(_ defaultsObject: Any, defaultsKey: String) {
        pendingDefaults[defaultsKey] = defaultsObject
    }

    func commitPendingSelections() {
        guard !pendingDefaults.isEmpty else { return }
        for (key, value) in pendingDefaults {
            UserDefaults.standard.set(value, forKey: key)
        }
        pendingDefaults.removeAll()
    }

    func discardPendingSelections() {
        pendingDefaults.removeAll()
    }
}

private struct ActionBehaviorOption: Identifiable, Hashable {
    enum Behavior: Hashable {
        case string(String)
        case action([String: String])
    }

    let id: String
    let title: String
    let behavior: Behavior?
    let isSeparator: Bool

    var defaultsObject: Any? {
        switch behavior {
        case .string(let value):
            return value
        case .action(let action):
            return action
        case nil:
            return nil
        }
    }

    static let none = ActionBehaviorOption(
        id: "string:",
        title: NSLocalizedString("None", comment: ""),
        behavior: .string(""),
        isSeparator: false
    )

    static let popUpActionMenu = ActionBehaviorOption(
        id: "string:popUpActionMenu",
        title: NSLocalizedString("Pop up Action Menu", comment: ""),
        behavior: .string("popUpActionMenu"),
        isSeparator: false
    )

    static func options(from store: ActionFileStore) -> [ActionBehaviorOption] {
        var results: [ActionBehaviorOption] = [.none, .popUpActionMenu]
        results.append(separator(id: 0))
        results.append(contentsOf: actionOptions(in: store.builtinNodes, prefix: "builtin"))
        results.append(separator(id: 1))
        results.append(contentsOf: actionOptions(in: store.bundledNodes, prefix: "bundled"))
        results.append(separator(id: 2))
        results.append(contentsOf: actionOptions(in: store.usersNodes, prefix: "user"))
        return results
    }

    static func id(for defaultsObject: Any?, options: [ActionBehaviorOption]) -> String {
        let fallback = none.id
        guard let defaultsObject else { return fallback }

        if let value = defaultsObject as? String {
            return options.last { $0.behavior == .string(value) }?.id ?? fallback
        }

        if let action = actionDictionary(from: defaultsObject) {
            let id = actionID(action)
            return options.last { option in
                guard case .action(let optionAction) = option.behavior else { return false }
                return actionID(optionAction) == id
            }?.id ?? fallback
        }

        return fallback
    }

    private static func separator(id: Int) -> ActionBehaviorOption {
        ActionBehaviorOption(id: "separator:\(id)", title: "-", behavior: nil, isSeparator: true)
    }

    private static func actionOptions(in nodes: [ActionNode], prefix: String) -> [ActionBehaviorOption] {
        nodes.enumerated().flatMap { index, node -> [ActionBehaviorOption] in
            if let action = node.action {
                return [ActionBehaviorOption(
                    id: "\(prefix):\(index):\(actionID(action))",
                    title: node.nodeTitle,
                    behavior: .action(action),
                    isSeparator: false
                )]
            }
            return actionOptions(in: node.children, prefix: "\(prefix):\(index)")
        }
    }

    private static func actionID(_ action: [String: String]) -> String {
        if let type = action[CMActionTypeKey], type == CMBuiltinActionType {
            return "action:builtin:\(action["name"] ?? "")"
        }
        if let type = action[CMActionTypeKey], type == CMJavaScriptActionType {
            let path = action["path"] ?? ""
            let normalizedPath = bundledScriptRelativePath(from: path) ?? path
            return "action:js:\(normalizedPath)"
        }
        return "action:\(action.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&"))"
    }

    private static func bundledScriptRelativePath(from path: String) -> String? {
        if let range = path.range(of: "/script/action/") {
            return String(path[range.upperBound...])
        }

        let scriptActionPrefix = "script/action/"
        if path.hasPrefix(scriptActionPrefix) {
            return String(path.dropFirst(scriptActionPrefix.count))
        }

        guard !path.hasPrefix("/"), path.hasSuffix(".js") else { return nil }
        return path
    }

}

private struct ActionTreePanel: View {
    struct EmptyState {
        let systemImage: String
        let title: String
        let message: String
    }

    let title: String
    let columnHeaderTitle: String?
    let nodes: [ActionNode]
    @Binding var selection: UUID?
    let editable: Bool
    var expandedNodeIDs: Binding<Set<UUID>>?
    var inlineTitleEditing = false
    var titleBinding: ((UUID) -> Binding<String>)?
    var dragProvider: ((ActionNode) -> NSItemProvider)?
    var onSelectionChange: ((UUID) -> Void)?
    var onDrop: (([NSItemProvider]) -> Bool)?
    var onNodeDrop: (([NSItemProvider], ActionDropDestination) -> Bool)?
    var emptyState: EmptyState?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            if let columnHeaderTitle, !columnHeaderTitle.isEmpty {
                VStack(spacing: 0) {
                    Text(columnHeaderTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.75))
                    Rectangle()
                        .fill(Color(NSColor.separatorColor))
                        .frame(height: 1)
                }
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                        ActionNodeRow(
                            node: node,
                            parentID: nil,
                            siblingIndex: index,
                            level: 0,
                            selection: $selection,
                            editable: editable,
                            expandedNodeIDs: expandedNodeIDs,
                            inlineTitleEditing: inlineTitleEditing,
                            titleBinding: titleBinding,
                            dragProvider: dragProvider,
                            onSelectionChange: onSelectionChange,
                            onNodeDrop: onNodeDrop
                        )
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .overlay(
                Group {
                    if nodes.isEmpty, let emptyState {
                        actionTreeEmptyState(emptyState)
                    }
                }
            )
            .onDrop(of: [UTType.clipMenuActionNodeDrag], isTargeted: nil) { providers in
                onDrop?(providers) ?? false
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func actionTreeEmptyState(_ state: EmptyState) -> some View {
        VStack(spacing: 10) {
            Image(systemName: state.systemImage)
                .font(.system(size: 26))
                .foregroundColor(.secondary)
            Text(state.title)
                .font(.headline)
            Text(state.message)
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ActionNodeRow: View {
    let node: ActionNode
    let parentID: UUID?
    let siblingIndex: Int
    let level: Int
    @Binding var selection: UUID?
    let editable: Bool
    var expandedNodeIDs: Binding<Set<UUID>>?
    let inlineTitleEditing: Bool
    var titleBinding: ((UUID) -> Binding<String>)?
    var dragProvider: ((ActionNode) -> NSItemProvider)?
    var onSelectionChange: ((UUID) -> Void)?
    var onNodeDrop: (([NSItemProvider], ActionDropDestination) -> Bool)?
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 8) {
                disclosureControl
                rowIcon

                if editable, inlineTitleEditing, node.id == selection, let titleBinding {
                    TextField("", text: titleBinding(node.id))
                        .textFieldStyle(PlainTextFieldStyle())
                } else {
                    Text(node.nodeTitle)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)
            }
            .padding(.leading, CGFloat(level) * 16)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(selection == node.id ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(selection == node.id ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selection = node.id
                onSelectionChange?(node.id)
            }
            .actionNodeDragProvider {
                dragProvider?(node)
            }
            .actionNodeDropTarget(
                enabled: editable,
                destination: dropDestination,
                onDrop: onNodeDrop
            )

            if rowIsExpanded {
                ForEach(Array(node.children.enumerated()), id: \.element.id) { index, child in
                    ActionNodeRow(
                        node: child,
                        parentID: node.id,
                        siblingIndex: index,
                        level: level + 1,
                        selection: $selection,
                        editable: editable,
                        expandedNodeIDs: expandedNodeIDs,
                        inlineTitleEditing: inlineTitleEditing,
                        titleBinding: titleBinding,
                        dragProvider: dragProvider,
                        onSelectionChange: onSelectionChange,
                        onNodeDrop: onNodeDrop
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var disclosureControl: some View {
        if !node.isLeaf && !node.children.isEmpty {
            Button {
                toggleExpanded()
            } label: {
                Image(systemName: rowIsExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 10)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear
                .frame(width: 10, height: 10)
        }
    }

    @ViewBuilder
    private var rowIcon: some View {
        if node.isLeaf {
            Image(systemName: actionImageName)
                .frame(width: 14)
                .foregroundColor(rowIconTint)
        } else {
            Image(systemName: "folder")
                .frame(width: 14)
                .foregroundColor(rowIconTint)
        }
    }

    private var actionImageName: String {
        if node.action?[CMActionTypeKey] == CMJavaScriptActionType {
            return "doc.text"
        }
        return "bolt"
    }

    private var rowIconTint: Color {
        if !node.isLeaf {
            return .secondary
        }
        if node.action?[CMActionTypeKey] == CMJavaScriptActionType {
            return Color(NSColor.systemTeal)
        }
        return Color(NSColor.systemOrange)
    }

    private var dropDestination: ActionDropDestination {
        if node.isLeaf {
            return ActionDropDestination(parentID: parentID, insertionIndex: siblingIndex + 1)
        }
        return ActionDropDestination(parentID: node.id, insertionIndex: node.children.count)
    }

    private var rowIsExpanded: Bool {
        if let expandedNodeIDs {
            return expandedNodeIDs.wrappedValue.contains(node.id)
        }
        return isExpanded
    }

    private func toggleExpanded() {
        if let expandedNodeIDs {
            var updated = expandedNodeIDs.wrappedValue
            if updated.contains(node.id) {
                updated.remove(node.id)
            } else {
                updated.insert(node.id)
            }
            expandedNodeIDs.wrappedValue = updated
        } else {
            isExpanded.toggle()
        }
    }
}

private extension View {
    @ViewBuilder
    func actionNodeDragProvider(_ provider: @escaping () -> NSItemProvider?) -> some View {
        if let provider = provider() {
            onDrag { provider }
        } else {
            self
        }
    }

    @ViewBuilder
    func actionNodeDropTarget(
        enabled: Bool,
        destination: ActionDropDestination,
        onDrop: (([NSItemProvider], ActionDropDestination) -> Bool)?
    ) -> some View {
        if enabled, let onDrop {
            self.onDrop(of: [UTType.clipMenuActionNodeDrag], isTargeted: nil) { providers in
                onDrop(providers, destination)
            }
        } else {
            self
        }
    }
}

private struct SnippetPlacementPreferenceSection: View {
    @AppStorage(CMPrefPositionOfSnippetsKey) private var position = CMPositionOfSnippets.belowClips.rawValue

    private let legacySnippetPositionLabel = NSLocalizedString("903.title", tableName: "Preferences", bundle: .main, value: "The position to show snippets in ClipMenu:", comment: "")
    private let legacySnippetHiddenLabel = NSLocalizedString("907.title", tableName: "Preferences", bundle: .main, value: "None", comment: "")
    private let legacySnippetAboveHistoryLabel = NSLocalizedString("908.title", tableName: "Preferences", bundle: .main, value: "Above the clipboard history", comment: "")
    private let legacySnippetBelowHistoryLabel = NSLocalizedString("909.title", tableName: "Preferences", bundle: .main, value: "Below the clipboard history", comment: "")

    private var snippetPositionSelection: Binding<Int> {
        Binding(
            get: { CMNormalizedLegacySnippetPosition(position) },
            set: { position = CMNormalizedLegacySnippetPosition($0) }
        )
    }

    var body: some View {
        PreferenceSection(NSLocalizedString("Snippets", comment: "")) {
            VStack(alignment: .leading, spacing: 10) {
                PreferenceRow(legacySnippetPositionLabel) {
                    Picker(selection: snippetPositionSelection) {
                        Text(legacySnippetHiddenLabel).tag(CMPositionOfSnippets.none.rawValue)
                        Text(legacySnippetAboveHistoryLabel).tag(CMPositionOfSnippets.aboveClips.rawValue)
                        Text(legacySnippetBelowHistoryLabel).tag(CMPositionOfSnippets.belowClips.rawValue)
                    } label: {
                        EmptyView()
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 260, alignment: .leading)
                }

                snippetPlacementPreviewRows
            }
        }
        .onAppear {
            let normalizedPosition = CMNormalizedLegacySnippetPosition(position)
            if normalizedPosition != position {
                position = normalizedPosition
            }
        }
    }

    private var snippetPlacementPreviewRows: some View {
        let option = SnippetPositionCardOption(rawValue: CMNormalizedLegacySnippetPosition(position)) ?? .below

        return VStack(alignment: .leading, spacing: 4) {
            ForEach(option.previewRows, id: \.self) { row in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(rowTint(for: row, selected: option.rawValue == position))
                        .frame(width: 64, height: 6)

                    Text(previewRowTitle(row))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func previewRowTitle(_ row: SnippetPositionCardOption.PreviewRow) -> String {
        switch row {
        case .snippets:
            return NSLocalizedString("Snippets", comment: "")
        case .history:
            return NSLocalizedString("History", comment: "")
        case .commands:
            return CMLocalizedModernString("Commands", japanese: "コマンド")
        }
    }

    private func rowTint(for row: SnippetPositionCardOption.PreviewRow, selected: Bool) -> Color {
        switch row {
        case .snippets:
            return Color(NSColor.systemPink).opacity(selected ? 0.85 : 0.55)
        case .history:
            return Color(NSColor.systemBlue).opacity(selected ? 0.85 : 0.55)
        case .commands:
            return Color(NSColor.systemGray).opacity(selected ? 0.6 : 0.45)
        }
    }

}

private enum SnippetPositionCardOption: Int, CaseIterable, Identifiable {
    case none = 0
    case above = 1
    case below = 2

    enum PreviewRow: String {
        case snippets
        case history
        case commands
    }

    var id: Int { rawValue }

    var tint: Color {
        switch self {
        case .none:
            return Color(NSColor.systemGray)
        case .above:
            return Color(NSColor.systemPink)
        case .below:
            return Color(NSColor.systemBlue)
        }
    }

    var systemImage: String {
        switch self {
        case .none:
            return "eye.slash"
        case .above:
            return "arrow.up.to.line"
        case .below:
            return "arrow.down.to.line"
        }
    }

    var detail: String {
        switch self {
        case .none:
            return NSLocalizedString("Keep the main menu focused on clipboard history and commands only.", comment: "")
        case .above:
            return NSLocalizedString("Let snippets lead the popup before the history section.", comment: "")
        case .below:
            return NSLocalizedString("Keep snippets available after the history list.", comment: "")
        }
    }

    var previewRows: [PreviewRow] {
        switch self {
        case .none:
            return [.history, .commands, .commands]
        case .above:
            return [.snippets, .history, .commands]
        case .below:
            return [.history, .snippets, .commands]
        }
    }

    func title(hidden: String, above: String, below: String) -> String {
        switch self {
        case .none:
            return hidden
        case .above:
            return above
        case .below:
            return below
        }
    }
}

private struct UpdatePreferencesView: View {
    @AppStorage(CMEnableAutomaticCheckKey) private var automaticChecks = true
    @AppStorage(CMEnableAutomaticCheckPreReleaseKey) private var preReleases = false
    @AppStorage(CMUpdateCheckIntervalKey) private var interval = 86400
    @AppStorage(CMAutomaticallyInstallUpdatesKey) private var automaticallyInstallUpdates = false
    @ObservedObject private var updateCoordinator = UpdateCoordinator.shared

    private let legacyAutomaticCheckLabel = NSLocalizedString("1337.title", tableName: "Preferences", bundle: .main, value: "Automatically check for updates:", comment: "")
    private let legacyIncludePreReleasesLabel = NSLocalizedString("1426.title", tableName: "Preferences", bundle: .main, value: "Include pre-releases", comment: "")
    private let legacyCheckNowLabel = NSLocalizedString("1331.title", tableName: "Preferences", bundle: .main, value: "Check Now", comment: "")
    private let legacyUpdateIntervalLabel = NSLocalizedString("1279.title", tableName: "Preferences", bundle: .main, value: "Time interval", comment: "")
    private let legacyAutomaticallyInstallUpdatesLabel = NSLocalizedString("Automatically download and install updates in the future", comment: "")

    var body: some View {
        PreferencePane {
            PreferenceSection(NSLocalizedString("Updates", comment: "")) {
                VStack(alignment: .leading, spacing: 10) {
                    PreferenceToggle(title: legacyAutomaticCheckLabel, isOn: $automaticChecks)
                    PreferenceToggle(title: legacyIncludePreReleasesLabel, isOn: $preReleases)
                        .disabled(!automaticChecks)
                    PreferenceToggle(title: legacyAutomaticallyInstallUpdatesLabel, isOn: $automaticallyInstallUpdates)
                        .disabled(!automaticChecks)
                    PreferenceRow(legacyUpdateIntervalLabel) {
                        PreferencePicker(
                            selection: Binding(
                                get: { visibleIntervalSelection },
                                set: { interval = $0 }
                            ),
                            width: 220
                        ) {
                            ForEach(CMVisibleUpdateIntervalOptions(), id: \.value) { option in
                                Text(option.title).tag(option.value)
                            }
                        }
                        .disabled(!automaticChecks)
                    }
                    if automaticChecks && showsImportedIntervalNotice {
                        Text(CMImportedUpdateIntervalNoticeTitle(for: interval))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            PreferenceSection(NSLocalizedString("Status", comment: "")) {
                VStack(alignment: .leading, spacing: 10) {
                    PreferenceRow(NSLocalizedString("Feed", comment: "")) {
                        UpdateStatusBadge(
                            title: feedStatusTitle,
                            tint: feedStatusTint
                        )
                    }

                    PreferenceRow(NSLocalizedString("Last checked", comment: "")) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                UpdateStatusBadge(
                                    title: checkingStatusTitle,
                                    tint: checkingStatusTint
                                )

                                Text(updateCoordinator.lastCheckDate.map(Self.lastCheckDateFormatter.string(from:)) ?? CMUpdatesNeverCheckedDisplayTitle())
                                    .font(.system(.body, design: .rounded).monospacedDigit())
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer(minLength: 0)

                            if updateCoordinator.isChecking {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }

                    PreferenceRow("") {
                        Button {
                            updateCoordinator.checkForUpdates()
                        } label: {
                            Label(legacyCheckNowLabel, systemImage: "arrow.clockwise.circle")
                        }
                        .disabled(!automaticChecks || updateCoordinator.feedURL == nil || updateCoordinator.isChecking)
                    }
                }
            }
        }
    }

    private var feedStatusTitle: String {
        guard updateCoordinator.feedURL != nil else {
            return NSLocalizedString("Unavailable", comment: "")
        }
        return preReleases
            ? NSLocalizedString("Pre-release", comment: "")
            : NSLocalizedString("Stable", comment: "")
    }

    private var feedStatusTint: Color {
        guard updateCoordinator.feedURL != nil else {
            return .secondary
        }
        return preReleases ? .orange : .green
    }

    private var checkingStatusTitle: String {
        if updateCoordinator.isChecking {
            return NSLocalizedString("Checking now", comment: "")
        }
        return automaticChecks
            ? NSLocalizedString("Automatic checks on", comment: "")
            : NSLocalizedString("Manual only", comment: "")
    }

    private var checkingStatusTint: Color {
        if updateCoordinator.isChecking {
            return .blue
        }
        return automaticChecks ? .green : .secondary
    }

    private var visibleIntervalSelection: Int {
        CMVisibleUpdateIntervalSelectionValue(for: interval)
    }
    private var showsImportedIntervalNotice: Bool {
        CMVisibleUpdateIntervalOptions().contains(where: { $0.value == interval }) == false
    }

    private static let lastCheckDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct CMUpdateIntervalOption {
    let value: Int
    let title: String
}

func CMUpdateIntervalOptions() -> [CMUpdateIntervalOption] {
    [
        CMUpdateIntervalOption(value: 60, title: NSLocalizedString("Every minute", comment: "")),
        CMUpdateIntervalOption(value: 300, title: NSLocalizedString("Every 5 minutes", comment: "")),
        CMUpdateIntervalOption(value: 600, title: NSLocalizedString("Every 10 minutes", comment: "")),
        CMUpdateIntervalOption(value: 1_800, title: NSLocalizedString("Every 30 minutes", comment: "")),
        CMUpdateIntervalOption(value: 3_600, title: NSLocalizedString("Every hour", comment: "")),
        CMUpdateIntervalOption(value: 10_800, title: NSLocalizedString("Every 3 hours", comment: "")),
        CMUpdateIntervalOption(value: 21_600, title: NSLocalizedString("Every 6 hours", comment: "")),
        CMUpdateIntervalOption(value: 43_200, title: NSLocalizedString("Every 12 hours", comment: "")),
        CMUpdateIntervalOption(value: 86_400, title: NSLocalizedString("1353.title", tableName: "Preferences", bundle: .main, value: "Daily", comment: "")),
        CMUpdateIntervalOption(value: 604_800, title: NSLocalizedString("1354.title", tableName: "Preferences", bundle: .main, value: "Weekly", comment: "")),
        CMUpdateIntervalOption(value: 2_592_000, title: NSLocalizedString("1355.title", tableName: "Preferences", bundle: .main, value: "Monthly", comment: "")),
        CMUpdateIntervalOption(value: 0, title: NSLocalizedString("1285.title", tableName: "Preferences", bundle: .main, value: "Never", comment: ""))
    ]
}

func CMVisibleUpdateIntervalOptions() -> [CMUpdateIntervalOption] {
    [
        CMUpdateIntervalOption(value: 86_400, title: NSLocalizedString("1353.title", tableName: "Preferences", bundle: .main, value: "Daily", comment: "")),
        CMUpdateIntervalOption(value: 604_800, title: NSLocalizedString("1354.title", tableName: "Preferences", bundle: .main, value: "Weekly", comment: "")),
        CMUpdateIntervalOption(value: 2_592_000, title: NSLocalizedString("1355.title", tableName: "Preferences", bundle: .main, value: "Monthly", comment: ""))
    ]
}

func CMVisibleUpdateIntervalSelectionValue(for value: Int) -> Int {
    CMVisibleUpdateIntervalOptions().first(where: { $0.value == value })?.value ?? 86_400
}

func CMUpdateIntervalTitle(for value: Int) -> String {
    CMUpdateIntervalOptions().first(where: { $0.value == value })?.title
        ?? NSLocalizedString("1353.title", tableName: "Preferences", bundle: .main, value: "Daily", comment: "")
}

func CMImportedUpdateIntervalNoticeTitle(for value: Int) -> String {
    String(
        format: NSLocalizedString(
            "Imported legacy interval: %@. Choose Daily, Weekly, or Monthly to replace it.",
            comment: ""
        ),
        CMUpdateIntervalTitle(for: value)
    )
}

struct SnippetFolder: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var isEnabled: Bool
    var snippets: [Snippet]
}

struct Snippet: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var content: String
    var isEnabled: Bool
}

fileprivate func CMNormalizedSnippet(_ snippet: Snippet, replacing oldValue: Snippet) -> Snippet {
    var normalized = snippet
    if normalized.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        normalized.title = oldValue.title.isEmpty ? NSLocalizedString("untitled snippet", comment: "") : oldValue.title
    }
    if normalized.title != oldValue.title,
       normalized.content.isEmpty,
       normalized.title != NSLocalizedString("untitled snippet", comment: "") {
        normalized.content = normalized.title
    }
    return normalized
}

fileprivate func CMNormalizedSnippetFolder(_ folder: SnippetFolder, replacing oldValue: SnippetFolder) -> SnippetFolder {
    var normalized = folder
    if normalized.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        normalized.title = oldValue.title.isEmpty ? NSLocalizedString("untitled folder", comment: "") : oldValue.title
    }
    return normalized
}

private let CMSnippetFolderDragPasteboardType = NSPasteboard.PasteboardType("com.naotaka.ClipMenu.snippet-folder-row")

private func CMMakeSnippetFolderDragPayload(folderIDs: [UUID]) -> String {
    folderIDs.map(\.uuidString).joined(separator: "\t")
}

private func CMParseSnippetFolderDragPayload(_ payload: String) -> [UUID] {
    payload.split(separator: "\t").compactMap { UUID(uuidString: String($0)) }
}

private func CMSnippetFolderAcceptsFolderReorderDrop(
    proposedChildIndex: Int,
    draggingSource: Any?
) -> Bool {
    proposedChildIndex != -1 && draggingSource is CMSnippetFolderOutlineView
}

private func CMSnippetFolderAcceptsSnippetDrop(
    proposedItem: Any?,
    proposedChildIndex: Int,
    draggingSource: Any?
) -> Bool {
    proposedItem is UUID
        && proposedChildIndex == -1
        && draggingSource is CMSnippetTableView
}

final class SnippetFileStore: ObservableObject {
    static let shared = SnippetFileStore()
    let undoManager = UndoManager()

    @Published var folders: [SnippetFolder] = [] {
        didSet {
            updateUnsavedChanges()
        }
    }
    @Published private(set) var hasUnsavedChanges = false
    @Published var selectedFolderIDs: Set<UUID> = [] {
        didSet {
            guard !isNormalizingFolderSelection else { return }
            normalizeFolderSelection()
        }
    }
    @Published var selectedSnippetIDs: Set<UUID> = [] {
        didSet {
            guard !isNormalizingSnippetSelection else { return }
            normalizeSnippetSelection()
        }
    }

    private var primarySelectedFolderID: UUID?
    private var primarySelectedSnippetID: UUID?
    private var isNormalizingFolderSelection = false
    private var isNormalizingSnippetSelection = false
    private var persistedFolders: [SnippetFolder] = []

    struct SelectionSnapshot {
        var selectedFolderIDs: Set<UUID>
        var selectedSnippetIDs: Set<UUID>
        var primarySelectedFolderID: UUID?
        var primarySelectedSnippetID: UUID?
    }

    private struct Snapshot {
        var folders: [SnippetFolder]
        var selectedFolderIDs: Set<UUID>
        var selectedSnippetIDs: Set<UUID>
        var primarySelectedFolderID: UUID?
        var primarySelectedSnippetID: UUID?
    }

    private var supportDirectory: URL {
        clipMenuApplicationSupportDirectory()
    }

    private var fileURL: URL {
        supportDirectory.appendingPathComponent("Snippets.xml")
    }

    private var jsonFileURL: URL {
        supportDirectory.appendingPathComponent("snippets.json")
    }

    init() {
        reload()
    }

    var selectedFolderID: UUID? { primarySelectedFolderID }
    var selectedSnippetID: UUID? { primarySelectedSnippetID }
    var hasSingleSelectedFolder: Bool { selectedFolderIDs.count == 1 && selectedFolderIndex != nil }
    var hasSingleSelectedSnippet: Bool { selectedSnippetIDs.count == 1 && selectedSnippetIndex != nil }
    var menuFolders: [SnippetFolder] { folders }

    func currentSelectionSnapshot() -> SelectionSnapshot {
        SelectionSnapshot(
            selectedFolderIDs: selectedFolderIDs,
            selectedSnippetIDs: selectedSnippetIDs,
            primarySelectedFolderID: primarySelectedFolderID,
            primarySelectedSnippetID: primarySelectedSnippetID
        )
    }

    func restoreSelectionSnapshot(_ snapshot: SelectionSnapshot) {
        applyFolderSelection(snapshot.selectedFolderIDs, primary: snapshot.primarySelectedFolderID)
        applySnippetSelection(snapshot.selectedSnippetIDs, primary: snapshot.primarySelectedSnippetID)
    }

    private func currentSnapshot() -> Snapshot {
        Snapshot(
            folders: folders,
            selectedFolderIDs: selectedFolderIDs,
            selectedSnippetIDs: selectedSnippetIDs,
            primarySelectedFolderID: primarySelectedFolderID,
            primarySelectedSnippetID: primarySelectedSnippetID
        )
    }

    private func registerUndoSnapshot() {
        let snapshot = currentSnapshot()
        undoManager.registerUndo(withTarget: self) { target in
            target.restoreSnapshot(snapshot)
        }
    }

    private func restoreSnapshot(_ snapshot: Snapshot) {
        let redoSnapshot = currentSnapshot()
        folders = snapshot.folders
        applyFolderSelection(snapshot.selectedFolderIDs, primary: snapshot.primarySelectedFolderID)
        applySnippetSelection(snapshot.selectedSnippetIDs, primary: snapshot.primarySelectedSnippetID)
        updateUnsavedChanges()
        undoManager.registerUndo(withTarget: self) { target in
            target.restoreSnapshot(redoSnapshot)
        }
    }

    func load() -> [SnippetFolder] {
        if shouldPreferJSONStore(),
           let jsonFolders = loadJSONSnippets() {
            folders = jsonFolders
            persistedFolders = jsonFolders
            updateUnsavedChanges()
            save()
            return jsonFolders
        }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let xmlFolders = try? importSnippets(from: fileURL, preservingMetadata: true, allowEmpty: true) {
                let stabilizedFolders = reusingIdentity(from: !persistedFolders.isEmpty ? persistedFolders : folders, to: xmlFolders)
                folders = stabilizedFolders
                persistedFolders = stabilizedFolders
                updateUnsavedChanges()
                return stabilizedFolders
            }

            if let legacyFolders = loadLegacySnippets() {
                folders = legacyFolders
                persistedFolders = legacyFolders
                updateUnsavedChanges()
                save()
                return legacyFolders
            }
        }

        if let decoded = loadJSONSnippets() {
            folders = decoded
            persistedFolders = decoded
            updateUnsavedChanges()
            save()
            return decoded
        }

        persistedFolders = []
        updateUnsavedChanges()
        return []
    }

    func reload() {
        folders = load()
        undoManager.removeAllActions()
        if selectedFolderID == nil || selectedFolderIndex == nil {
            let folderID = folders.first?.id
            applyFolderSelection(folderID.map { [$0] } ?? [], primary: folderID)
        } else {
            normalizeFolderSelection()
        }
        if selectedSnippetID == nil || selectedSnippetIndex == nil {
            let snippetID = selectedFolderIndex.flatMap { folders[$0].snippets.first?.id }
            applySnippetSelection(snippetID.map { [$0] } ?? [], primary: snippetID)
        } else {
            normalizeSnippetSelection()
        }
    }

    private func applyFolderSelection(_ ids: Set<UUID>, primary: UUID? = nil) {
        primarySelectedFolderID = primary
        selectedFolderIDs = ids
    }

    private func applySnippetSelection(_ ids: Set<UUID>, primary: UUID? = nil) {
        primarySelectedSnippetID = primary
        selectedSnippetIDs = ids
    }

    func notePrimaryFolder(_ id: UUID) {
        primarySelectedFolderID = id
        if selectedFolderIDs.count == 1, !selectedFolderIDs.contains(id) {
            applyFolderSelection([id], primary: id)
        }
    }

    func notePrimarySnippet(_ id: UUID) {
        primarySelectedSnippetID = id
        if selectedSnippetIDs.count == 1, !selectedSnippetIDs.contains(id) {
            applySnippetSelection([id], primary: id)
        }
    }

    private func orderedSelectedFolderIDs(from ids: Set<UUID>? = nil) -> [UUID] {
        let ids = ids ?? selectedFolderIDs
        return folders.map(\.id).filter(ids.contains)
    }

    private func orderedSelectedSnippetIDs(
        in folderIndex: Int? = nil,
        from ids: Set<UUID>? = nil
    ) -> [UUID] {
        guard let folderIndex = folderIndex ?? selectedFolderIndex else { return [] }
        let ids = ids ?? selectedSnippetIDs
        return folders[folderIndex].snippets.map(\.id).filter(ids.contains)
    }

    private func normalizeFolderSelection() {
        isNormalizingFolderSelection = true
        defer { isNormalizingFolderSelection = false }

        let validIDs = Set(folders.map(\.id))
        let filtered = selectedFolderIDs.intersection(validIDs)
        if filtered != selectedFolderIDs {
            selectedFolderIDs = filtered
        }

        if let primarySelectedFolderID, filtered.contains(primarySelectedFolderID) {
            // keep current primary selection
        } else {
            primarySelectedFolderID = orderedSelectedFolderIDs(from: filtered).first
        }

        if filtered.count != 1 {
            applySnippetSelection([], primary: nil)
        } else {
            normalizeSnippetSelection()
        }
    }

    private func normalizeSnippetSelection() {
        isNormalizingSnippetSelection = true
        defer { isNormalizingSnippetSelection = false }

        guard let folderIndex = selectedFolderIndex else {
            if !selectedSnippetIDs.isEmpty {
                selectedSnippetIDs = []
            }
            primarySelectedSnippetID = nil
            return
        }

        let validIDs = Set(folders[folderIndex].snippets.map(\.id))
        let filtered = selectedSnippetIDs.intersection(validIDs)
        if filtered != selectedSnippetIDs {
            selectedSnippetIDs = filtered
        }

        if let primarySelectedSnippetID, filtered.contains(primarySelectedSnippetID) {
            // keep current primary selection
        } else {
            primarySelectedSnippetID = orderedSelectedSnippetIDs(in: folderIndex, from: filtered).first
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(folders)
            try data.write(to: jsonFileURL, options: .atomic)
            try exportSnippets(to: fileURL, includeMetadata: true)
            persistedFolders = folders
            updateUnsavedChanges()
        } catch {
            showSnippetAlert(
                NSLocalizedString("Could not save snippets.", comment: ""),
                informativeText: error.localizedDescription
            )
        }
    }

    private func updateUnsavedChanges() {
        hasUnsavedChanges = folders != persistedFolders
    }

    private func reusingIdentity(from referenceFolders: [SnippetFolder], to loadedFolders: [SnippetFolder]) -> [SnippetFolder] {
        loadedFolders.enumerated().map { folderOffset, folder in
            guard referenceFolders.indices.contains(folderOffset) else {
                return folder
            }

            let referenceFolder = referenceFolders[folderOffset]
            var stabilizedFolder = folder
            stabilizedFolder.id = referenceFolder.id
            stabilizedFolder.snippets = folder.snippets.enumerated().map { snippetOffset, snippet in
                guard referenceFolder.snippets.indices.contains(snippetOffset) else {
                    return snippet
                }

                var stabilizedSnippet = snippet
                stabilizedSnippet.id = referenceFolder.snippets[snippetOffset].id
                return stabilizedSnippet
            }
            return stabilizedFolder
        }
    }

    private func loadJSONSnippets() -> [SnippetFolder]? {
        guard let data = try? Data(contentsOf: jsonFileURL),
              let decoded = try? JSONDecoder().decode([SnippetFolder].self, from: data) else {
            return nil
        }
        return decoded
    }

    private func shouldPreferJSONStore() -> Bool {
        guard FileManager.default.fileExists(atPath: jsonFileURL.path) else { return false }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return true }
        guard let jsonDate = modificationDate(for: jsonFileURL),
              let xmlDate = modificationDate(for: fileURL) else {
            return false
        }
        return jsonDate > xmlDate
    }

    private func modificationDate(for url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
    }

    private func loadLegacySnippets() -> [SnippetFolder]? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        let model = Self.loadLegacySnippetModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        do {
            try coordinator.addPersistentStore(
                ofType: NSXMLStoreType,
                configurationName: nil,
                at: fileURL,
                options: [NSReadOnlyPersistentStoreOption: true]
            )
        } catch {
            if let coreDataXMLFolders = try? importLegacyCoreDataSnippets(from: fileURL) {
                return coreDataXMLFolders
            }
            if let exportedFolders = try? importSnippets(from: fileURL, preservingMetadata: true, allowEmpty: true) {
                return exportedFolders
            }
            NSLog("ClipMenu failed to load legacy Snippets.xml: \(error.localizedDescription)")
            return nil
        }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        var result: [SnippetFolder] = []
        context.performAndWait {
            let folderRequest = NSFetchRequest<NSManagedObject>(entityName: "Folder")
            folderRequest.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]

            do {
                let legacyFolders = try context.fetch(folderRequest)
                result = legacyFolders.map { folder in
                    let snippetsSet = folder.value(forKey: "snippets") as? Set<NSManagedObject> ?? []
                    let snippets = snippetsSet.sorted {
                        ($0.value(forKey: "index") as? Int ?? 0) < ($1.value(forKey: "index") as? Int ?? 0)
                    }.map { snippet in
                        Snippet(
                            title: snippet.value(forKey: "title") as? String ?? "",
                            content: snippet.value(forKey: "content") as? String ?? "",
                            isEnabled: snippet.value(forKey: "enabled") as? Bool ?? true
                        )
                    }

                    return SnippetFolder(
                        title: folder.value(forKey: "title") as? String ?? "",
                        isEnabled: folder.value(forKey: "enabled") as? Bool ?? true,
                        snippets: snippets
                    )
                }
            } catch {
                NSLog("ClipMenu failed to migrate legacy snippets: \(error.localizedDescription)")
            }
        }

        return result
    }

    private func importLegacyCoreDataSnippets(from url: URL) throws -> [SnippetFolder] {
        let document = try XMLDocument(contentsOf: url, options: [])
        guard let root = document.rootElement(), root.name == "database" else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var snippetsByID: [String: (index: Int, snippet: Snippet)] = [:]
        var folders: [(offset: Int, index: Int, folder: SnippetFolder)] = []

        for (offset, object) in root.elements(forName: "object").enumerated() {
            guard let type = object.attribute(forName: "type")?.stringValue,
                  let objectID = object.attribute(forName: "id")?.stringValue else {
                continue
            }

            switch type.uppercased() {
            case "SNIPPET":
                snippetsByID[objectID] = (
                    index: Self.legacyAttributeInt(named: "index", in: object) ?? offset,
                    snippet: Snippet(
                        title: Self.legacyAttributeText(named: "title", in: object) ?? "",
                        content: Self.legacyAttributeText(named: "content", in: object) ?? "",
                        isEnabled: Self.legacyAttributeBool(named: "enabled", in: object) ?? true
                    )
                )
            default:
                continue
            }
        }

        for (offset, object) in root.elements(forName: "object").enumerated() {
            guard object.attribute(forName: "type")?.stringValue?.uppercased() == "FOLDER" else {
                continue
            }

            let idrefs = object.elements(forName: "relationship")
                .first { $0.attribute(forName: "name")?.stringValue == "snippets" }?
                .attribute(forName: "idrefs")?
                .stringValue?
                .split { $0.isWhitespace }
                .map(String.init) ?? []

            let snippets = idrefs.enumerated()
                .compactMap { idrefOffset, idref -> (offset: Int, index: Int, snippet: Snippet)? in
                    guard let entry = snippetsByID[idref] else { return nil }
                    return (offset: idrefOffset, index: entry.index, snippet: entry.snippet)
                }
                .sorted { $0.index == $1.index ? $0.offset < $1.offset : $0.index < $1.index }
                .map(\.snippet)

            folders.append((
                offset: offset,
                index: Self.legacyAttributeInt(named: "index", in: object) ?? offset,
                folder: SnippetFolder(
                    title: Self.legacyAttributeText(named: "title", in: object) ?? "",
                    isEnabled: Self.legacyAttributeBool(named: "enabled", in: object) ?? true,
                    snippets: snippets
                )
            ))
        }

        let sortedFolders = folders
            .sorted { $0.index == $1.index ? $0.offset < $1.offset : $0.index < $1.index }
            .map(\.folder)
        guard !sortedFolders.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return sortedFolders
    }

    private static func loadLegacySnippetModel() -> NSManagedObjectModel {
        if let bundledModelURL = Bundle.main.url(forResource: "Snippets", withExtension: "mom"),
           let bundledModel = NSManagedObjectModel(contentsOf: bundledModelURL) {
            return bundledModel
        }
        return makeLegacySnippetModel()
    }

    private static func makeLegacySnippetModel() -> NSManagedObjectModel {
        let folderEntity = NSEntityDescription()
        folderEntity.name = "Folder"
        folderEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let snippetEntity = NSEntityDescription()
        snippetEntity.name = "Snippet"
        snippetEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let folderTitle = stringAttribute(name: "title", defaultValue: "untitled folder", isOptional: false)
        let folderEnabled = boolAttribute(name: "enabled")
        let folderIndex = integerAttribute(name: "index")

        let snippetTitle = stringAttribute(name: "title", defaultValue: "untitled snippet", isOptional: false)
        let snippetContent = stringAttribute(name: "content", defaultValue: nil)
        let snippetEnabled = boolAttribute(name: "enabled")
        let snippetIndex = integerAttribute(name: "index")

        let snippetsRelationship = NSRelationshipDescription()
        snippetsRelationship.name = "snippets"
        snippetsRelationship.destinationEntity = snippetEntity
        snippetsRelationship.minCount = 0
        snippetsRelationship.maxCount = 0
        snippetsRelationship.deleteRule = .cascadeDeleteRule
        snippetsRelationship.isOptional = true

        let folderRelationship = NSRelationshipDescription()
        folderRelationship.name = "folder"
        folderRelationship.destinationEntity = folderEntity
        folderRelationship.minCount = 1
        folderRelationship.maxCount = 1
        folderRelationship.deleteRule = .nullifyDeleteRule
        folderRelationship.isOptional = true

        snippetsRelationship.inverseRelationship = folderRelationship
        folderRelationship.inverseRelationship = snippetsRelationship

        folderEntity.properties = [folderTitle, folderEnabled, folderIndex, snippetsRelationship]
        snippetEntity.properties = [snippetTitle, snippetContent, snippetEnabled, snippetIndex, folderRelationship]

        let model = NSManagedObjectModel()
        model.entities = [folderEntity, snippetEntity]
        return model
    }

    private static func stringAttribute(name: String, defaultValue: String?, isOptional: Bool = true) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .stringAttributeType
        attribute.defaultValue = defaultValue
        attribute.isOptional = isOptional
        return attribute
    }

    private static func boolAttribute(name: String) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .booleanAttributeType
        attribute.defaultValue = true
        attribute.isOptional = true
        return attribute
    }

    private static func integerAttribute(name: String) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .integer16AttributeType
        attribute.defaultValue = 0
        attribute.isOptional = false
        return attribute
    }

    func importSnippetsFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.xml]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        beginSnippetPanel(panel) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.finishSnippetImport(from: url)
        }
    }

    func exportSnippetsToPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.xml]
        panel.canSelectHiddenExtension = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        panel.nameFieldStringValue = "snippets"

        beginSnippetPanel(panel) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.finishSnippetExport(to: url)
        }
    }

    private func beginSnippetPanel(_ panel: NSSavePanel, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window = NSApp.keyWindow ?? NSApp.mainWindow,
           window.isVisible {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    func importSnippets(from url: URL) {
        finishSnippetImport(from: url)
    }

    private func finishSnippetImport(from url: URL) {
        do {
            let importedFolders = try importSnippets(from: url, preservingMetadata: false, allowEmpty: false)
            let previousFolderID = selectedFolderID
            let previousSnippetID = selectedSnippetID
            registerUndoSnapshot()
            folders.append(contentsOf: importedFolders)
            if previousFolderID.flatMap({ id in folders.firstIndex { $0.id == id } }) != nil {
                applyFolderSelection(previousFolderID.map { [$0] } ?? [], primary: previousFolderID)
                applySnippetSelection(previousSnippetID.map { [$0] } ?? [], primary: previousSnippetID)
            } else if selectedFolderID == nil {
                let folderID = folders.first?.id
                let snippetID = folderID.flatMap { id in
                    folders.firstIndex { $0.id == id }.flatMap { folders[$0].snippets.first?.id }
                }
                applyFolderSelection(folderID.map { [$0] } ?? [], primary: folderID)
                applySnippetSelection(snippetID.map { [$0] } ?? [], primary: snippetID)
            }
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            showSnippetAlert(
                NSLocalizedString("Failed to parse XML file", comment: ""),
                informativeText: error.localizedDescription
            )
        }
    }

    private func finishSnippetExport(to url: URL) {
        do {
            try exportSnippets(to: url, includeMetadata: false)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            showSnippetAlert(
                NSLocalizedString("Could not write document out...", comment: ""),
                informativeText: error.localizedDescription
            )
        }
    }

    private func importSnippets(from url: URL, preservingMetadata: Bool, allowEmpty: Bool) throws -> [SnippetFolder] {
        let document = try XMLDocument(contentsOf: url, options: [])
        guard let root = document.rootElement(), root.name == "folders" else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let importedFolders = root.elements(forName: "folder").enumerated().map { folderOffset, folderElement -> (offset: Int, index: Int, folder: SnippetFolder) in
            let snippetsElement = folderElement.elements(forName: "snippets").first
            let importedSnippets = (snippetsElement?.elements(forName: "snippet") ?? []).enumerated().map { snippetOffset, snippetElement -> (offset: Int, index: Int, snippet: Snippet) in
                let snippet = Snippet(
                    title: Self.childText(named: "title", in: snippetElement) ?? "",
                    content: Self.childText(named: "content", in: snippetElement) ?? "",
                    isEnabled: preservingMetadata ? (Self.childBool(named: "enabled", in: snippetElement) ?? true) : true
                )
                return (
                    offset: snippetOffset,
                    index: preservingMetadata ? (Self.childInt(named: "index", in: snippetElement) ?? snippetOffset) : snippetOffset,
                    snippet: snippet
                )
            }
            let snippets = importedSnippets
                .sorted { $0.index == $1.index ? $0.offset < $1.offset : $0.index < $1.index }
                .map(\.snippet)

            let folder = SnippetFolder(
                title: Self.childText(named: "title", in: folderElement) ?? "",
                isEnabled: preservingMetadata ? (Self.childBool(named: "enabled", in: folderElement) ?? true) : true,
                snippets: snippets
            )

            return (
                offset: folderOffset,
                index: preservingMetadata ? (Self.childInt(named: "index", in: folderElement) ?? folderOffset) : folderOffset,
                folder: folder
            )
        }

        let folders = importedFolders
            .sorted { $0.index == $1.index ? $0.offset < $1.offset : $0.index < $1.index }
            .map(\.folder)
        guard allowEmpty || !folders.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return folders
    }

    private func exportSnippets(to url: URL, includeMetadata: Bool, sourceFolders: [SnippetFolder]? = nil) throws {
        let data = makeSnippetXMLDocument(includeMetadata: includeMetadata, sourceFolders: sourceFolders).xmlData(options: [.nodePrettyPrint])
        try data.write(to: url, options: .atomic)
    }

    private func makeSnippetXMLDocument(includeMetadata: Bool, sourceFolders: [SnippetFolder]? = nil) -> XMLDocument {
        let sourceFolders = sourceFolders ?? folders
        let root = XMLElement(name: "folders")
        for (folderIndex, folder) in sourceFolders.enumerated() {
            let folderElement = XMLElement(name: "folder")
            if includeMetadata {
                folderElement.addChild(XMLElement(name: "index", stringValue: "\(folderIndex)"))
                folderElement.addChild(XMLElement(name: "enabled", stringValue: folder.isEnabled ? "1" : "0"))
            }
            folderElement.addChild(XMLElement(name: "title", stringValue: folder.title))

            let snippetsElement = XMLElement(name: "snippets")
            for (snippetIndex, snippet) in folder.snippets.enumerated() {
                let snippetElement = XMLElement(name: "snippet")
                if includeMetadata {
                    snippetElement.addChild(XMLElement(name: "index", stringValue: "\(snippetIndex)"))
                    snippetElement.addChild(XMLElement(name: "enabled", stringValue: snippet.isEnabled ? "1" : "0"))
                }
                snippetElement.addChild(XMLElement(name: "title", stringValue: snippet.title))
                let contentElement = XMLNode(kind: .element, options: [.nodePreserveWhitespace])
                contentElement.name = "content"
                contentElement.stringValue = snippet.content
                snippetElement.addChild(contentElement)
                snippetsElement.addChild(snippetElement)
            }

            folderElement.addChild(snippetsElement)
            root.addChild(folderElement)
        }

        let document = XMLDocument(rootElement: root)
        document.version = "1.0"
        document.characterEncoding = "UTF-8"
        return document
    }

#if DEBUG
    func debugEmptyExportReport() -> [String: Any] {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipmenu-empty-snippet-export.xml")
        do {
            try exportSnippets(to: temporaryURL, includeMetadata: false, sourceFolders: [])
            let data = try Data(contentsOf: temporaryURL)
            let document = try XMLDocument(data: data)
            let rootName = document.rootElement()?.name ?? ""
            let folderElements = document.rootElement()?.elements(forName: "folder") ?? []
            let xmlString = String(data: data, encoding: .utf8) ?? ""
            return [
                "exportedFileExists": FileManager.default.fileExists(atPath: temporaryURL.path),
                "rootName": rootName,
                "folderCount": folderElements.count,
                "xmlContainsFoldersRoot": xmlString.contains("<folders"),
                "matchesExpected": rootName == "folders" && folderElements.isEmpty && !data.isEmpty
            ]
        } catch {
            return [
                "error": error.localizedDescription,
                "matchesExpected": false
            ]
        }
    }

    func debugManualExportImportReport() -> [String: Any] {
        let fixtureFolders = [
            SnippetFolder(
                title: "Export Alpha",
                isEnabled: false,
                snippets: [
                    Snippet(title: "First Snippet", content: "first line\nsecond line", isEnabled: false),
                    Snippet(title: "Second Snippet", content: "", isEnabled: true)
                ]
            ),
            SnippetFolder(
                title: "Export Beta",
                isEnabled: true,
                snippets: [
                    Snippet(title: "Beta Snippet", content: "beta body", isEnabled: false)
                ]
            )
        ]
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipmenu-manual-snippet-export-\(UUID().uuidString).xml")
        let invalidURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipmenu-invalid-snippet-import-\(UUID().uuidString).xml")
        defer {
            try? FileManager.default.removeItem(at: exportURL)
            try? FileManager.default.removeItem(at: invalidURL)
        }

        func elementChildNames(_ element: XMLElement) -> [String] {
            (element.children ?? []).compactMap { child in
                child.kind == .element ? child.name : nil
            }
        }

        var report: [String: Any] = [
            "fixtureFolderTitles": fixtureFolders.map(\.title),
            "fixtureFolderEnabledStates": fixtureFolders.map(\.isEnabled),
            "fixtureSnippetTitlesByFolder": fixtureFolders.map { $0.snippets.map(\.title) },
            "fixtureSnippetContentsByFolder": fixtureFolders.map { $0.snippets.map(\.content) },
            "fixtureSnippetEnabledStatesByFolder": fixtureFolders.map { $0.snippets.map(\.isEnabled) }
        ]

        do {
            try exportSnippets(to: exportURL, includeMetadata: false, sourceFolders: fixtureFolders)
            let exportedData = try Data(contentsOf: exportURL)
            let exportedXML = String(data: exportedData, encoding: .utf8) ?? ""
            let document = try XMLDocument(contentsOf: exportURL, options: [])
            guard let root = document.rootElement() else {
                throw CocoaError(.fileReadCorruptFile)
            }

            let folderElements = root.elements(forName: "folder")
            let folderChildNames = folderElements.map(elementChildNames)
            let snippetChildNamesByFolder = folderElements.map { folderElement in
                folderElement.elements(forName: "snippets").first?.elements(forName: "snippet").map(elementChildNames) ?? []
            }
            let exportedFolderTitles = folderElements.compactMap { Self.childText(named: "title", in: $0) }
            let exportedSnippetTitlesByFolder = folderElements.map { folderElement in
                folderElement.elements(forName: "snippets").first?.elements(forName: "snippet").compactMap {
                    Self.childText(named: "title", in: $0)
                } ?? []
            }
            let exportedSnippetContentsByFolder = folderElements.map { folderElement in
                folderElement.elements(forName: "snippets").first?.elements(forName: "snippet").map {
                    Self.childText(named: "content", in: $0) ?? ""
                } ?? []
            }
            let metadataNodes = (try? document.nodes(forXPath: "//enabled | //index")) ?? []
            let importedFolders = try importSnippets(from: exportURL, preservingMetadata: false, allowEmpty: false)
            let importedFolderEnabledStates = importedFolders.map(\.isEnabled)
            let importedSnippetEnabledStatesByFolder = importedFolders.map { $0.snippets.map(\.isEnabled) }

            report["exportedXML"] = exportedXML
            report["rootElementName"] = root.name ?? ""
            report["folderChildNames"] = folderChildNames
            report["snippetChildNamesByFolder"] = snippetChildNamesByFolder
            report["exportedFolderTitles"] = exportedFolderTitles
            report["exportedSnippetTitlesByFolder"] = exportedSnippetTitlesByFolder
            report["exportedSnippetContentsByFolder"] = exportedSnippetContentsByFolder
            report["metadataNodeCount"] = metadataNodes.count
            report["exportContainsNoMetadataElements"] = metadataNodes.isEmpty
                && !exportedXML.contains("<enabled>")
                && !exportedXML.contains("<index>")
            report["folderStructureMatchesExpected"] = folderChildNames.allSatisfy { $0 == ["title", "snippets"] }
            report["snippetStructureMatchesExpected"] = snippetChildNamesByFolder.flatMap { $0 }.allSatisfy { $0 == ["title", "content"] }
            report["exportedOrderMatchesExpected"] = exportedFolderTitles == fixtureFolders.map(\.title)
                && exportedSnippetTitlesByFolder == fixtureFolders.map { $0.snippets.map(\.title) }
            report["exportedContentsMatchExpected"] = exportedSnippetContentsByFolder == fixtureFolders.map { $0.snippets.map(\.content) }
            report["manualExportMatchesExpected"] = (root.name == "folders")
                && folderChildNames.allSatisfy { $0 == ["title", "snippets"] }
                && snippetChildNamesByFolder.flatMap { $0 }.allSatisfy { $0 == ["title", "content"] }
                && metadataNodes.isEmpty
                && exportedFolderTitles == fixtureFolders.map(\.title)
                && exportedSnippetTitlesByFolder == fixtureFolders.map { $0.snippets.map(\.title) }
                && exportedSnippetContentsByFolder == fixtureFolders.map { $0.snippets.map(\.content) }
            report["importedFolderTitles"] = importedFolders.map(\.title)
            report["importedFolderEnabledStates"] = importedFolderEnabledStates
            report["importedSnippetTitlesByFolder"] = importedFolders.map { $0.snippets.map(\.title) }
            report["importedSnippetContentsByFolder"] = importedFolders.map { $0.snippets.map(\.content) }
            report["importedSnippetEnabledStatesByFolder"] = importedSnippetEnabledStatesByFolder
            report["manualImportMatchesExpected"] = importedFolders.map(\.title) == fixtureFolders.map(\.title)
                && importedFolders.map { $0.snippets.map(\.title) } == fixtureFolders.map { $0.snippets.map(\.title) }
                && importedFolders.map { $0.snippets.map(\.content) } == fixtureFolders.map { $0.snippets.map(\.content) }
                && importedFolderEnabledStates == Array(repeating: true, count: importedFolders.count)
                && importedSnippetEnabledStatesByFolder == importedFolders.map { Array(repeating: true, count: $0.snippets.count) }

            let baselineFolders = folders
            try "<folders><folder><title>Broken".write(to: invalidURL, atomically: true, encoding: .utf8)
            CMResetLastAlertForDebug()
            CMSetBypassAlertPresentationForDebug(true)
            finishSnippetImport(from: invalidURL)
            CMSetBypassAlertPresentationForDebug(false)
            let invalidImportAlert = CMLastAlertSnapshotForDebug()
            let foldersUnchangedAfterInvalidImport = folders == baselineFolders

            report["invalidImportAlert"] = invalidImportAlert as Any
            report["foldersUnchangedAfterInvalidImport"] = foldersUnchangedAfterInvalidImport
            report["invalidImportShowsExpectedAlert"] = (invalidImportAlert?["messageText"] as? String)
                == NSLocalizedString("Failed to parse XML file", comment: "")
                && ((invalidImportAlert?["buttonTitles"] as? [String]) ?? []) == [NSLocalizedString("OK", comment: "")]
                && foldersUnchangedAfterInvalidImport
            report["matchesExpected"] = (report["manualExportMatchesExpected"] as? Bool == true)
                && (report["manualImportMatchesExpected"] as? Bool == true)
                && (report["invalidImportShowsExpectedAlert"] as? Bool == true)
        } catch {
            report["error"] = error.localizedDescription
            report["matchesExpected"] = false
        }

        return report
    }
#endif

    private static func childText(named name: String, in element: XMLElement) -> String? {
        element.elements(forName: name).first?.stringValue
    }

    private static func childInt(named name: String, in element: XMLElement) -> Int? {
        guard let value = childText(named: name, in: element)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        return Int(value)
    }

    private static func childBool(named name: String, in element: XMLElement) -> Bool? {
        guard let value = childText(named: name, in: element)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !value.isEmpty else {
            return nil
        }

        switch value {
        case "1", "true", "yes":
            return true
        case "0", "false", "no":
            return false
        default:
            return nil
        }
    }

    private static func legacyAttributeText(named name: String, in element: XMLElement) -> String? {
        element.elements(forName: "attribute")
            .first { $0.attribute(forName: "name")?.stringValue == name }?
            .stringValue
    }

    private static func legacyAttributeInt(named name: String, in element: XMLElement) -> Int? {
        guard let value = legacyAttributeText(named: name, in: element)?
            .trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        return Int(value)
    }

    private static func legacyAttributeBool(named name: String, in element: XMLElement) -> Bool? {
        guard let value = legacyAttributeText(named: name, in: element)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !value.isEmpty else {
            return nil
        }

        switch value {
        case "1", "true", "yes":
            return true
        case "0", "false", "no":
            return false
        default:
            return nil
        }
    }

    private func showSnippetAlert(_ messageText: String, informativeText: String = "") {
        let alert: NSAlert
        switch messageText {
        case NSLocalizedString("Could not save snippets.", comment: ""):
            let error = NSError(domain: "ClipMenu.Snippets", code: 1, userInfo: [
                NSLocalizedDescriptionKey: informativeText
            ])
            alert = CMMakeSnippetSaveFailureAlert(error)
        case NSLocalizedString("Failed to parse XML file", comment: ""):
            let error = NSError(domain: "ClipMenu.Snippets", code: 2, userInfo: [
                NSLocalizedDescriptionKey: informativeText
            ])
            alert = CMMakeSnippetImportFailureAlert(error)
        case NSLocalizedString("Could not write document out...", comment: ""):
            let error = NSError(domain: "ClipMenu.Snippets", code: 3, userInfo: [
                NSLocalizedDescriptionKey: informativeText
            ])
            alert = CMMakeSnippetExportFailureAlert(error)
        default:
            alert = CMMakeGenericSnippetAlert(
                messageText: messageText,
                informativeText: informativeText
            )
        }
        CMShowAlert(alert, sheetFor: NSApp.keyWindow ?? NSApp.mainWindow)
    }

    func updateFolder(id: UUID, to newValue: SnippetFolder) {
        guard let index = folders.firstIndex(where: { $0.id == id }),
              folders[index] != newValue else {
            return
        }
        registerUndoSnapshot()
        folders[index] = newValue
    }

    func updateSnippet(folderID: UUID, snippetID: UUID, to newValue: Snippet) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderID }),
              let snippetIndex = folders[folderIndex].snippets.firstIndex(where: { $0.id == snippetID }),
              folders[folderIndex].snippets[snippetIndex] != newValue else {
            return
        }
        registerUndoSnapshot()
        folders[folderIndex].snippets[snippetIndex] = newValue
    }

    var selectedFolderIndex: Int? {
        guard let id = selectedFolderID else { return nil }
        return folders.firstIndex { $0.id == id }
    }

    var selectedSnippetIndex: Int? {
        guard let folderIndex = selectedFolderIndex, let id = selectedSnippetID else { return nil }
        return folders[folderIndex].snippets.firstIndex { $0.id == id }
    }

    private func replacementFolderID(afterRemovingFolderAt index: Int) -> UUID? {
        guard !folders.isEmpty else { return nil }
        let replacementIndex = min(index, folders.count - 1)
        return folders[replacementIndex].id
    }

    private func replacementSnippetID(in folderIndex: Int, afterRemovingSnippetAt index: Int) -> UUID? {
        let snippets = folders[folderIndex].snippets
        guard !snippets.isEmpty else { return nil }
        let replacementIndex = min(index, snippets.count - 1)
        return snippets[replacementIndex].id
    }

    @discardableResult
    func addFolder() -> UUID {
        registerUndoSnapshot()
        let folder = SnippetFolder(title: NSLocalizedString("untitled folder", comment: ""), isEnabled: true, snippets: [])
        folders.append(folder)
        applyFolderSelection([folder.id], primary: folder.id)
        applySnippetSelection([], primary: nil)
        return folder.id
    }

    func removeSelectedFolder() {
        let selectedIDs = orderedSelectedFolderIDs()
        guard !selectedIDs.isEmpty else { return }
        registerUndoSnapshot()
        let selectedIndexes = selectedIDs.compactMap { id in
            folders.firstIndex { $0.id == id }
        }
        guard let firstRemovedIndex = selectedIndexes.min() else { return }
        for index in selectedIndexes.sorted(by: >) {
            folders.remove(at: index)
        }

        let folderID = replacementFolderID(afterRemovingFolderAt: firstRemovedIndex)
        let snippetID = folderID.flatMap { id in
            folders.firstIndex { $0.id == id }.flatMap { folders[$0].snippets.first?.id }
        }
        applyFolderSelection(folderID.map { [$0] } ?? [], primary: folderID)
        applySnippetSelection(snippetID.map { [$0] } ?? [], primary: snippetID)
    }

    func toggleSelectedFolderEnabled() {
        let selectedIDs = orderedSelectedFolderIDs()
        guard let firstID = selectedIDs.first,
              let index = folders.firstIndex(where: { $0.id == firstID }) else { return }
        registerUndoSnapshot()
        let newValue = !folders[index].isEnabled
        for id in selectedIDs {
            guard let folderIndex = folders.firstIndex(where: { $0.id == id }) else { continue }
            folders[folderIndex].isEnabled = newValue
        }
        applyFolderSelection([], primary: nil)
        applySnippetSelection([], primary: nil)
    }

    func moveFolders(from offsets: IndexSet, to destination: Int) {
        let selectedIDs = selectedFolderIDs
        let primary = selectedFolderID
        registerUndoSnapshot()
        folders.move(fromOffsets: offsets, toOffset: destination)
        applyFolderSelection(selectedIDs.intersection(Set(folders.map(\.id))), primary: primary)
    }

    @discardableResult
    func addSnippet() -> UUID? {
        let targetFolderID = selectedFolderID ?? orderedSelectedFolderIDs().first
        guard let targetFolderID,
              let folderIndex = folders.firstIndex(where: { $0.id == targetFolderID }) else {
            return nil
        }
        let folderID = folders[folderIndex].id
        registerUndoSnapshot()
        let snippet = Snippet(title: NSLocalizedString("untitled snippet", comment: ""), content: "", isEnabled: true)
        folders[folderIndex].snippets.append(snippet)
        applyFolderSelection([folderID], primary: folderID)
        applySnippetSelection([snippet.id], primary: snippet.id)
        return snippet.id
    }

    func removeSelectedSnippet() {
        guard let folderIndex = selectedFolderIndex else { return }
        let selectedIDs = orderedSelectedSnippetIDs(in: folderIndex)
        registerUndoSnapshot()
        let selectedIndexes = selectedIDs.compactMap { id in
            folders[folderIndex].snippets.firstIndex { $0.id == id }
        }
        guard let firstRemovedIndex = selectedIndexes.min(), !selectedIndexes.isEmpty else { return }
        for index in selectedIndexes.sorted(by: >) {
            folders[folderIndex].snippets.remove(at: index)
        }
        let snippetID = replacementSnippetID(in: folderIndex, afterRemovingSnippetAt: firstRemovedIndex)
        applySnippetSelection(snippetID.map { [$0] } ?? [], primary: snippetID)
    }

    func toggleSelectedSnippetEnabled() {
        guard let folderIndex = selectedFolderIndex else { return }
        let selectedIDs = orderedSelectedSnippetIDs(in: folderIndex)
        guard let firstID = selectedIDs.first,
              let snippetIndex = folders[folderIndex].snippets.firstIndex(where: { $0.id == firstID }) else { return }
        registerUndoSnapshot()
        let newValue = !folders[folderIndex].snippets[snippetIndex].isEnabled
        for id in selectedIDs {
            guard let index = folders[folderIndex].snippets.firstIndex(where: { $0.id == id }) else { continue }
            folders[folderIndex].snippets[index].isEnabled = newValue
        }
    }

    func removeSnippet(folderID: UUID, snippetID: UUID) {
        reload()
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderID }),
              let snippetIndex = folders[folderIndex].snippets.firstIndex(where: { $0.id == snippetID }) else {
            return
        }
        folders[folderIndex].snippets.remove(at: snippetIndex)
        if selectedFolderID == folderID {
            let replacementID = replacementSnippetID(in: folderIndex, afterRemovingSnippetAt: snippetIndex)
            applySnippetSelection(replacementID.map { [$0] } ?? [], primary: replacementID)
        }
        save()
    }

    func moveSnippets(from offsets: IndexSet, to destination: Int, in folderID: UUID) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderID }) else { return }
        let movedIDs = offsets.map { folders[folderIndex].snippets[$0].id }
        registerUndoSnapshot()
        folders[folderIndex].snippets.move(fromOffsets: offsets, toOffset: destination)
        let primary = movedIDs.first ?? selectedSnippetID
        applySnippetSelection(Set(movedIDs), primary: primary)
    }

    func moveSnippetForTesting(sourceFolderID: UUID, snippetID: UUID, targetFolderID: UUID, destinationIndex: Int? = nil) {
        let payload = makeSnippetDragPayload(folderID: sourceFolderID, snippetIDs: [snippetID])
        moveSnippet(fromDragPayload: payload, to: targetFolderID, destinationIndex: destinationIndex)
    }

    func snippetDragProvider(folderID: UUID, snippetID: UUID) -> NSItemProvider {
        let provider = NSItemProvider()
        let draggedIDs: [UUID]
        if selectedFolderID == folderID, selectedSnippetIDs.contains(snippetID), selectedSnippetIDs.count > 1 {
            draggedIDs = orderedSelectedSnippetIDs()
        } else {
            draggedIDs = [snippetID]
        }
        let payload = makeSnippetDragPayload(folderID: folderID, snippetIDs: draggedIDs)
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.clipMenuSnippetDrag.identifier,
            visibility: .ownProcess
        ) { completion in
            completion(payload.data(using: .utf8), nil)
            return nil
        }
        return provider
    }

    func acceptSnippetDrop(_ providers: [NSItemProvider], targetFolderID: UUID, destinationIndex: Int? = nil) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.clipMenuSnippetDrag.identifier)
        }) else {
            return false
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.clipMenuSnippetDrag.identifier) { [weak self] data, _ in
            guard let data,
                  let payload = String(data: data, encoding: .utf8) else {
                return
            }
            DispatchQueue.main.async {
                self?.moveSnippet(fromDragPayload: payload, to: targetFolderID, destinationIndex: destinationIndex)
            }
        }
        return true
    }

    private func moveSnippet(fromDragPayload payload: String, to targetFolderID: UUID, destinationIndex: Int?) {
        guard let (sourceFolderID, snippetIDs) = parseSnippetDragPayload(payload),
              !snippetIDs.isEmpty,
              let sourceFolderIndex = folders.firstIndex(where: { $0.id == sourceFolderID }),
              let targetFolderIndex = folders.firstIndex(where: { $0.id == targetFolderID }) else {
            return
        }

        let orderedSnippetIDs = folders[sourceFolderIndex].snippets.map(\.id).filter(snippetIDs.contains)
        let sourceIndexes = orderedSnippetIDs.compactMap { id in
            folders[sourceFolderIndex].snippets.firstIndex { $0.id == id }
        }
        guard !sourceIndexes.isEmpty else { return }

        registerUndoSnapshot()
        let movingSnippets = orderedSnippetIDs.compactMap { id in
            folders[sourceFolderIndex].snippets.first { $0.id == id }
        }
        for index in sourceIndexes.sorted(by: >) {
            folders[sourceFolderIndex].snippets.remove(at: index)
        }

        var insertionIndex = destinationIndex ?? folders[targetFolderIndex].snippets.count
        if sourceFolderIndex == targetFolderIndex {
            insertionIndex -= sourceIndexes.filter { $0 < insertionIndex }.count
        }
        insertionIndex = max(0, min(insertionIndex, folders[targetFolderIndex].snippets.count))
        folders[targetFolderIndex].snippets.insert(contentsOf: movingSnippets, at: insertionIndex)
        let primary = movingSnippets.first?.id
        applyFolderSelection([folders[targetFolderIndex].id], primary: folders[targetFolderIndex].id)
        applySnippetSelection(Set(movingSnippets.map(\.id)), primary: primary)
    }

    func makeSnippetDragPayload(folderID: UUID, snippetIDs: [UUID]) -> String {
        ([folderID.uuidString] + snippetIDs.map(\.uuidString)).joined(separator: "\t")
    }

    private func parseSnippetDragPayload(_ payload: String) -> (folderID: UUID, snippetIDs: Set<UUID>)? {
        let parts = payload.split(separator: "\t").map(String.init)
        guard let folderIDString = parts.first,
              let folderID = UUID(uuidString: folderIDString) else {
            return nil
        }
        let snippetIDs = Set(parts.dropFirst().compactMap(UUID.init(uuidString:)))
        return (folderID, snippetIDs)
    }
}

private struct SnippetEditorView: View {
    @ObservedObject var store: SnippetFileStore
    @State private var searchText = ""
    @State private var searchScope: SnippetSearchScope = .all
    @State private var focusedFolderTitleID: UUID?
    @State private var focusedSnippetTitleID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            AutoSavingSplitView(
                autosaveName: "SnippetEditorVerticalDivider",
                isVertical: true,
                dividerStyle: .thin,
                initialPrimarySize: 244,
                primaryMin: 220,
                primaryMax: 280,
                secondaryMin: 320
            ) {
                folderList
            } secondary: {
                AutoSavingSplitView(
                    autosaveName: "SnippetEditorHorizontalDivider",
                    isVertical: false,
                    dividerStyle: .paneSplitter,
                    initialPrimarySize: 235,
                    primaryMin: 170,
                    primaryMax: nil,
                    secondaryMin: 170
                ) {
                    snippetList
                } secondary: {
                    snippetDetail
                }
            }
        }
#if DEBUG
        .overlay(debugInlineValidationHarness, alignment: .topLeading)
#endif
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: reconcileVisibleSnippetSelection)
        .onAppear {
#if DEBUG
            CMSnippetEditorActionDebugRegistry.register(action: .addFolder, handler: performAddFolderAndBeginEditing)
            CMSnippetEditorActionDebugRegistry.register(action: .addSnippet, handler: performAddSnippetAndBeginEditing)
            CMSnippetEditorActionDebugRegistry.register(action: .importSnippets, handler: performSnippetImport)
            CMSnippetEditorSearchScopeDebugRegistry.register { rawValue in
                guard let scope = SnippetSearchScope(rawValue: rawValue) else { return }
                searchScope = scope
            }
            CMSnippetEditorSearchScopeDebugRegistry.updateCurrentScope(searchScope.rawValue)
            CMSnippetEditorSearchTextDebugRegistry.register { value in
                searchText = value
            }
            CMSnippetEditorSearchTextDebugRegistry.updateCurrentText(searchText)
#endif
        }
        .onDisappear {
#if DEBUG
            CMSnippetEditorActionDebugRegistry.unregisterAll()
            CMSnippetEditorSearchScopeDebugRegistry.unregisterAll()
            CMSnippetEditorSearchTextDebugRegistry.unregisterAll()
            CMSnippetEditorSearchFieldDebugRegistry.unregister()
            CMSnippetEditorContentTextViewDebugRegistry.unregister()
#endif
        }
        .onChange(of: searchText) { newValue in
#if DEBUG
            CMSnippetEditorSearchTextDebugRegistry.updateCurrentText(newValue)
#endif
            reconcileVisibleSnippetSelection()
        }
        .onChange(of: searchScope) { newValue in
#if DEBUG
            CMSnippetEditorSearchScopeDebugRegistry.updateCurrentScope(newValue.rawValue)
#endif
            reconcileVisibleSnippetSelection()
        }
        .onChange(of: store.selectedFolderIDs) { _ in
            reconcileVisibleSnippetSelection()
        }
        .onChange(of: visibleSnippetSelectionSignature) { _ in
            reconcileVisibleSnippetSelection()
        }
        .toolbar {
            ToolbarItemGroup {
                toolbarButton("doc.badge.plus", help: NSLocalizedString("Add Snippet", comment: ""), legacyImageName: "AddSnippet.tiff", action: performAddSnippetAndBeginEditing)
                .disabled(store.selectedFolderIDs.isEmpty)
                toolbarButton("trash", help: NSLocalizedString("Delete Snippet", comment: ""), legacyImageName: "DeleteSnippet.tiff", action: performRemoveSelectedSnippet)
                toolbarButton(
                    selectedSnippetToggleSystemImage,
                    help: NSLocalizedString("Enable/Disable Snippet", comment: ""),
                    legacyImageName: "CheckSnippet.tiff",
                    action: performToggleSelectedSnippetEnabled
                )
                .disabled(store.selectedSnippetIDs.isEmpty)
                Spacer(minLength: 0)
                NativeSearchField(
                    text: $searchText,
                    placeholder: CMSnippetEditorSearchPlaceholder(),
                    selectedScope: $searchScope,
                    isEnabled: store.hasSingleSelectedFolder
                )
                .frame(width: 182)
            }
        }
    }

#if DEBUG
    @ViewBuilder
    private var debugInlineValidationHarness: some View {
        if let folderID = store.selectedFolderID {
            let folder = binding(for: folderID)
            VStack(spacing: 0) {
                FocusablePlainTextField(
                    text: Binding(
                        get: { folder.wrappedValue.title },
                        set: { newTitle in
                            var updated = folder.wrappedValue
                            updated.title = newTitle
                            folder.wrappedValue = updated
                        }
                    ),
                    placeholder: "",
                    font: NSFont.systemFont(ofSize: 11),
                    focusToken: nil,
                    canEndEditing: CMSnippetItemNameCanEndEditing(_:),
                    debugKey: "snippet-folder-title"
                )
                .frame(width: 1, height: 1)

                if let folderIndex = store.selectedFolderIndex,
                   let snippetID = store.selectedSnippetID,
                   store.folders.indices.contains(folderIndex),
                   store.folders[folderIndex].snippets.contains(where: { $0.id == snippetID }) {
                    let snippet = snippetBinding(for: snippetID, in: folderID)
                    FocusablePlainTextField(
                        text: Binding(
                            get: { snippet.wrappedValue.title },
                            set: { newTitle in
                                var updated = snippet.wrappedValue
                                updated.title = newTitle
                                snippet.wrappedValue = updated
                            }
                        ),
                        placeholder: "",
                        font: NSFont.systemFont(ofSize: 11),
                        focusToken: nil,
                        canEndEditing: CMSnippetItemNameCanEndEditing(_:),
                        debugKey: "snippet-title"
                    )
                    .frame(width: 1, height: 1)
                }
            }
            .opacity(0.01)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
#endif

    private var folderList: some View {
        VStack(spacing: 0) {
            NativeSnippetFolderBrowser(
                store: store,
                focusToken: focusedFolderTitleID == store.selectedFolderID ? focusedFolderTitleID : focusedFolderTitleID,
                backgroundColor: snippetFolderListBackgroundColor
            )
            .background(Color(snippetFolderListBackgroundColor))
            .overlay(
                Group {
                    if store.folders.isEmpty {
                        listEmptyState(
                            systemImage: "folder",
                            title: NSLocalizedString("No Folders", comment: ""),
                            message: NSLocalizedString("Add a folder to start organizing snippets.", comment: "")
                        )
                    }
                }
            )

            Divider()

            folderActionBar
        }
    }

    private var snippetList: some View {
        VStack(spacing: 0) {
            NativeSnippetTableBrowser(
                store: store,
                visibleSnippets: store.selectedFolderIndex.map(visibleSnippets(in:)) ?? [],
                focusToken: focusedSnippetTitleID == store.selectedSnippetID ? focusedSnippetTitleID : focusedSnippetTitleID,
                allowsReordering: trimmedSearchText.isEmpty,
                backgroundColor: snippetListBackgroundColor
            )
            .background(Color(snippetListBackgroundColor))
        }
    }

    private var snippetDetail: some View {
        let editorContext = snippetDetailContext
        return snippetDetailEditor(
            folderTitle: editorContext.folderTitle,
            snippetTitle: editorContext.snippetTitle,
            snippet: editorContext.binding,
            isEditable: editorContext.isEditable
        )
    }

    @ViewBuilder
    private func toolbarButton(
        _ systemImage: String,
        help: String,
        legacyImageName: String? = nil,
        tint: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            snippetLegacyIcon(
                legacyImageName: legacyImageName,
                fallbackSystemImage: systemImage,
                size: 15,
                tint: tint,
                preserveTemplateRendering: false
            )
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(Text(help))
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func actionBarButton(
        _ systemImage: String,
        help: String,
        legacyImageName: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            snippetLegacyIcon(
                legacyImageName: legacyImageName,
                fallbackSystemImage: systemImage,
                size: 13,
                tint: .primary,
                preserveTemplateRendering: true
            )
            .frame(width: 32, height: 24)
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
        .disabled(isDisabled)
        .help(help)
        .accessibilityLabel(Text(help))
    }

    private var folderActionBar: some View {
        HStack(spacing: 6) {
            actionBarButton(
                "plus",
                help: NSLocalizedString("Add Folder", comment: ""),
                legacyImageName: "NSAddTemplate",
                action: performAddFolderAndBeginEditing
            )
            actionBarButton(
                "minus",
                help: NSLocalizedString("Delete Folder", comment: ""),
                legacyImageName: "NSRemoveTemplate",
                isDisabled: store.selectedFolderIDs.isEmpty,
                action: performRemoveSelectedFolder
            )
            actionBarButton(
                selectedFolderToggleSystemImage,
                help: NSLocalizedString("Enable/Disable Folder", comment: ""),
                legacyImageName: "check",
                isDisabled: store.selectedFolderIDs.isEmpty,
                action: performToggleSelectedFolderEnabled
            )

            Menu {
                Button(NSLocalizedString("Import Snippets...", comment: ""), action: performSnippetImport)
                Button(NSLocalizedString("Export Snippets...", comment: ""), action: performSnippetExport)
                    .disabled(store.folders.isEmpty)
            } label: {
                snippetLegacyIcon(
                    legacyImageName: "NSActionTemplate",
                    fallbackSystemImage: "ellipsis.circle",
                    size: 13,
                    tint: .primary,
                    preserveTemplateRendering: true
                )
                .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28, height: 28)
            .help(NSLocalizedString("Snippet Actions", comment: ""))
            .accessibilityLabel(Text(NSLocalizedString("Snippet Actions", comment: "")))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
    }

    private enum EmptyStateStyle {
        case browser
        case inspector
    }

    @ViewBuilder
    private func listEmptyState(
        systemImage: String,
        title: String,
        message: String,
        style: EmptyStateStyle = .browser
    ) -> some View {
        let titleColor: Color = style == .inspector ? .primary : Color.black.opacity(0.72)
        let messageColor: Color = style == .inspector ? .secondary : Color.black.opacity(0.52)
        let iconColor: Color = style == .inspector ? .secondary : Color.black.opacity(0.32)
        VStack(alignment: style == .inspector ? .leading : .center, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(iconColor)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(titleColor)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(messageColor)
        }
        .multilineTextAlignment(style == .inspector ? .leading : .center)
        .frame(maxWidth: style == .inspector ? 280 : 204, alignment: style == .inspector ? .leading : .center)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: style == .inspector ? .topLeading : .top
        )
        .padding(.horizontal, 20)
        .padding(.top, style == .inspector ? 22 : 32)
        .padding(.bottom, 24)
    }

    private func snippetDetailEditor(
        folderTitle: String?,
        snippetTitle: String?,
        snippet: Binding<Snippet>,
        isEditable: Bool
    ) -> some View {
        let selectedSnippet = snippet.wrappedValue
        return VStack(spacing: 0) {
            if let snippetTitle, let folderTitle {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snippetTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(snippetDetailMetadataLine(folderTitle: folderTitle, snippet: selectedSnippet))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)

                Divider()
            }

            if isEditable {
                NativeSnippetTextView(text: snippetContentBinding(snippet), isEditable: isEditable)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.textBackgroundColor))
            } else {
                listEmptyState(
                    systemImage: "selection.pin.in.out",
                    title: NSLocalizedString("No Snippet Selected", comment: ""),
                    message: NSLocalizedString("Choose a snippet to review or edit its contents.", comment: ""),
                    style: .inspector
                )
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func performSnippetSave() {
        if !NSApp.sendAction(#selector(SwiftUISnippetEditorWindowController.save(_:)), to: nil, from: nil) {
            store.save()
        }
    }

    private func performSnippetRevert() {
        if !NSApp.sendAction(#selector(SwiftUISnippetEditorWindowController.revertToSaved(_:)), to: nil, from: nil) {
            store.reload()
        }
    }

    private func performSnippetImport() {
        guard commitSnippetEditorEditing(showFailureAlert: true) else { return }
        if !NSApp.sendAction(#selector(SwiftUISnippetEditorWindowController.importSnippets(_:)), to: nil, from: nil) {
            store.importSnippetsFromPanel()
        }
    }

    private func performSnippetExport() {
        if !NSApp.sendAction(#selector(SwiftUISnippetEditorWindowController.exportSnippets(_:)), to: nil, from: nil) {
            store.exportSnippetsToPanel()
        }
    }

    private func performAddFolderAndBeginEditing() {
        guard commitSnippetEditorEditing(showFailureAlert: true) else { return }
        addFolderAndBeginEditing()
    }

    private func performRemoveSelectedFolder() {
        endSnippetEditorEditing()
        store.removeSelectedFolder()
    }

    private func performToggleSelectedFolderEnabled() {
        endSnippetEditorEditing()
        store.toggleSelectedFolderEnabled()
    }

    private func performAddSnippetAndBeginEditing() {
        guard commitSnippetEditorEditing(showFailureAlert: true) else { return }
        addSnippetAndBeginEditing()
    }

    private func performRemoveSelectedSnippet() {
        endSnippetEditorEditing()
        store.removeSelectedSnippet()
    }

    private func performToggleSelectedSnippetEnabled() {
        endSnippetEditorEditing()
        store.toggleSelectedSnippetEnabled()
    }

    private func performMoveFolders(from offsets: IndexSet, to destination: Int) {
        endSnippetEditorEditing()
        store.moveFolders(from: offsets, to: destination)
    }

    private func performAcceptSnippetDrop(_ providers: [NSItemProvider], targetFolderID: UUID, destinationIndex: Int? = nil) -> Bool {
        endSnippetEditorEditing()
        return store.acceptSnippetDrop(providers, targetFolderID: targetFolderID, destinationIndex: destinationIndex)
    }

    private func performMoveSnippets(from offsets: IndexSet, to destination: Int, in folderID: UUID) {
        endSnippetEditorEditing()
        store.moveSnippets(from: offsets, to: destination, in: folderID)
    }

    private func endSnippetEditorEditing() {
        _ = commitSnippetEditorEditing(showFailureAlert: false)
    }

    @discardableResult
    private func commitSnippetEditorEditing(showFailureAlert: Bool) -> Bool {
        CMEndEditingForWindow(NSApp.keyWindow ?? NSApp.mainWindow, showFailureAlert: showFailureAlert)
    }

    @ViewBuilder
    private func snippetLegacyIcon(
        legacyImageName: String?,
        fallbackSystemImage: String,
        size: CGFloat,
        tint: Color,
        preserveTemplateRendering: Bool
    ) -> some View {
        if let copiedImage = snippetLegacyImage(
            named: legacyImageName,
            preserveTemplateRendering: preserveTemplateRendering
        ) {
            Image(nsImage: copiedImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: fallbackSystemImage)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: size, height: size)
        }
    }

    private func snippetLegacyImage(
        named legacyImageName: String?,
        preserveTemplateRendering: Bool
    ) -> NSImage? {
        guard let legacyImageName,
              let sourceImage = NSImage(named: legacyImageName)
                ?? NSImage(named: (legacyImageName as NSString).deletingPathExtension),
              let copiedImage = sourceImage.copy() as? NSImage else {
            return nil
        }
        copiedImage.isTemplate = preserveTemplateRendering ? sourceImage.isTemplate : false
        return copiedImage
    }

    private func binding(for id: UUID) -> Binding<SnippetFolder> {
        Binding(
            get: { store.folders.first { $0.id == id } ?? SnippetFolder(title: "", isEnabled: true, snippets: []) },
            set: { newValue in
                if let oldValue = store.folders.first(where: { $0.id == id }) {
                    store.updateFolder(id: id, to: normalizedFolder(newValue, replacing: oldValue))
                }
            }
        )
    }

    private func snippetBinding(for id: UUID, in folderID: UUID) -> Binding<Snippet> {
        Binding(
            get: {
                guard let folderIndex = store.folders.firstIndex(where: { $0.id == folderID }) else {
                    return Snippet(title: "", content: "", isEnabled: true)
                }
                return store.folders[folderIndex].snippets.first { $0.id == id } ?? Snippet(title: "", content: "", isEnabled: true)
            },
            set: { newValue in
                guard let folderIndex = store.folders.firstIndex(where: { $0.id == folderID }),
                      let oldValue = store.folders[folderIndex].snippets.first(where: { $0.id == id }) else {
                    return
                }
                store.updateSnippet(
                    folderID: folderID,
                    snippetID: id,
                    to: normalizedSnippet(newValue, replacing: oldValue)
                )
            }
        )
    }

    private func snippetContentBinding(_ snippet: Binding<Snippet>) -> Binding<String> {
        Binding(
            get: { snippet.wrappedValue.content },
            set: { content in
                var updated = snippet.wrappedValue
                updated.content = content
                snippet.wrappedValue = updated
            }
        )
    }

    private func normalizedSnippet(_ snippet: Snippet, replacing oldValue: Snippet) -> Snippet {
        CMNormalizedSnippet(snippet, replacing: oldValue)
    }

    private func normalizedFolder(_ folder: SnippetFolder, replacing oldValue: SnippetFolder) -> SnippetFolder {
        CMNormalizedSnippetFolder(folder, replacing: oldValue)
    }

    private func addFolderAndBeginEditing() {
        let id = store.addFolder()
        focusedSnippetTitleID = nil
        focusedFolderTitleID = nil
        DispatchQueue.main.async {
            focusedFolderTitleID = id
        }
    }

    private func addSnippetAndBeginEditing() {
        guard let id = store.addSnippet() else { return }
        focusedFolderTitleID = nil
        focusedSnippetTitleID = nil
        DispatchQueue.main.async {
            focusedSnippetTitleID = id
        }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var visibleSnippetSelectionSignature: String {
        guard let folderIndex = store.selectedFolderIndex else { return "" }
        return visibleSnippets(in: folderIndex)
            .map { $0.snippet.id.uuidString }
            .joined(separator: "|")
    }

    private var selectedFolders: [SnippetFolder] {
        store.folders.filter { store.selectedFolderIDs.contains($0.id) }
    }

    private var selectedSnippets: [Snippet] {
        guard let folderIndex = store.selectedFolderIndex,
              store.folders.indices.contains(folderIndex) else {
            return []
        }
        return store.folders[folderIndex].snippets.filter { store.selectedSnippetIDs.contains($0.id) }
    }

    private var selectedFolderToggleSystemImage: String {
        guard !selectedFolders.isEmpty else { return "checkmark.circle" }
        return selectedFolders.allSatisfy(\.isEnabled) ? "checkmark.circle" : "slash.circle"
    }

    private var selectedSnippetToggleSystemImage: String {
        guard !selectedSnippets.isEmpty else { return "checkmark.square" }
        return selectedSnippets.allSatisfy(\.isEnabled) ? "checkmark.square" : "xmark.square"
    }

    private var visibleSnippetCount: Int {
        guard let folderIndex = store.selectedFolderIndex else { return 0 }
        return visibleSnippets(in: folderIndex).count
    }

    private var selectedFolderTitle: String? {
        store.selectedFolderIndex.flatMap { index in
            store.folders.indices.contains(index) ? store.folders[index].title : nil
        }
    }

    private var selectedSnippetTitle: String? {
        guard let folderIndex = store.selectedFolderIndex,
              store.folders.indices.contains(folderIndex),
              let snippetIndex = store.selectedSnippetIndex,
              store.folders[folderIndex].snippets.indices.contains(snippetIndex) else {
            return nil
        }
        return store.folders[folderIndex].snippets[snippetIndex].title
    }

    private var snippetDetailContext: (
        folderTitle: String?,
        snippetTitle: String?,
        binding: Binding<Snippet>,
        isEditable: Bool
    ) {
        if let folderIndex = store.selectedFolderIndex,
           let snippetIndex = store.selectedSnippetIndex,
           store.selectedFolderIDs.count == 1,
           store.selectedSnippetIDs.count == 1,
           store.folders.indices.contains(folderIndex),
           store.folders[folderIndex].snippets.indices.contains(snippetIndex) {
            let folderID = store.folders[folderIndex].id
            let selectedSnippet = store.folders[folderIndex].snippets[snippetIndex]
            return (
                folderTitle: store.folders[folderIndex].title,
                snippetTitle: selectedSnippet.title,
                binding: snippetBinding(for: selectedSnippet.id, in: folderID),
                isEditable: true
            )
        }

        let emptySnippet = Binding<Snippet>(
            get: { Snippet(title: "", content: "", isEnabled: true) },
            set: { _ in }
        )
        return (
            folderTitle: nil,
            snippetTitle: nil,
            binding: emptySnippet,
            isEditable: false
        )
    }

    private var snippetFolderListBackgroundColor: NSColor {
        NSColor(calibratedRed: 0.839, green: 0.867, blue: 0.898, alpha: 1.0)
    }

    private var snippetListBackgroundColor: NSColor {
        .controlBackgroundColor
    }

    private func visibleSnippets(in folderIndex: Int) -> [VisibleSnippet] {
        let snippets = store.folders[folderIndex].snippets.enumerated().map {
            VisibleSnippet(index: $0.offset, snippet: $0.element)
        }
        let query = trimmedSearchText
        guard !query.isEmpty else { return snippets }
        return snippets.filter { searchScope.matches($0.snippet, index: $0.index, query: query) }
    }

    private func reconcileVisibleSnippetSelection() {
        guard !trimmedSearchText.isEmpty else { return }
        guard let folderIndex = store.selectedFolderIndex else {
            if !store.selectedSnippetIDs.isEmpty {
                store.selectedSnippetIDs = []
            }
            return
        }

        let visibleIDs = visibleSnippets(in: folderIndex).map { $0.snippet.id }
        let targetID = store.selectedSnippetID.flatMap { visibleIDs.contains($0) ? $0 : nil } ?? visibleIDs.first

        if let targetID {
            if store.selectedSnippetIDs != [targetID] || store.selectedSnippetID != targetID {
                store.selectedSnippetIDs = [targetID]
                store.notePrimarySnippet(targetID)
            }
        } else if !store.selectedSnippetIDs.isEmpty {
            store.selectedSnippetIDs = []
        }
    }

    private func snippetDetailMetadataLine(folderTitle: String, snippet: Snippet) -> String {
        let state = snippet.isEnabled
            ? NSLocalizedString("Enabled", comment: "")
            : NSLocalizedString("Disabled", comment: "")
        return "\(folderTitle) • \(state)"
    }

    private var folderGroupHeader: String {
        CMSnippetEditorFolderGroupHeader()
    }

}

private final class CMSnippetFolderOutlineView: NSOutlineView {}

final class CMSnippetTableView: NSTableView {}

private final class CMSnippetSearchField: NSSearchField {}

private final class CMSnippetContentTextView: NSTextView {}

private final class CMSnippetFolderNameTextField: NSTextField {
    var folderID: UUID?
}

private final class CMSnippetSnippetNameTextField: NSTextField {
    var folderID: UUID?
    var snippetID: UUID?
}

private final class CMSnippetFolderGroupLabelView: NSView {
    var title: String = "" {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.black.withAlphaComponent(0.56),
            .paragraphStyle: paragraphStyle
        ]

        let textRect = bounds.insetBy(dx: 0, dy: 2)
        title.draw(in: textRect, withAttributes: attributes)
    }
}

private struct NativeSnippetFolderBrowser: NSViewRepresentable {
    @ObservedObject var store: SnippetFileStore
    let focusToken: UUID?
    let backgroundColor: NSColor
    private static let groupItemIdentifier = CMSnippetEditorFolderGroupIdentifier

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let outlineView = CMSnippetFolderOutlineView(frame: .zero)
        outlineView.headerView = nil
        outlineView.rowHeight = 20
        outlineView.intercellSpacing = NSSize(width: 3, height: 0)
        outlineView.selectionHighlightStyle = .sourceList
        outlineView.draggingDestinationFeedbackStyle = .sourceList
        outlineView.focusRingType = .none
        outlineView.backgroundColor = .clear
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.allowsMultipleSelection = true
        outlineView.allowsEmptySelection = true
        outlineView.floatsGroupRows = false
        outlineView.indentationPerLevel = 14
        outlineView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        outlineView.rowHeight = 20
        outlineView.intercellSpacing = NSSize(width: 3, height: 0)
        outlineView.delegate = context.coordinator
        outlineView.dataSource = context.coordinator
        outlineView.target = context.coordinator
        outlineView.doubleAction = #selector(Coordinator.beginEditingSelectedFolder(_:))
        outlineView.setDraggingSourceOperationMask(.move, forLocal: true)
        outlineView.registerForDraggedTypes([CMSnippetFolderDragPasteboardType, NSPasteboard.PasteboardType(UTType.clipMenuSnippetDrag.identifier)])

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ImageAndTextCellColumn"))
        column.title = NSLocalizedString("798.headerCell.title", tableName: "Preferences", bundle: .main, value: "Title", comment: "")
        column.width = 240
        column.minWidth = 16
        column.maxWidth = 1000
        column.resizingMask = [.autoresizingMask, .userResizingMask]
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        scrollView.documentView = outlineView
        context.coordinator.outlineView = outlineView
        context.coordinator.scrollView = scrollView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.reloadData()
        scrollView.backgroundColor = backgroundColor
    }

    final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate, NSTextFieldDelegate {
        var parent: NativeSnippetFolderBrowser
        weak var outlineView: CMSnippetFolderOutlineView?
        weak var scrollView: NSScrollView?
        private var isApplyingSelection = false
        private var lastFocusedToken: UUID?

        init(parent: NativeSnippetFolderBrowser) {
            self.parent = parent
        }

        func reloadData() {
            guard let outlineView else { return }
            outlineView.reloadData()
            outlineView.expandItem(NativeSnippetFolderBrowser.groupItemIdentifier)
            syncSelection()
            updateFocusIfNeeded()
        }

        private func syncSelection() {
            guard let outlineView else { return }
            let selectedRows = IndexSet(parent.store.folders.enumerated().compactMap { offset, folder in
                parent.store.selectedFolderIDs.contains(folder.id) ? offset + 1 : nil
            })
            if outlineView.selectedRowIndexes != selectedRows {
                isApplyingSelection = true
                outlineView.selectRowIndexes(selectedRows, byExtendingSelection: false)
                isApplyingSelection = false
            }
        }

        private func updateFocusIfNeeded() {
            guard let outlineView,
                  let focusToken = parent.focusToken,
                  focusToken != lastFocusedToken,
                  let row = parent.store.folders.firstIndex(where: { $0.id == focusToken }) else {
                return
            }
            lastFocusedToken = focusToken
            DispatchQueue.main.async {
                outlineView.window?.makeFirstResponder(outlineView)
                outlineView.editColumn(0, row: row + 1, with: nil, select: true)
            }
        }

        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            if item == nil {
                return 1
            }
            if let item = item as? String, item == NativeSnippetFolderBrowser.groupItemIdentifier {
                return parent.store.folders.count
            }
            return 0
        }

        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            if item == nil {
                return NativeSnippetFolderBrowser.groupItemIdentifier
            }
            return parent.store.folders[index].id
        }

        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            if let item = item as? String, item == NativeSnippetFolderBrowser.groupItemIdentifier {
                return true
            }
            return false
        }

        func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
            false
        }

        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            if let groupIdentifier = item as? String, groupIdentifier == NativeSnippetFolderBrowser.groupItemIdentifier {
                let identifier = NSUserInterfaceItemIdentifier("CMSnippetFolderGroupCell")
                let cellView = (outlineView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView) ?? makeGroupCellView(identifier: identifier)
                cellView.identifier = identifier
                if let labelView = cellView.subviews.first as? CMSnippetFolderGroupLabelView {
                    labelView.title = CMSnippetEditorFolderGroupHeader()
                }
                return cellView
            }
            guard let id = item as? UUID,
                  let folder = parent.store.folders.first(where: { $0.id == id }) else {
                return nil
            }
            let identifier = NSUserInterfaceItemIdentifier("CMSnippetFolderCell")
            let cellView = (outlineView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView) ?? makeFolderCellView(identifier: identifier)
            cellView.identifier = identifier
            cellView.textField?.stringValue = folder.title
            cellView.textField?.textColor = folder.isEnabled ? .labelColor : .secondaryLabelColor
            cellView.imageView?.image = CMSnippetEditorFolderRowIcon() ?? NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
            cellView.imageView?.alphaValue = folder.isEnabled ? 1.0 : 0.58
            cellView.textField?.alphaValue = folder.isEnabled ? 1.0 : 0.58
            if let textField = cellView.textField as? CMSnippetFolderNameTextField {
                textField.folderID = id
                textField.delegate = self
            }
            return cellView
        }

        private func makeGroupCellView(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
            let cellView = NSTableCellView(frame: .zero)
            cellView.identifier = identifier

            let labelView = CMSnippetFolderGroupLabelView(frame: .zero)
            labelView.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(labelView)

            NSLayoutConstraint.activate([
                labelView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 14),
                labelView.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -6),
                labelView.topAnchor.constraint(equalTo: cellView.topAnchor),
                labelView.bottomAnchor.constraint(equalTo: cellView.bottomAnchor)
            ])

            return cellView
        }

        private func makeFolderCellView(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
            let cellView = NSTableCellView(frame: .zero)
            cellView.identifier = identifier

            let imageView = NSImageView(frame: .zero)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyDown
            cellView.imageView = imageView
            cellView.addSubview(imageView)

            let textField = CMSnippetFolderNameTextField(frame: .zero)
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.isBordered = false
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.focusRingType = .none
            textField.lineBreakMode = .byTruncatingTail
            textField.font = CMSnippetEditorLegacyListFont()
            cellView.textField = textField
            cellView.addSubview(textField)

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 14),
                imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 3),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -6),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])

            return cellView
        }

        func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
            if let item = item as? String, item == NativeSnippetFolderBrowser.groupItemIdentifier {
                return false
            }
            return true
        }

        func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
            if let item = item as? String, item == NativeSnippetFolderBrowser.groupItemIdentifier {
                return true
            }
            return false
        }

        func outlineViewSelectionDidChange(_ notification: Notification) {
            guard let outlineView, !isApplyingSelection else { return }
            let selectedIDs = Set(outlineView.selectedRowIndexes.compactMap { row -> UUID? in
                guard row > 0 else { return nil }
                let folderIndex = row - 1
                guard folderIndex < parent.store.folders.count else { return nil }
                return parent.store.folders[folderIndex].id
            })
            parent.store.selectedFolderIDs = selectedIDs
            let primaryRow = outlineView.clickedRow >= 0 ? outlineView.clickedRow : outlineView.selectedRow
            if primaryRow > 0 {
                let folderIndex = primaryRow - 1
                if folderIndex < parent.store.folders.count {
                    parent.store.notePrimaryFolder(parent.store.folders[folderIndex].id)
                }
            }
        }

        @objc func beginEditingSelectedFolder(_ sender: Any?) {
            guard let outlineView,
                  outlineView.selectedRow > 0 else {
                return
            }
            outlineView.editColumn(0, row: outlineView.selectedRow, with: nil, select: true)
        }

        func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
            if let item = item as? String, item == NativeSnippetFolderBrowser.groupItemIdentifier {
                return nil
            }
            guard let draggedID = item as? UUID else { return nil }
            let draggedIDs: [UUID]
            if parent.store.selectedFolderIDs.contains(draggedID), parent.store.selectedFolderIDs.count > 1 {
                draggedIDs = parent.store.folders.map(\.id).filter(parent.store.selectedFolderIDs.contains)
            } else {
                draggedIDs = [draggedID]
            }
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(
                CMMakeSnippetFolderDragPayload(folderIDs: draggedIDs),
                forType: CMSnippetFolderDragPasteboardType
            )
            return pasteboardItem
        }

        func outlineView(
            _ outlineView: NSOutlineView,
            validateDrop info: NSDraggingInfo,
            proposedItem item: Any?,
            proposedChildIndex index: Int
        ) -> NSDragOperation {
            let pasteboard = info.draggingPasteboard
            if pasteboard.availableType(from: [CMSnippetFolderDragPasteboardType]) != nil,
               CMSnippetFolderAcceptsFolderReorderDrop(
                proposedChildIndex: index,
                draggingSource: info.draggingSource
               ) {
                let groupItem: Any = NativeSnippetFolderBrowser.groupItemIdentifier
                outlineView.setDropItem(groupItem, dropChildIndex: max(0, index))
                return .move
            }
            if pasteboard.availableType(from: [NSPasteboard.PasteboardType(UTType.clipMenuSnippetDrag.identifier)]) != nil,
               CMSnippetFolderAcceptsSnippetDrop(
                proposedItem: item,
                proposedChildIndex: index,
                draggingSource: info.draggingSource
               ) {
                return .move
            }
            return []
        }

        func outlineView(
            _ outlineView: NSOutlineView,
            acceptDrop info: NSDraggingInfo,
            item: Any?,
            childIndex index: Int
        ) -> Bool {
            let pasteboard = info.draggingPasteboard
            if let payload = pasteboard.string(forType: CMSnippetFolderDragPasteboardType),
               CMSnippetFolderAcceptsFolderReorderDrop(
                proposedChildIndex: index,
                draggingSource: info.draggingSource
               ) {
                let draggedIDs = CMParseSnippetFolderDragPayload(payload)
                let offsets = IndexSet(draggedIDs.compactMap { draggedID in
                    parent.store.folders.firstIndex(where: { $0.id == draggedID })
                })
                guard !offsets.isEmpty else { return false }
                parent.store.moveFolders(from: offsets, to: max(0, index))
                return true
            }
            if let targetFolderID = item as? UUID,
               CMSnippetFolderAcceptsSnippetDrop(
                proposedItem: item,
                proposedChildIndex: index,
                draggingSource: info.draggingSource
               ) {
                return parent.store.acceptSnippetDrop(
                    [NSItemProvider(item: pasteboard.string(forType: NSPasteboard.PasteboardType(UTType.clipMenuSnippetDrag.identifier)) as NSString?, typeIdentifier: UTType.clipMenuSnippetDrag.identifier)],
                    targetFolderID: targetFolderID
                )
            }
            return false
        }

        func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
            CMSnippetItemNameCanEndEditing(fieldEditor.string)
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let textField = obj.object as? CMSnippetFolderNameTextField,
                  let folderID = textField.folderID,
                  let oldValue = parent.store.folders.first(where: { $0.id == folderID }) else {
                return
            }
            var updated = oldValue
            updated.title = textField.stringValue
            parent.store.updateFolder(id: folderID, to: CMNormalizedSnippetFolder(updated, replacing: oldValue))
        }
    }
}

private struct NativeSnippetTableBrowser: NSViewRepresentable {
    @ObservedObject var store: SnippetFileStore
    let visibleSnippets: [VisibleSnippet]
    let focusToken: UUID?
    let allowsReordering: Bool
    let backgroundColor: NSColor

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let tableView = CMSnippetTableView(frame: .zero)
        tableView.headerView = NSTableHeaderView(frame: NSRect(x: 0, y: 0, width: 372, height: 17))
        tableView.rowHeight = 17
        tableView.intercellSpacing = NSSize(width: 3, height: 2)
        tableView.selectionHighlightStyle = .regular
        tableView.draggingDestinationFeedbackStyle = .regular
        tableView.focusRingType = .none
        tableView.backgroundColor = .controlBackgroundColor
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.target = context.coordinator
        tableView.doubleAction = #selector(Coordinator.beginEditingSelectedSnippet(_:))
        tableView.setDraggingSourceOperationMask(.move, forLocal: true)
        tableView.registerForDraggedTypes([NSPasteboard.PasteboardType(UTType.clipMenuSnippetDrag.identifier)])

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ImageAndTextCellColumn"))
        column.title = NSLocalizedString("863.headerCell.title", tableName: "Preferences", bundle: .main, value: "Title", comment: "")
        column.width = 372
        column.minWidth = 40
        column.maxWidth = 1000
        column.resizingMask = [.autoresizingMask, .userResizingMask]
        tableView.addTableColumn(column)

        scrollView.documentView = tableView
        context.coordinator.tableView = tableView
        context.coordinator.scrollView = scrollView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        if let tableView = context.coordinator.tableView ?? scrollView.documentView as? CMSnippetTableView {
            tableView.selectionHighlightStyle = .regular
            tableView.draggingDestinationFeedbackStyle = .regular
            context.coordinator.tableView = tableView
        }
        context.coordinator.reloadData()
        scrollView.backgroundColor = backgroundColor
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
        var parent: NativeSnippetTableBrowser
        weak var tableView: CMSnippetTableView?
        weak var scrollView: NSScrollView?
        private var isApplyingSelection = false
        private var lastFocusedToken: UUID?
        private var didApplyLegacyColumnWidth = false

        init(parent: NativeSnippetTableBrowser) {
            self.parent = parent
        }

        func reloadData() {
            guard let tableView else { return }
            tableView.reloadData()
            if !didApplyLegacyColumnWidth {
                didApplyLegacyColumnWidth = true
                tableView.tableColumns.first?.width = 372
                DispatchQueue.main.async { [weak tableView] in
                    guard let tableView else { return }
                    tableView.tableColumns.first?.width = 372
                }
            }
            syncSelection()
            updateFocusIfNeeded()
        }

        private func syncSelection() {
            guard let tableView else { return }
            let selectedRows = IndexSet(parent.visibleSnippets.enumerated().compactMap { offset, visibleSnippet in
                parent.store.selectedSnippetIDs.contains(visibleSnippet.snippet.id) ? offset : nil
            })
            if tableView.selectedRowIndexes != selectedRows {
                isApplyingSelection = true
                tableView.selectRowIndexes(selectedRows, byExtendingSelection: false)
                isApplyingSelection = false
            }
        }

        private func updateFocusIfNeeded() {
            guard let tableView,
                  let focusToken = parent.focusToken,
                  focusToken != lastFocusedToken,
                  let row = parent.visibleSnippets.firstIndex(where: { $0.snippet.id == focusToken }) else {
                return
            }
            lastFocusedToken = focusToken
            DispatchQueue.main.async {
                tableView.window?.makeFirstResponder(tableView)
                tableView.editColumn(0, row: row, with: nil, select: true)
            }
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.visibleSnippets.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard parent.visibleSnippets.indices.contains(row),
                  let folderID = parent.store.selectedFolderID else {
                return nil
            }
            let visibleSnippet = parent.visibleSnippets[row]
            let identifier = NSUserInterfaceItemIdentifier("CMSnippetCell")
            let cellView = (tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView) ?? makeSnippetCellView(identifier: identifier)
            cellView.identifier = identifier
            cellView.textField?.stringValue = visibleSnippet.snippet.title
            cellView.textField?.textColor = visibleSnippet.snippet.isEnabled ? .labelColor : .secondaryLabelColor
            cellView.textField?.isEditable = visibleSnippet.snippet.isEnabled
            cellView.textField?.isSelectable = visibleSnippet.snippet.isEnabled
            cellView.imageView?.image = CMSnippetEditorSnippetRowIcon() ?? NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
            cellView.imageView?.alphaValue = visibleSnippet.snippet.isEnabled ? 1.0 : 0.58
            cellView.textField?.alphaValue = visibleSnippet.snippet.isEnabled ? 1.0 : 0.58
            if let textField = cellView.textField as? CMSnippetSnippetNameTextField {
                textField.folderID = folderID
                textField.snippetID = visibleSnippet.snippet.id
                textField.delegate = self
            }
            return cellView
        }

        private func makeSnippetCellView(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
            let cellView = NSTableCellView(frame: .zero)
            cellView.identifier = identifier

            let imageView = NSImageView(frame: .zero)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyDown
            cellView.imageView = imageView
            cellView.addSubview(imageView)

            let textField = CMSnippetSnippetNameTextField(frame: .zero)
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.isBordered = false
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.focusRingType = .none
            textField.lineBreakMode = .byTruncatingTail
            textField.font = CMSnippetEditorLegacyListFont()
            cellView.textField = textField
            cellView.addSubview(textField)

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 3),
                imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 3),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])

            return cellView
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView, !isApplyingSelection else { return }
            let selectedIDs = Set(tableView.selectedRowIndexes.compactMap { row -> UUID? in
                guard parent.visibleSnippets.indices.contains(row) else { return nil }
                return parent.visibleSnippets[row].snippet.id
            })
            parent.store.selectedSnippetIDs = selectedIDs
            let primaryRow = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
            if primaryRow >= 0, parent.visibleSnippets.indices.contains(primaryRow) {
                parent.store.notePrimarySnippet(parent.visibleSnippets[primaryRow].snippet.id)
            }
        }

        @objc func beginEditingSelectedSnippet(_ sender: Any?) {
            guard let tableView,
                  tableView.selectedRow >= 0,
                  parent.visibleSnippets.indices.contains(tableView.selectedRow),
                  parent.visibleSnippets[tableView.selectedRow].snippet.isEnabled else {
                return
            }
            tableView.editColumn(0, row: tableView.selectedRow, with: nil, select: true)
        }

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard parent.visibleSnippets.indices.contains(row),
                  let folderID = parent.store.selectedFolderID else {
                return nil
            }
            let draggedSnippet = parent.visibleSnippets[row].snippet
            let draggedIDs: [UUID]
            if parent.store.selectedSnippetIDs.contains(draggedSnippet.id), parent.store.selectedSnippetIDs.count > 1 {
                draggedIDs = parent.visibleSnippets.map(\.snippet.id).filter(parent.store.selectedSnippetIDs.contains)
            } else {
                draggedIDs = [draggedSnippet.id]
            }
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(
                parent.store.makeSnippetDragPayload(folderID: folderID, snippetIDs: draggedIDs),
                forType: NSPasteboard.PasteboardType(UTType.clipMenuSnippetDrag.identifier)
            )
            return pasteboardItem
        }

        func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
            guard parent.allowsReordering,
                  parent.store.selectedFolderID != nil,
                  info.draggingPasteboard.availableType(from: [NSPasteboard.PasteboardType(UTType.clipMenuSnippetDrag.identifier)]) != nil else {
                return []
            }
            tableView.setDropRow(max(0, row), dropOperation: .above)
            return .move
        }

        func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
            guard parent.allowsReordering,
                  let folderID = parent.store.selectedFolderID,
                  let payload = info.draggingPasteboard.string(forType: NSPasteboard.PasteboardType(UTType.clipMenuSnippetDrag.identifier)) else {
                return false
            }
            let provider = NSItemProvider(item: payload as NSString, typeIdentifier: UTType.clipMenuSnippetDrag.identifier)
            return parent.store.acceptSnippetDrop([provider], targetFolderID: folderID, destinationIndex: row)
        }

        func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
            CMSnippetItemNameCanEndEditing(fieldEditor.string)
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let textField = obj.object as? CMSnippetSnippetNameTextField,
                  let folderID = textField.folderID,
                  let snippetID = textField.snippetID,
                  let folderIndex = parent.store.folders.firstIndex(where: { $0.id == folderID }),
                  let snippetIndex = parent.store.folders[folderIndex].snippets.firstIndex(where: { $0.id == snippetID }) else {
                return
            }
            let oldValue = parent.store.folders[folderIndex].snippets[snippetIndex]
            var updated = oldValue
            updated.title = textField.stringValue
            parent.store.updateSnippet(
                folderID: folderID,
                snippetID: snippetID,
                to: CMNormalizedSnippet(updated, replacing: oldValue)
            )
        }
    }
}

func CMSnippetEditorMetricsTitle(for snippet: Snippet) -> String {
    let lineCount = max(snippet.content.split(whereSeparator: \.isNewline).count, snippet.content.isEmpty ? 0 : 1)
    return String(
        format: NSLocalizedString("%d chars, %d lines", comment: ""),
        snippet.content.count,
        lineCount
    )
}

private struct AutoSavingSplitView<Primary: View, Secondary: View>: NSViewControllerRepresentable {
    let autosaveName: String
    let isVertical: Bool
    let dividerStyle: NSSplitView.DividerStyle
    let initialPrimarySize: CGFloat
    let primaryMin: CGFloat
    let primaryMax: CGFloat?
    let secondaryMin: CGFloat
    let primary: Primary
    let secondary: Secondary

    init(
        autosaveName: String,
        isVertical: Bool,
        dividerStyle: NSSplitView.DividerStyle,
        initialPrimarySize: CGFloat,
        primaryMin: CGFloat,
        primaryMax: CGFloat?,
        secondaryMin: CGFloat,
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder secondary: () -> Secondary
    ) {
        self.autosaveName = autosaveName
        self.isVertical = isVertical
        self.dividerStyle = dividerStyle
        self.initialPrimarySize = initialPrimarySize
        self.primaryMin = primaryMin
        self.primaryMax = primaryMax
        self.secondaryMin = secondaryMin
        self.primary = primary()
        self.secondary = secondary()
    }

    func makeNSViewController(context: Context) -> AutoSavingSplitViewController {
        let controller = AutoSavingSplitViewController(
            autosaveName: autosaveName,
            isVertical: isVertical,
            dividerStyle: dividerStyle,
            initialPrimarySize: initialPrimarySize,
            primaryMin: primaryMin,
            primaryMax: primaryMax,
            secondaryMin: secondaryMin
        )
        controller.update(primary: AnyView(primary), secondary: AnyView(secondary))
        return controller
    }

    func updateNSViewController(_ controller: AutoSavingSplitViewController, context: Context) {
        controller.update(primary: AnyView(primary), secondary: AnyView(secondary))
    }
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

private final class AutoSavingSplitViewController: NSSplitViewController {
    private let autosaveName: String
    private let initialPrimarySize: CGFloat
    private let primaryHost = NSHostingController(rootView: AnyView(EmptyView()))
    private let secondaryHost = NSHostingController(rootView: AnyView(EmptyView()))
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
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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

private enum SnippetSearchScope: String, CaseIterable, Identifiable {
    case all
    case title
    case content

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .all:
            return NSLocalizedString("All", comment: "")
        case .title:
            return NSLocalizedString("Title", comment: "")
        case .content:
            return NSLocalizedString("Content", comment: "")
        }
    }

    func matches(_ snippet: Snippet, index: Int, query: String) -> Bool {
        switch self {
        case .all:
            return String(index).localizedCaseInsensitiveContains(query)
                || snippet.title.localizedCaseInsensitiveContains(query)
                || snippet.content.localizedCaseInsensitiveContains(query)
        case .title:
            return snippet.title.localizedCaseInsensitiveContains(query)
        case .content:
            return snippet.content.localizedCaseInsensitiveContains(query)
        }
    }
}

private func CMSnippetEditorFolderCountBadgeTitle(_ count: Int) -> String {
    if CMModernLocalizationIsJapanese() {
        return "\(count)フォルダ"
    }
    return count == 1 ? "1 folder" : "\(count) folders"
}

private func CMSnippetEditorSnippetCountBadgeTitle(_ count: Int) -> String {
    if CMModernLocalizationIsJapanese() {
        return "\(count)スニペット"
    }
    return count == 1 ? "1 snippet" : "\(count) snippets"
}

private func CMSnippetEditorVisibleSnippetCountBadgeTitle(_ count: Int) -> String {
    if CMModernLocalizationIsJapanese() {
        return "\(count)件を表示"
    }
    return count == 1 ? "1 visible" : "\(count) visible"
}

private func CMSnippetEditorSelectionBadgeTitle(folderTitle: String?, snippetTitle: String?) -> String {
    if let snippetTitle {
        return snippetTitle
    }
    if let folderTitle {
        return folderTitle
    }
    return NSLocalizedString("No folder selected", comment: "")
}

private func CMSnippetEditorOverviewDetail(
    folderTitle: String?,
    snippetTitle: String?,
    hasUnsavedChanges: Bool,
    folderCount: Int
) -> String {
    if hasUnsavedChanges {
        return NSLocalizedString("Snippet edits stay in memory until Save, window close, or app termination.", comment: "")
    }
    if let snippetTitle, let folderTitle {
        return CMModernLocalizationIsJapanese()
            ? "「\(folderTitle)」内の「\(snippetTitle)」を編集中です。"
            : "Editing \(snippetTitle) in \(folderTitle)."
    }
    if let folderTitle {
        return CMModernLocalizationIsJapanese()
            ? "「\(folderTitle)」のスニペットを閲覧しています。"
            : "Browsing snippets in \(folderTitle)."
    }
    if folderCount == 0 {
        return NSLocalizedString("Add a folder to start organizing snippets.", comment: "")
    }
    return NSLocalizedString("Choose a folder to browse and edit saved snippets.", comment: "")
}

private func CMSnippetEditorFooterSummary(
    visibleSnippetCount: Int,
    folderTitle: String?,
    snippetTitle: String?,
    hasUnsavedChanges: Bool
) -> String {
    if hasUnsavedChanges {
        return NSLocalizedString("Unsaved snippet changes are ready to save or revert.", comment: "")
    }
    if let snippetTitle, let folderTitle {
        return CMModernLocalizationIsJapanese()
            ? "「\(folderTitle)」内で「\(snippetTitle)」を表示しています。"
            : "Showing \(snippetTitle) from \(folderTitle)."
    }
    if let folderTitle {
        return CMModernLocalizationIsJapanese()
            ? "「\(folderTitle)」で \(visibleSnippetCount) 件のスニペットを表示しています。"
            : "Showing \(visibleSnippetCount) snippets from \(folderTitle)."
    }
    return NSLocalizedString("Choose a folder to focus the snippet browser.", comment: "")
}

private func CMSnippetEditorLegacyContentFont() -> NSFont {
    NSFont(name: "Helvetica", size: 13) ?? NSFont.systemFont(ofSize: 13)
}

private func CMSnippetEditorLegacySearchFont() -> NSFont {
    NSFont(name: "LucidaGrande", size: 13) ?? NSFont.systemFont(ofSize: 13)
}

private func CMSnippetEditorLegacyListFont() -> NSFont {
    NSFont(name: "LucidaGrande", size: 13) ?? NSFont.systemFont(ofSize: 13)
}

#if DEBUG
enum CMSnippetEditorDebugAction: Hashable {
    case addFolder
    case addSnippet
    case importSnippets
}

final class CMSnippetEditorActionDebugRegistry {
    private static var actions: [CMSnippetEditorDebugAction: () -> Void] = [:]

    static func register(action: CMSnippetEditorDebugAction, handler: @escaping () -> Void) {
        actions[action] = handler
    }

    static func invoke(_ action: CMSnippetEditorDebugAction) -> Bool {
        guard let handler = actions[action] else { return false }
        handler()
        return true
    }

    static func unregisterAll() {
        actions.removeAll()
    }
}

final class CMSnippetEditorSearchScopeDebugRegistry {
    private static var storedScopeRawValue = SnippetSearchScope.all.rawValue
    private static var setter: ((String) -> Void)?

    static func register(setter: @escaping (String) -> Void) {
        self.setter = setter
    }

    @discardableResult
    static func setScope(rawValue: String) -> Bool {
        guard let setter,
              let scope = SnippetSearchScope(rawValue: rawValue) else {
            return false
        }
        setter(scope.rawValue)
        storedScopeRawValue = scope.rawValue
        return true
    }

    static func updateCurrentScope(_ rawValue: String) {
        storedScopeRawValue = SnippetSearchScope(rawValue: rawValue)?.rawValue ?? SnippetSearchScope.all.rawValue
    }

    static func currentScopeRawValue() -> String {
        storedScopeRawValue
    }

    static func currentScopeTitle() -> String {
        (SnippetSearchScope(rawValue: storedScopeRawValue) ?? .all).localizedTitle
    }

    static func unregisterAll() {
        setter = nil
        storedScopeRawValue = SnippetSearchScope.all.rawValue
    }
}

final class CMSnippetEditorSearchTextDebugRegistry {
    private static var storedText = ""
    private static var setter: ((String) -> Void)?

    static func register(setter: @escaping (String) -> Void) {
        self.setter = setter
    }

    @discardableResult
    static func setText(_ value: String) -> Bool {
        guard let setter else { return false }
        setter(value)
        storedText = value
        return true
    }

    static func updateCurrentText(_ value: String) {
        storedText = value
    }

    static func currentText() -> String {
        storedText
    }

    static func unregisterAll() {
        setter = nil
        storedText = ""
    }
}

final class CMSnippetEditorSearchFieldDebugRegistry {
    private static weak var searchField: NSSearchField?

    static func register(searchField: NSSearchField) {
        self.searchField = searchField
    }

    static func currentAppearance() -> [String: Any] {
        guard let searchField else { return [:] }
        return [
            "fontName": searchField.font?.fontName as Any,
            "fontSize": Int((searchField.font?.pointSize ?? 0).rounded())
        ]
    }

    static func unregister() {
        searchField = nil
    }
}

final class CMSnippetEditorContentTextViewDebugRegistry {
    private static weak var textView: NSTextView?

    static func register(textView: NSTextView) {
        self.textView = textView
    }

    static func currentAppearance() -> [String: Any] {
        guard let textView else { return [:] }
        return [
            "fontName": textView.font?.fontName as Any,
            "fontSize": Int((textView.font?.pointSize ?? 0).rounded())
        ]
    }

    static func unregister() {
        textView = nil
    }
}

func CMSnippetEditorSnapshotForDebug() -> [String: Any] {
    let store = SnippetFileStore.shared
    let snippetEditorTitle = NSLocalizedString("Snippet Editor", comment: "")
    let window = NSApp.keyWindow?.title == snippetEditorTitle
        ? NSApp.keyWindow
        : (
            NSApp.mainWindow?.title == snippetEditorTitle
                ? NSApp.mainWindow
                : NSApp.windows.first(where: { window in
                    window.title == snippetEditorTitle && window.isVisible && !window.isMiniaturized
                })
        )
    let splitLayout: [String: Int] = {
        guard let rootView = window?.contentViewController?.view ?? window?.contentView,
              let verticalSplit = CMFindSplitView(in: rootView, identifier: "SnippetEditorVerticalDivider"),
              let horizontalSplit = CMFindSplitView(in: rootView, identifier: "SnippetEditorHorizontalDivider") else {
            return [:]
        }
        return [
            "verticalPrimaryWidth": Int(verticalSplit.subviews.first?.frame.width.rounded() ?? 0),
            "verticalSecondaryWidth": Int(verticalSplit.subviews.dropFirst().first?.frame.width.rounded() ?? 0),
            "horizontalPrimaryHeight": Int(horizontalSplit.subviews.first?.frame.height.rounded() ?? 0),
            "horizontalSecondaryHeight": Int(horizontalSplit.subviews.dropFirst().first?.frame.height.rounded() ?? 0)
        ]
    }()
    let splitDebug: [String: Any] = {
        guard let rootView = window?.contentViewController?.view ?? window?.contentView,
              let verticalSplit = CMFindSplitView(in: rootView, identifier: "SnippetEditorVerticalDivider"),
              let horizontalSplit = CMFindSplitView(in: rootView, identifier: "SnippetEditorHorizontalDivider") else {
            return [:]
        }

        func description(for view: NSView) -> [String: Any] {
            let fitting = view.fittingSize
            return [
                "className": NSStringFromClass(type(of: view)),
                "frame": [
                    "width": Int(view.frame.width.rounded()),
                    "height": Int(view.frame.height.rounded())
                ],
                "fittingSize": [
                    "width": Int(fitting.width.rounded()),
                    "height": Int(fitting.height.rounded())
                ]
            ]
        }

        return [
            "verticalSplit": [
                "bounds": [
                    "width": Int(verticalSplit.bounds.width.rounded()),
                    "height": Int(verticalSplit.bounds.height.rounded())
                ],
                "dividerThickness": Int(verticalSplit.dividerThickness.rounded())
            ],
            "horizontalSplit": [
                "bounds": [
                    "width": Int(horizontalSplit.bounds.width.rounded()),
                    "height": Int(horizontalSplit.bounds.height.rounded())
                ],
                "dividerThickness": Int(horizontalSplit.dividerThickness.rounded())
            ],
            "verticalSubviews": verticalSplit.subviews.map(description(for:)),
            "horizontalSubviews": horizontalSplit.subviews.map(description(for:))
        ]
    }()
    let browserMetrics: [String: [String: Int]] = {
        guard let rootView = window?.contentViewController?.view ?? window?.contentView else {
            return [:]
        }
        let tables = CMCollectTableViews(in: rootView)
        guard tables.count >= 2 else {
            return [:]
        }
        let folderOutlineView = tables[0]
        let snippetTableView = tables[1]
        func metrics(for tableView: NSTableView) -> [String: Int] {
            [
                "rowHeight": Int(tableView.rowHeight.rounded()),
                "intercellWidth": Int(tableView.intercellSpacing.width.rounded()),
                "intercellHeight": Int(tableView.intercellSpacing.height.rounded()),
                "firstColumnWidth": Int((tableView.tableColumns.first?.width ?? 0).rounded())
            ]
        }
        return [
            "folderOutline": metrics(for: folderOutlineView),
            "snippetTable": metrics(for: snippetTableView)
        ]
    }()
    let browserAppearance: [String: [String: Int]] = {
        guard let rootView = window?.contentViewController?.view ?? window?.contentView else {
            return [:]
        }
        let tables = CMCollectTableViews(in: rootView)
        guard tables.count >= 2,
              let folderOutlineView = tables[0] as? NSOutlineView else {
            return [:]
        }
        let snippetTableView = tables[1]
        return [
            "folderOutline": [
                "selectionHighlightStyle": folderOutlineView.selectionHighlightStyle.rawValue,
                "draggingDestinationFeedbackStyle": folderOutlineView.draggingDestinationFeedbackStyle.rawValue,
                "indentationPerLevel": Int(folderOutlineView.indentationPerLevel.rounded()),
                "columnAutoresizingStyle": Int(folderOutlineView.columnAutoresizingStyle.rawValue),
                "firstColumnMinWidth": Int((folderOutlineView.tableColumns.first?.minWidth ?? 0).rounded()),
                "firstColumnMaxWidth": Int((folderOutlineView.tableColumns.first?.maxWidth ?? 0).rounded()),
                "firstColumnResizingMask": Int(folderOutlineView.tableColumns.first?.resizingMask.rawValue ?? 0)
            ],
            "snippetTable": [
                "selectionHighlightStyle": snippetTableView.selectionHighlightStyle.rawValue,
                "draggingDestinationFeedbackStyle": snippetTableView.draggingDestinationFeedbackStyle.rawValue,
                "columnAutoresizingStyle": Int(snippetTableView.columnAutoresizingStyle.rawValue),
                "firstColumnMinWidth": Int((snippetTableView.tableColumns.first?.minWidth ?? 0).rounded()),
                "firstColumnMaxWidth": Int((snippetTableView.tableColumns.first?.maxWidth ?? 0).rounded()),
                "firstColumnResizingMask": Int(snippetTableView.tableColumns.first?.resizingMask.rawValue ?? 0)
            ]
        ]
    }()
    let browserHeaders: [String: Any] = {
        guard let rootView = window?.contentViewController?.view ?? window?.contentView else {
            return [:]
        }
        let tables = CMCollectTableViews(in: rootView)
        guard tables.count >= 2,
              let folderOutlineView = tables[0] as? NSOutlineView else {
            return [:]
        }
        let snippetTableView = tables[1]
        return [
            "folderOutlineShowsHeader": folderOutlineView.headerView != nil,
            "snippetTableShowsHeader": snippetTableView.headerView != nil,
            "snippetTableHeaderTitle": snippetTableView.tableColumns.first?.headerCell.stringValue as Any,
            "snippetTableHeaderHeight": Int(snippetTableView.headerView?.frame.height.rounded() ?? 0)
        ]
    }()
    let browserTextAppearance: [String: [String: Any]] = {
        guard let rootView = window?.contentViewController?.view ?? window?.contentView else {
            return [:]
        }
        let tables = CMCollectTableViews(in: rootView)
        guard tables.count >= 2 else {
            return [:]
        }

        var appearance: [String: [String: Any]] = [:]

        if let folderOutlineView = tables[0] as? NSOutlineView,
           folderOutlineView.numberOfRows > 1,
           let folderCellView = folderOutlineView.view(atColumn: 0, row: 1, makeIfNecessary: false) as? NSTableCellView,
           let textAppearance = CMSnippetEditorTextAppearance(for: folderCellView.textField) {
            appearance["folderOutline"] = textAppearance
        }

        let snippetTableView = tables[1]
        if snippetTableView.numberOfRows > 0,
           let snippetCellView = snippetTableView.view(atColumn: 0, row: 0, makeIfNecessary: false) as? NSTableCellView,
           let textAppearance = CMSnippetEditorTextAppearance(for: snippetCellView.textField) {
            appearance["snippetTable"] = textAppearance
        }

        return appearance
    }()
    let browserDebug: [String: Any] = {
        guard let rootView = window?.contentViewController?.view ?? window?.contentView else {
            return [:]
        }
        let tables = CMCollectTableViews(in: rootView)
        return [
            "tableCount": tables.count,
            "tableClassNames": tables.map { String(describing: type(of: $0)) },
            "viewClassNames": CMCollectViewClassNames(in: rootView, limit: 80)
        ]
    }()
    let folderBrowserStructure: [String: Any] = {
        guard let rootView = window?.contentViewController?.view ?? window?.contentView,
              let outlineView = CMCollectTableViews(in: rootView).first as? NSOutlineView else {
            return [:]
        }
        let rowCount = outlineView.numberOfRows
        guard rowCount > 0 else {
            return [
                "rowCount": 0
            ]
        }
        let firstItem = outlineView.item(atRow: 0)
        let firstRowTitle: String? = {
            if let title = firstItem as? String {
                return title == CMSnippetEditorFolderGroupIdentifier ? CMSnippetEditorFolderGroupHeader() : title
            }
            if let folderID = firstItem as? UUID,
               let folder = store.folders.first(where: { $0.id == folderID }) {
                return folder.title
            }
            return nil
        }()
        return [
            "rowCount": rowCount,
            "firstRowTitle": firstRowTitle as Any,
            "firstRowIsGroup": ((firstItem as? String) == CMSnippetEditorFolderGroupIdentifier)
        ]
    }()
    let currentSearchScopeRawValue = CMSnippetEditorSearchScopeDebugRegistry.currentScopeRawValue()
    let currentSearchScopeTitle = CMSnippetEditorSearchScopeDebugRegistry.currentScopeTitle()
    let currentSearchText = CMSnippetEditorSearchTextDebugRegistry.currentText()
    let searchFieldAppearance: [String: Any] = {
        let registeredAppearance = CMSnippetEditorSearchFieldDebugRegistry.currentAppearance()
        if !registeredAppearance.isEmpty {
            return registeredAppearance
        }
        let searchField: NSSearchField? = {
            if let toolbarField = window?.toolbar?.items.compactMap({ (item: NSToolbarItem) -> CMSnippetSearchField? in
                guard let itemView = item.view else { return nil }
                return CMCollectSnippetSearchFields(in: itemView).first
            }).first {
                return toolbarField
            }
            if let frameView = window?.contentView?.superview,
               let frameField = CMCollectSnippetSearchFields(in: frameView).first {
                return frameField
            }
            if let rootView = window?.contentViewController?.view ?? window?.contentView,
               let rootField = CMCollectSnippetSearchFields(in: rootView).first {
                return rootField
            }
            return nil
        }()
        guard let searchField else {
            let font = CMSnippetEditorLegacySearchFont()
            return [
                "fontName": font.fontName,
                "fontSize": Int(font.pointSize.rounded())
            ]
        }
        return [
            "fontName": searchField.font?.fontName as Any,
            "fontSize": Int((searchField.font?.pointSize ?? 0).rounded())
        ]
    }()
    let trimmedSearchText = currentSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    let selectedFolder = store.selectedFolderIndex.flatMap { store.folders.indices.contains($0) ? store.folders[$0] : nil }
    let selectedSnippet: Snippet? = {
        guard let folderIndex = store.selectedFolderIndex,
              store.folders.indices.contains(folderIndex),
              let snippetIndex = store.selectedSnippetIndex,
              store.folders[folderIndex].snippets.indices.contains(snippetIndex) else {
            return nil
        }
        return store.folders[folderIndex].snippets[snippetIndex]
    }()
    let effectiveSelectedSnippet: Snippet? = {
        guard store.selectedFolderIDs.count == 1,
              store.selectedSnippetIDs.count == 1 else {
            return nil
        }
        return selectedSnippet
    }()
    let visibleSnippetCount: Int = {
        guard let folderIndex = store.selectedFolderIndex,
              store.folders.indices.contains(folderIndex) else {
            return 0
        }
        let snippets = Array(store.folders[folderIndex].snippets.enumerated())
        guard let scope = SnippetSearchScope(rawValue: currentSearchScopeRawValue),
              !trimmedSearchText.isEmpty else {
            return snippets.count
        }
        return snippets.filter { scope.matches($0.element, index: $0.offset, query: trimmedSearchText) }.count
    }()
    let visibleSnippetTitles: [String] = {
        guard let rootView = window?.contentViewController?.view ?? window?.contentView,
              let snippetTableView = CMCollectTableViews(in: rootView).dropFirst().first else {
            return []
        }
        return (0..<snippetTableView.numberOfRows).compactMap { row in
            (snippetTableView.view(atColumn: 0, row: row, makeIfNecessary: true) as? NSTableCellView)?
                .textField?
                .stringValue
        }
    }()
    let snippetListState: [String: String] = {
        if store.selectedFolderIDs.count > 1 {
            return [
                "mode": "multipleFolders",
                "systemImage": "checklist",
                "title": NSLocalizedString("Multiple Folders Selected", comment: ""),
                "message": NSLocalizedString("Choose a single folder to browse its snippets.", comment: "")
            ]
        }
        if store.selectedFolderIndex == nil {
            return [
                "mode": "noFolder",
                "systemImage": "sidebar.left",
                "title": NSLocalizedString("Choose a Folder", comment: ""),
                "message": NSLocalizedString("Select a folder to browse its snippets.", comment: "")
            ]
        }
        if visibleSnippetCount == 0 {
            return [
                "mode": trimmedSearchText.isEmpty ? "noSnippets" : "noMatches",
                "systemImage": trimmedSearchText.isEmpty ? "doc.text" : "magnifyingglass",
                "title": trimmedSearchText.isEmpty ? NSLocalizedString("No Snippets", comment: "") : NSLocalizedString("No Matches", comment: ""),
                "message": trimmedSearchText.isEmpty
                    ? NSLocalizedString("Add a snippet to the selected folder.", comment: "")
                    : NSLocalizedString("Try a different search term.", comment: "")
            ]
        }
        return [
            "mode": "results",
            "systemImage": "list.bullet",
            "title": CMSnippetEditorVisibleSnippetCountBadgeTitle(visibleSnippetCount),
            "message": CMSnippetEditorSelectionBadgeTitle(
                folderTitle: selectedFolder?.title,
                snippetTitle: effectiveSelectedSnippet?.title
            )
        ]
    }()
    let detailPaneState: [String: String] = {
        if store.selectedFolderIDs.count > 1 {
            return [
                "mode": "multipleFolders",
                "systemImage": "checklist",
                "title": NSLocalizedString("Multiple Folders Selected", comment: ""),
                "message": NSLocalizedString("Choose a single folder to browse its snippets.", comment: "")
            ]
        }
        if store.selectedSnippetIDs.count > 1 {
            return [
                "mode": "multipleSnippets",
                "systemImage": "checklist",
                "title": NSLocalizedString("Multiple Snippets Selected", comment: ""),
                "message": NSLocalizedString("Choose a single snippet to edit its content.", comment: "")
            ]
        }
        if effectiveSelectedSnippet == nil {
            return [
                "mode": "noSnippet",
                "systemImage": "doc.text",
                "title": NSLocalizedString("No Snippet Selected", comment: ""),
                "message": NSLocalizedString("Choose a snippet to edit its content.", comment: "")
            ]
        }
        return [
            "mode": "editor",
            "systemImage": "square.and.pencil",
            "title": effectiveSelectedSnippet?.title ?? NSLocalizedString("No Snippet Selected", comment: ""),
            "message": CMSnippetEditorSelectionBadgeTitle(
                folderTitle: selectedFolder?.title,
                snippetTitle: effectiveSelectedSnippet?.title
            )
        ]
    }()
    let detailPaneSectionTitles: [String] = {
        []
    }()
    let detailEditorAppearance: [String: Any] = {
        guard effectiveSelectedSnippet != nil else { return [:] }
        let registeredAppearance = CMSnippetEditorContentTextViewDebugRegistry.currentAppearance()
        if !registeredAppearance.isEmpty {
            return registeredAppearance
        }
        guard let rootView = window?.contentViewController?.view ?? window?.contentView,
              let textView = CMCollectSnippetContentTextViews(in: rootView).first else {
            return [:]
        }
        return [
            "fontName": textView.font?.fontName as Any,
            "fontSize": Int((textView.font?.pointSize ?? 0).rounded())
        ]
    }()
    let toolbarItemStates: [String: Bool] = [
        NSLocalizedString("Add Snippet", comment: ""): !store.selectedFolderIDs.isEmpty,
        NSLocalizedString("Delete Snippet", comment: ""): true,
        NSLocalizedString("Enable/Disable Snippet", comment: ""): !store.selectedSnippetIDs.isEmpty
    ]
    return [
        "search": [
            "isEnabled": store.hasSingleSelectedFolder,
            "appearance": searchFieldAppearance,
            "placeholder": CMSnippetEditorSearchPlaceholder(),
            "text": currentSearchText,
            "scopeOptions": SnippetSearchScope.allCases.map(\.localizedTitle),
            "selectedScopeRawValue": currentSearchScopeRawValue,
            "selectedScopeTitle": currentSearchScopeTitle
        ],
        "toolbarIconSources": [
            NSLocalizedString("Add Snippet", comment: ""): "legacyArtwork",
            NSLocalizedString("Delete Snippet", comment: ""): "legacyArtwork",
            NSLocalizedString("Enable/Disable Snippet", comment: ""): "legacyArtwork"
        ],
        "toolbarLayout": [
            "defaultItemLabels": [
                NSLocalizedString("Add Snippet", comment: ""),
                NSLocalizedString("Delete Snippet", comment: ""),
                NSLocalizedString("Enable/Disable Snippet", comment: ""),
                "Flexible Space",
                NSLocalizedString("Search", comment: "")
            ],
            "usesFlexibleSpaceBeforeSearch": true,
            "searchFieldWidth": 182
        ],
        "toolbarItemStates": toolbarItemStates,
        "splitLayout": splitLayout,
        "splitDebug": splitDebug,
        "browserMetrics": browserMetrics,
        "browserAppearance": browserAppearance,
        "browserHeaders": browserHeaders,
        "browserTextAppearance": browserTextAppearance,
        "browserDebug": browserDebug,
        "folderBrowserStructure": folderBrowserStructure,
        "folderGroupHeader": CMSnippetEditorFolderGroupHeader(),
        "folderActionBarIconSources": [
            NSLocalizedString("Add Folder", comment: ""): "legacyTemplate",
            NSLocalizedString("Delete Folder", comment: ""): "legacyTemplate",
            NSLocalizedString("Enable/Disable Folder", comment: ""): "legacyTemplate",
            NSLocalizedString("Snippet Actions", comment: ""): "legacyTemplate"
        ],
        "folderActionBarStates": [
            NSLocalizedString("Add Folder", comment: ""): true,
            NSLocalizedString("Delete Folder", comment: ""): !store.selectedFolderIDs.isEmpty,
            NSLocalizedString("Enable/Disable Folder", comment: ""): !store.selectedFolderIDs.isEmpty,
            NSLocalizedString("Snippet Actions", comment: ""): true
        ],
        "snippetActionsMenuTitles": [
            NSLocalizedString("Import Snippets...", comment: ""),
            NSLocalizedString("Export Snippets...", comment: "")
        ],
        "snippetActionsMenuStates": [
            NSLocalizedString("Import Snippets...", comment: ""): true,
            NSLocalizedString("Export Snippets...", comment: ""): !store.folders.isEmpty
        ],
        "rowIconSources": [
            "folder": "workspaceGenericFolderIcon",
            "snippet": "workspaceClippingTextIcon"
        ],
        "snippetListState": snippetListState,
        "visibleSnippetTitles": visibleSnippetTitles,
        "snippetListSurface": [
            "showsTableSurface": true,
            "showsEmptyStateCard": false
        ],
        "detailPane": [
            "style": "contentEditor",
            "sectionTitles": detailPaneSectionTitles,
            "state": detailPaneState,
            "editorAppearance": detailEditorAppearance,
            "showsEditorSurface": effectiveSelectedSnippet != nil,
            "showsEmptyStateCard": effectiveSelectedSnippet == nil,
            "showsContextChips": false,
            "showsInlineTitle": false,
            "showsInlineFolder": false,
            "showsEnabledToggle": false
        ],
        "footerButtons": [],
        "footerButtonIconSources": [:],
        "selection": [
            "selectedFolderTitle": selectedFolder?.title as Any,
            "selectedSnippetTitle": effectiveSelectedSnippet?.title as Any,
            "selectedSnippetEnabled": effectiveSelectedSnippet?.isEnabled as Any
        ]
    ]
}

func CMDebugSnippetNormalizationReport() -> [String: Any] {
    let untitled = NSLocalizedString("untitled snippet", comment: "")
    let emptyOriginal = Snippet(title: untitled, content: "", isEnabled: true)

    let retitledFromEmpty = CMNormalizedSnippet(
        Snippet(title: "Greeting", content: "", isEnabled: true),
        replacing: emptyOriginal
    )
    let unchangedUntitled = CMNormalizedSnippet(
        Snippet(title: untitled, content: "", isEnabled: true),
        replacing: emptyOriginal
    )
    let renamedWithExistingContent = CMNormalizedSnippet(
        Snippet(title: "Greeting", content: "Custom body", isEnabled: true),
        replacing: emptyOriginal
    )

    return [
        "defaultUntitledTitle": untitled,
        "retitledFromEmpty": [
            "title": retitledFromEmpty.title,
            "content": retitledFromEmpty.content
        ],
        "unchangedUntitled": [
            "title": unchangedUntitled.title,
            "content": unchangedUntitled.content
        ],
        "renamedWithExistingContent": [
            "title": renamedWithExistingContent.title,
            "content": renamedWithExistingContent.content
        ],
        "matchesExpected": retitledFromEmpty.title == "Greeting"
            && retitledFromEmpty.content == "Greeting"
            && unchangedUntitled.title == untitled
            && unchangedUntitled.content.isEmpty
            && renamedWithExistingContent.title == "Greeting"
            && renamedWithExistingContent.content == "Custom body"
    ]
}

func CMDebugSnippetSearchScopeReport() -> [String: Any] {
    let snippets = [
        Snippet(title: "Greeting", content: "Hello from snippet", isEnabled: true),
        Snippet(title: "Bug Bash", content: "Needs follow-up", isEnabled: true),
        Snippet(title: "Archive", content: "Greeting appears in content only", isEnabled: true)
    ]

    func titles(matching scope: SnippetSearchScope, query: String) -> [String] {
        snippets.enumerated().compactMap { index, snippet in
            scope.matches(snippet, index: index, query: query) ? snippet.title : nil
        }
    }

    let allGreetingTitles = titles(matching: .all, query: "greet")
    let titleGreetingTitles = titles(matching: .title, query: "greet")
    let contentGreetingTitles = titles(matching: .content, query: "greet")
    let allIndexTitles = titles(matching: .all, query: "1")
    let titleIndexTitles = titles(matching: .title, query: "1")
    let contentFollowUpTitles = titles(matching: .content, query: "follow")

    return [
        "allScopeGreetingTitles": allGreetingTitles,
        "titleScopeGreetingTitles": titleGreetingTitles,
        "contentScopeGreetingTitles": contentGreetingTitles,
        "allScopeIndexTitles": allIndexTitles,
        "titleScopeIndexTitles": titleIndexTitles,
        "contentScopeFollowUpTitles": contentFollowUpTitles,
        "matchesExpected": allGreetingTitles == ["Greeting", "Archive"]
            && titleGreetingTitles == ["Greeting"]
            && contentGreetingTitles == ["Archive"]
            && allIndexTitles == ["Bug Bash"]
            && titleIndexTitles.isEmpty
            && contentFollowUpTitles == ["Bug Bash"]
    ]
}

func CMTestSnippetInlineTitleEditForTesting(folderValue: String, snippetValue: String) -> [String: Any] {
    let store = SnippetFileStore.shared
    let selectedFolderTitle = store.selectedFolderIndex.flatMap {
        store.folders.indices.contains($0) ? store.folders[$0].title : nil
    } ?? ""
    let selectedSnippetTitle = store.selectedFolderIndex.flatMap { folderIndex -> String? in
        guard store.folders.indices.contains(folderIndex),
              let snippetIndex = store.selectedSnippetIndex,
              store.folders[folderIndex].snippets.indices.contains(snippetIndex) else {
            return nil
        }
        return store.folders[folderIndex].snippets[snippetIndex].title
    } ?? ""

    let folderReplaced = FocusablePlainTextField.debugReplaceText(folderValue, for: "snippet-folder-title")
    let folderCommitSucceeded = FocusablePlainTextField.debugAttemptCommit(for: "snippet-folder-title") ?? false
    let snippetReplaced = FocusablePlainTextField.debugReplaceText(snippetValue, for: "snippet-title")
    let snippetCommitSucceeded = FocusablePlainTextField.debugAttemptCommit(for: "snippet-title") ?? false

    let folderTitleAfter = store.selectedFolderIndex.flatMap {
        store.folders.indices.contains($0) ? store.folders[$0].title : nil
    } ?? ""
    let snippetTitleAfter = store.selectedFolderIndex.flatMap { folderIndex -> String? in
        guard store.folders.indices.contains(folderIndex),
              let snippetIndex = store.selectedSnippetIndex,
              store.folders[folderIndex].snippets.indices.contains(snippetIndex) else {
            return nil
        }
        return store.folders[folderIndex].snippets[snippetIndex].title
    } ?? ""

    return [
        "before": [
            "folderTitle": selectedFolderTitle,
            "snippetTitle": selectedSnippetTitle
        ],
        "folderEdit": [
            "replacementApplied": folderReplaced,
            "commitSucceeded": folderCommitSucceeded,
            "titleAfter": folderTitleAfter
        ],
        "snippetEdit": [
            "replacementApplied": snippetReplaced,
            "commitSucceeded": snippetCommitSucceeded,
            "titleAfter": snippetTitleAfter
        ],
        "matchesExpected": folderReplaced
            && snippetReplaced
            && !folderCommitSucceeded
            && !snippetCommitSucceeded
            && folderTitleAfter == selectedFolderTitle
            && snippetTitleAfter == selectedSnippetTitle
    ]
}

func CMDebugSnippetFolderDropValidationReport() -> [String: Any] {
    let validFolderReorderDrop = CMSnippetFolderAcceptsFolderReorderDrop(
        proposedChildIndex: 0,
        draggingSource: CMSnippetFolderOutlineView(frame: .zero)
    )
    let invalidFolderReorderChildIndexDrop = CMSnippetFolderAcceptsFolderReorderDrop(
        proposedChildIndex: -1,
        draggingSource: CMSnippetFolderOutlineView(frame: .zero)
    )
    let invalidFolderReorderSourceDrop = CMSnippetFolderAcceptsFolderReorderDrop(
        proposedChildIndex: 0,
        draggingSource: CMSnippetTableView(frame: .zero)
    )
    let validFolderDrop = CMSnippetFolderAcceptsSnippetDrop(
        proposedItem: UUID(),
        proposedChildIndex: -1,
        draggingSource: CMSnippetTableView(frame: .zero)
    )
    let invalidChildIndexDrop = CMSnippetFolderAcceptsSnippetDrop(
        proposedItem: UUID(),
        proposedChildIndex: 0,
        draggingSource: CMSnippetTableView(frame: .zero)
    )
    let invalidTargetDrop = CMSnippetFolderAcceptsSnippetDrop(
        proposedItem: "GROUPS",
        proposedChildIndex: -1,
        draggingSource: CMSnippetTableView(frame: .zero)
    )
    let invalidSourceDrop = CMSnippetFolderAcceptsSnippetDrop(
        proposedItem: UUID(),
        proposedChildIndex: -1,
        draggingSource: NSOutlineView(frame: .zero)
    )

    return [
        "validFolderReorderDrop": validFolderReorderDrop,
        "invalidFolderReorderChildIndexDrop": invalidFolderReorderChildIndexDrop,
        "invalidFolderReorderSourceDrop": invalidFolderReorderSourceDrop,
        "validFolderDrop": validFolderDrop,
        "invalidChildIndexDrop": invalidChildIndexDrop,
        "invalidTargetDrop": invalidTargetDrop,
        "invalidSourceDrop": invalidSourceDrop,
        "matchesExpected": validFolderReorderDrop
            && !invalidFolderReorderChildIndexDrop
            && !invalidFolderReorderSourceDrop
            && validFolderDrop
            && !invalidChildIndexDrop
            && !invalidTargetDrop
            && !invalidSourceDrop
    ]
}
#endif

private struct VisibleSnippet: Identifiable {
    let index: Int
    let snippet: Snippet

    var id: UUID { snippet.id }
}

private struct FolderRow: View {
    @Binding var folder: SnippetFolder
    let focusToken: UUID?
    var debugKey: String? = nil

    var body: some View {
        HStack(spacing: 3) {
            if let icon = CMSnippetEditorFolderRowIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            }
            FocusablePlainTextField(
                text: $folder.title,
                placeholder: "",
                font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                focusToken: focusToken,
                canEndEditing: CMSnippetItemNameCanEndEditing(_:),
                debugKey: debugKey
            )
            .frame(minHeight: 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(folder.isEnabled ? 1.0 : 0.58)
    }
}

private struct SnippetRow: View {
    @Binding var snippet: Snippet
    let index: Int
    let focusToken: UUID?
    var debugKey: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            if let icon = CMSnippetEditorSnippetRowIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            }
            FocusablePlainTextField(
                text: $snippet.title,
                placeholder: "",
                font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                focusToken: focusToken,
                canEndEditing: CMSnippetItemNameCanEndEditing(_:),
                debugKey: debugKey
            )
            .textFieldStyle(PlainTextFieldStyle())
            .frame(minHeight: 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(snippet.isEnabled ? 1.0 : 0.58)
    }
}

struct FocusablePlainTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let font: NSFont
    let focusToken: UUID?
    var updatesContinuously = true
    var canEndEditing: ((String) -> Bool)? = nil
    var debugKey: String? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, updatesContinuously: updatesContinuously, canEndEditing: canEndEditing)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(string: text)
        textField.isBordered = false
        textField.drawsBackground = false
        textField.isBezeled = false
        textField.focusRingType = .none
        textField.lineBreakMode = .byTruncatingTail
        textField.delegate = context.coordinator
        if let debugKey {
            Self.debugRegistry.register(textField: textField, coordinator: context.coordinator, key: debugKey)
        }
        return textField
    }

    func updateNSView(_ textField: NSTextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.updatesContinuously = updatesContinuously
        context.coordinator.canEndEditing = canEndEditing
        if !context.coordinator.isEditing && textField.stringValue != text {
            textField.stringValue = text
        }
        textField.placeholderString = placeholder.isEmpty ? nil : placeholder
        textField.font = font
        if let debugKey {
            Self.debugRegistry.register(textField: textField, coordinator: context.coordinator, key: debugKey)
        }

        guard focusToken != context.coordinator.lastFocusedToken else { return }
        context.coordinator.lastFocusedToken = focusToken
        guard focusToken != nil else { return }

        DispatchQueue.main.async {
            guard let window = textField.window else { return }
            window.makeFirstResponder(textField)
            textField.currentEditor()?.selectAll(nil)
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var lastFocusedToken: UUID?
        var updatesContinuously: Bool
        var canEndEditing: ((String) -> Bool)?
        var isEditing = false

        init(text: Binding<String>, updatesContinuously: Bool, canEndEditing: ((String) -> Bool)?) {
            self.text = text
            self.updatesContinuously = updatesContinuously
            self.canEndEditing = canEndEditing
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            isEditing = true
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            if updatesContinuously {
                text.wrappedValue = textField.stringValue
            }
        }

        func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
            let proposedValue = fieldEditor.string
            guard canEndEditing?(proposedValue) ?? true else {
                return false
            }
            if !updatesContinuously {
                text.wrappedValue = proposedValue
            }
            return true
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            isEditing = false
        }

        func debugReplaceText(_ value: String, on textField: NSTextField) {
            isEditing = true
            if let editor = textField.currentEditor() {
                editor.string = value
            } else {
                textField.stringValue = value
            }
            if updatesContinuously {
                text.wrappedValue = value
            }
        }

        func debugAttemptCommit(with textField: NSTextField) -> Bool {
            guard canEndEditing?(textField.stringValue) ?? true else {
                return false
            }
            if !updatesContinuously {
                text.wrappedValue = textField.stringValue
            }
            isEditing = false
            return true
        }
    }

    static func debugReplaceText(_ value: String, for key: String) -> Bool {
        debugRegistry.replaceText(value, for: key)
    }

    static func debugBeginEditing(for key: String) -> Bool {
        debugRegistry.beginEditing(for: key)
    }

    static func debugAttemptCommit(for key: String) -> Bool? {
        debugRegistry.attemptCommit(for: key)
    }

    static func commitCurrentEditing(in window: NSWindow?) -> Bool? {
        debugRegistry.commitCurrentEditing(in: window)
    }

    private static let debugRegistry = DebugRegistry()

    private final class DebugRegistry {
        private final class Entry {
            var textField: NSTextField?
            var coordinator: Coordinator?
        }

        private var entries: [String: Entry] = [:]

        func register(textField: NSTextField, coordinator: Coordinator, key: String) {
            let entry = entries[key] ?? Entry()
            entry.textField = textField
            entry.coordinator = coordinator
            entries[key] = entry
        }

        func replaceText(_ value: String, for key: String) -> Bool {
            guard let entry = entries[key],
                  let textField = entry.textField,
                  let coordinator = entry.coordinator else {
                return false
            }
            coordinator.debugReplaceText(value, on: textField)
            return true
        }

        func beginEditing(for key: String) -> Bool {
            guard let entry = entries[key],
                  let textField = entry.textField,
                  let window = textField.window else {
                return false
            }
            window.makeFirstResponder(textField)
            textField.selectText(nil)
            return true
        }

        func attemptCommit(for key: String) -> Bool? {
            guard let entry = entries[key],
                  let textField = entry.textField,
                  let coordinator = entry.coordinator else {
                return nil
            }
            return coordinator.debugAttemptCommit(with: textField)
        }

        func commitCurrentEditing(in window: NSWindow?) -> Bool? {
            for entry in entries.values {
                guard let textField = entry.textField,
                      let coordinator = entry.coordinator,
                      coordinator.isEditing,
                      textField.window === window else {
                    continue
                }
                return coordinator.debugAttemptCommit(with: textField)
            }
            return nil
        }
    }
}

private struct NativeSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    @Binding var selectedScope: SnippetSearchScope
    let isEnabled: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedScope: $selectedScope)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = CMSnippetSearchField(string: text)
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = true
        searchField.recentsAutosaveName = nil
        searchField.font = CMSnippetEditorLegacySearchFont()
#if DEBUG
        CMSnippetEditorSearchFieldDebugRegistry.register(searchField: searchField)
#endif
        searchField.delegate = context.coordinator
        if let cell = searchField.cell as? NSSearchFieldCell {
            cell.searchMenuTemplate = context.coordinator.makeSearchMenu()
        }
        return searchField
    }

    func updateNSView(_ searchField: NSSearchField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.selectedScope = $selectedScope
        if searchField.stringValue != text {
            searchField.stringValue = text
        }
        searchField.isEnabled = isEnabled
        searchField.font = CMSnippetEditorLegacySearchFont()
#if DEBUG
        CMSnippetEditorSearchFieldDebugRegistry.register(searchField: searchField)
#endif
        searchField.placeholderString = placeholder.isEmpty ? nil : placeholder
        if let cell = searchField.cell as? NSSearchFieldCell {
            cell.searchMenuTemplate = context.coordinator.makeSearchMenu()
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        var selectedScope: Binding<SnippetSearchScope>

        init(text: Binding<String>, selectedScope: Binding<SnippetSearchScope>) {
            self.text = text
            self.selectedScope = selectedScope
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else { return }
            text.wrappedValue = searchField.stringValue
        }

        func makeSearchMenu() -> NSMenu {
            let menu = NSMenu(title: CMSnippetEditorSearchPlaceholder())
            let selected = selectedScope.wrappedValue

            for scope in SnippetSearchScope.allCases {
                let item = NSMenuItem(
                    title: scope.localizedTitle,
                    action: #selector(selectScopeFromMenu(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = scope.rawValue
                item.state = scope == selected ? .on : .off
                menu.addItem(item)
            }

            return menu
        }

        @objc private func selectScopeFromMenu(_ sender: NSMenuItem) {
            guard let rawValue = sender.representedObject as? String,
                  let scope = SnippetSearchScope(rawValue: rawValue) else {
                return
            }
            selectedScope.wrappedValue = scope
        }
    }
}

private struct NativeSnippetTextView: NSViewRepresentable {
    @Binding var text: String
    let isEditable: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        let textView = CMSnippetContentTextView()
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.allowsUndo = true
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 5, height: 5)
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.font = CMSnippetEditorLegacyContentFont()
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.delegate = context.coordinator
        textView.string = text
#if DEBUG
        CMSnippetEditorContentTextViewDebugRegistry.register(textView: textView)
#endif

        if let textContainer = textView.textContainer {
            textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            textContainer.widthTracksTextView = true
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        guard let textView = context.coordinator.textView ?? scrollView.documentView as? NSTextView else {
            return
        }
        context.coordinator.textView = textView
        textView.font = CMSnippetEditorLegacyContentFont()
#if DEBUG
        CMSnippetEditorContentTextViewDebugRegistry.register(textView: textView)
#endif
        textView.backgroundColor = .textBackgroundColor
        textView.isEditable = isEditable
        textView.isSelectable = isEditable || !text.isEmpty
        scrollView.backgroundColor = .textBackgroundColor
        if textView.string != text {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: NSTextView?

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}
