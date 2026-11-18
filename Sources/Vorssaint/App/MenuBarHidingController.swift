// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox

/// A lightweight menu-bar overflow control inspired by Hidden Bar.
///
/// Its status items are installed after Vorssaint's own items, leaving those
/// items on the visible side of the divider by default. Items on the other
/// side can be moved with Command-drag, just like other status items.
final class MenuBarHidingController: NSObject {
    private var arrowItem: NSStatusItem?
    private var dividerItem: NSStatusItem?
    private var collapseTimer: Timer?
    private var screenObserver: NSObjectProtocol?
    private var defaultsObserver: NSObjectProtocol?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var registeredShortcut: GlobalShortcut?
    private var isCollapsed = false
    private var nativeVisibility: NativeMenuBarVisibility?
    private var usesNativeVisibility: Bool { ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 }

    private let dividerWidth: CGFloat = 18
    private let arrowAutosaveName = "VorssaintMenuBarHidingArrow"
    private let dividerAutosaveName = "VorssaintMenuBarHidingDivider"

    override init() {
        super.init()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.applyDividerLength() }
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.syncWithPreferences() }
        }
        syncWithPreferences()
    }

    deinit {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let defaultsObserver { NotificationCenter.default.removeObserver(defaultsObserver) }
        collapseTimer?.invalidate()
        removeItems()
        unregisterShortcut()
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }

    private func syncWithPreferences() {
        if UserDefaults.standard.bool(forKey: DefaultsKey.menuBarHidingEnabled) {
            installItemsIfNeeded()
            registerShortcut()
            if UserDefaults.standard.bool(forKey: DefaultsKey.menuBarHidingAutoCollapse) {
                if !isCollapsed, collapseTimer == nil { scheduleAutoCollapse() }
            } else {
                collapseTimer?.invalidate()
                collapseTimer = nil
            }
        } else {
            removeItems()
            unregisterShortcut()
        }
    }

    private func installItemsIfNeeded() {
        guard arrowItem == nil, dividerItem == nil else { return }

        let arrow = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        arrow.autosaveName = arrowAutosaveName
        arrow.behavior = []
        arrow.button?.target = self
        arrow.button?.action = #selector(toggleCollapsed)
        arrow.button?.toolTip = usesNativeVisibility
            ? "Hide or show menu bar items. Command-drag icons across this arrow to set the boundary."
            : "Hide or show menu bar items"

        let divider = NSStatusBar.system.statusItem(withLength: dividerWidth)
        divider.autosaveName = dividerAutosaveName
        divider.behavior = []
        divider.button?.image = NSImage(systemSymbolName: "line.3.vertical", accessibilityDescription: "Menu bar divider")
        divider.button?.imagePosition = .imageOnly
        divider.button?.toolTip = "Menu bar divider. Command-drag items across it to choose which items are hidden."

        arrowItem = arrow
        dividerItem = divider
        if usesNativeVisibility {
            nativeVisibility = NativeMenuBarVisibility(arrowItem: arrow)
            divider.isVisible = false
        }
        updateArrow()
        applyDividerLength()
    }

    private func removeItems() {
        collapseTimer?.invalidate()
        collapseTimer = nil
        nativeVisibility?.expand()
        nativeVisibility = nil
        if let arrowItem { NSStatusBar.system.removeStatusItem(arrowItem) }
        if let dividerItem { NSStatusBar.system.removeStatusItem(dividerItem) }
        arrowItem = nil
        dividerItem = nil
        isCollapsed = false
    }

    private func registerShortcut() {
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.menuBarHidingShortcut,
                                            fallback: .menuBarHidingDefault)
        if hotKeyRef != nil, registeredShortcut == shortcut { return }
        unregisterShortcut()
        if eventHandlerRef == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                     eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetEventDispatcherTarget(), { _, event, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                var identifier = EventHotKeyID()
                if let event {
                    GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                      EventParamType(typeEventHotKeyID), nil,
                                      MemoryLayout<EventHotKeyID>.size, nil, &identifier)
                }
                guard identifier.signature == MenuBarHidingController.shortcutSignature,
                      identifier.id == 1 else { return OSStatus(eventNotHandledErr) }
                let controller = Unmanaged<MenuBarHidingController>.fromOpaque(userData)
                    .takeUnretainedValue()
                DispatchQueue.main.async { controller.toggleFromShortcut() }
                return noErr
            }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &eventHandlerRef)
        }
        let identifier = EventHotKeyID(signature: Self.shortcutSignature, id: 1)
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.carbonKeyCode,
                                         shortcut.carbonModifiers,
                                         identifier,
                                         GetEventDispatcherTarget(),
                                         0,
                                         &reference)
        guard status == noErr, let reference else { return }
        hotKeyRef = reference
        registeredShortcut = shortcut
    }

    private func unregisterShortcut() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        registeredShortcut = nil
    }

    @objc private func toggleFromShortcut() {
        toggleCollapsed()
    }

    private static let shortcutSignature = OSType(0x4D42_4844) // 'MBHD'

    @objc private func toggleCollapsed() {
        if usesNativeVisibility {
            toggleNativeVisibility()
            return
        }
        isCollapsed.toggle()
        updateArrow()
        applyDividerLength()
        if isCollapsed {
            collapseTimer?.invalidate()
            collapseTimer = nil
        } else {
            scheduleAutoCollapse()
        }
    }

    private func toggleNativeVisibility() {
        guard let nativeVisibility else { return }
        collapseTimer?.invalidate()
        collapseTimer = nil
        if isCollapsed {
            nativeVisibility.expand()
            isCollapsed = false
            updateArrow()
            scheduleAutoCollapse()
        } else {
            nativeVisibility.collapse { [weak self] succeeded in
                guard let self else { return }
                if succeeded {
                    isCollapsed = true
                    updateArrow()
                } else {
                    // No permission/API means the UI stays expanded; never claim that
                    // icons were hidden when the system did not apply the restriction.
                    isCollapsed = false
                    updateArrow()
                }
            }
        }
    }

    private func updateArrow() {
        guard let button = arrowItem?.button else { return }
        let symbol = isCollapsed ? "chevron.left" : "chevron.right"
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: isCollapsed ? "Show hidden menu bar items" : "Hide menu bar items")
        button.toolTip = isCollapsed ? "Show hidden menu bar items" : "Hide menu bar items"
    }

    private func applyDividerLength() {
        guard let dividerItem else { return }
        if usesNativeVisibility {
            dividerItem.isVisible = false
            return
        }
        let widestDisplay = NSScreen.screens.map(\.frame.width).max() ?? 1440
        let hiddenLength = min(max(widestDisplay * 2, 500), 10_000)
        dividerItem.length = isCollapsed ? hiddenLength : dividerWidth
    }

    private func scheduleAutoCollapse() {
        collapseTimer?.invalidate()
        guard UserDefaults.standard.bool(forKey: DefaultsKey.menuBarHidingAutoCollapse) else {
            collapseTimer = nil
            return
        }
        let delay = Defaults.sanitizedMenuBarHidingDelay(
            UserDefaults.standard.integer(forKey: DefaultsKey.menuBarHidingDelaySeconds))
        collapseTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self, !isCollapsed else { return }
            if pointerIsInMenuBar {
                scheduleAutoCollapse()
                return
            }
            isCollapsed = true
            if usesNativeVisibility {
                nativeVisibility?.collapse { [weak self] succeeded in
                    guard let self else { return }
                    if !succeeded { isCollapsed = false }
                    updateArrow()
                }
            } else {
                updateArrow()
                applyDividerLength()
            }
            collapseTimer = nil
        }
    }

    private var pointerIsInMenuBar: Bool {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            let menuBarBand = CGRect(x: screen.frame.minX,
                                     y: screen.visibleFrame.maxY,
                                     width: screen.frame.width,
                                     height: max(0, screen.frame.maxY - screen.visibleFrame.maxY))
            return menuBarBand.contains(point)
        }
    }
}
