// SPDX-License-Identifier: GPL-3.0-or-later
// macOS 27 implementation adapted from Hidden Bar (MIT).

#if SWIFT_PACKAGE
import NativeMenuBarShim
#endif
import AppKit
import ApplicationServices

private struct NativeMenuBarItem {
    let bundleID: String
    let frame: CGRect
}

/// macOS 27 removes oversized status items from the layout, so visibility is
/// controlled through the system's assessment-mode allow-list API instead.
final class NativeMenuBarVisibility {
    private weak var arrowItem: NSStatusItem?
    private var assertion: AnyObject?
    private var hasPromptedForAccessibility = false
    private var clockClickMonitor: Any?
    private var clockRestoreTimer: Timer?
    private var clockInteractionGeneration = 0
    private var activeAllowedBundleIDs: [String]?
    private let ownBundleID = Bundle.main.bundleIdentifier
    private let systemItems = (0..<64).map { NSNumber(value: $0) }
    private static let systemOwners: Set<String> = [
        "com.apple.MenuBarAgent", "com.apple.controlcenter", "com.apple.systemuiserver"
    ]

    var isAvailable: Bool { HBNativeVisibilityIsAvailable() }

    init(arrowItem: NSStatusItem) {
        self.arrowItem = arrowItem
        installClockClickMonitor()
    }

    deinit {
        clockRestoreTimer?.invalidate()
        if let clockClickMonitor { NSEvent.removeMonitor(clockClickMonitor) }
    }

    func collapse(completion: @escaping (Bool) -> Void) {
        clockInteractionGeneration += 1
        let generation = clockInteractionGeneration
        clockRestoreTimer?.invalidate()
        clockRestoreTimer = nil
        isReplayingClockClick = false
        installClockClickMonitor()
        guard isAvailable else {
            NSLog("Vorssaint: native menu bar visibility is unavailable on this system")
            completion(false)
            return
        }
        guard AXIsProcessTrusted() else {
            requestAccessibility()
            completion(false)
            return
        }
        guard let boundary = arrowItem?.button?.window?.frame else {
            completion(false)
            return
        }
        let isRTL = NSLocale.characterDirection(
            forLanguage: Locale.current.language.languageCode?.identifier ?? "en"
        ) == .rightToLeft
        snapshot { [weak self] items in
            guard let self, generation == self.clockInteractionGeneration else { completion(false); return }
            var visibleBundleIDs = Set<String>()
            for item in items {
                guard item.bundleID != self.ownBundleID,
                      !Self.systemOwners.contains(item.bundleID) else { continue }
                let isOnVisibleSide = isRTL
                    ? item.frame.midX < boundary.midX
                    : item.frame.midX > boundary.midX
                if isOnVisibleSide { visibleBundleIDs.insert(item.bundleID) }
            }
            self.activate(allowing: visibleBundleIDs.sorted(), generation: generation, completion: completion)
        }
    }

    /// Releasing the assertion restores every menu bar icon.
    func expand() {
        clockInteractionGeneration += 1
        clockRestoreTimer?.invalidate()
        clockRestoreTimer = nil
        activeAllowedBundleIDs = nil
        isReplayingClockClick = false
        releaseAssertion()
        installClockClickMonitor()
    }

    private func releaseAssertion() {
        if let assertion { HBNativeVisibilityInvalidate(assertion) }
        assertion = nil
    }

    /// macOS 27's assessment-mode restriction blocks the clock from opening
    /// Notification Center. Hidden Bar handles this by releasing the
    /// restriction, replaying the clock click to MenuBarAgent, then restoring
    /// the same allow-list after the panel appears (or after a bounded wait).
    private func installClockClickMonitor() {
        guard clockClickMonitor == nil else { return }
        clockClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            guard let self, self.assertion != nil, let point = event.cgEvent?.location else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.assertion != nil, !self.isReplayingClockClick,
                      !Self.isNotificationCenterVisible() else { return }
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let target = Self.clockTarget(at: point) else { return }
                    DispatchQueue.main.async { [weak self] in
                        self?.replayClockClick(to: target)
                    }
                }
            }
        }
    }

    private var isReplayingClockClick = false

    private struct ClockTarget {
        let pid: pid_t
        let frame: CGRect
    }

    private func replayClockClick(to target: ClockTarget) {
        guard assertion != nil, !isReplayingClockClick,
              !Self.isNotificationCenterVisible() else { return }
        guard let allowList = activeAllowedBundleIDs else { return }

        clockInteractionGeneration += 1
        let generation = clockInteractionGeneration
        clockRestoreTimer?.invalidate()
        clockRestoreTimer = nil
        isReplayingClockClick = true
        if let clockClickMonitor {
            NSEvent.removeMonitor(clockClickMonitor)
            self.clockClickMonitor = nil
        }
        releaseAssertion()

        // Releasing the restriction may allow the original physical click to
        // finish opening the panel. Give it a brief chance, then replay only
        // if Notification Center is still closed; otherwise the replay would
        // toggle the newly opened panel shut and make the user click twice.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, generation == self.clockInteractionGeneration else { return }
            let deadline = ProcessInfo.processInfo.systemUptime + 0.5
            if !Self.isNotificationCenterVisible() {
                Self.postClockClick(at: CGPoint(x: target.frame.midX, y: target.frame.midY), to: target.pid)
            }
            self.waitForNotificationCenterAndRestore(
                generation: generation,
                allowList: allowList,
                deadline: deadline
            )
        }
    }

    private func waitForNotificationCenterAndRestore(
        generation: Int,
        allowList: [String],
        deadline: TimeInterval
    ) {
        guard generation == clockInteractionGeneration else { return }
        if Self.isNotificationCenterVisible() || ProcessInfo.processInfo.systemUptime >= deadline {
            clockRestoreTimer = nil
            activate(allowing: allowList, generation: generation) { [weak self] _ in
                guard let self, generation == self.clockInteractionGeneration else { return }
                self.isReplayingClockClick = false
                self.installClockClickMonitor()
            }
            return
        }
        let timer = Timer(timeInterval: 0.05, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.clockRestoreTimer = nil
            self.waitForNotificationCenterAndRestore(
                generation: generation,
                allowList: allowList,
                deadline: deadline
            )
        }
        clockRestoreTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private static func isNotificationCenterVisible() -> Bool {
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.notificationcenterui"
        ).first else { return false }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.05)
        var focusedWindow: CFTypeRef?
        return AXUIElementCopyAttributeValue(
            application, kAXFocusedWindowAttribute as CFString, &focusedWindow
        ) == .success && focusedWindow != nil
    }

    private static func clockTarget(at point: CGPoint) -> ClockTarget? {
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.MenuBarAgent"
        ).first else { return nil }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.2)
        func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
            return value
        }
        func children(_ element: AXUIElement) -> [AXUIElement] {
            attribute(element, kAXChildrenAttribute as String) as? [AXUIElement] ?? []
        }
        guard let barValue = attribute(application, "AXExtrasMenuBar") else { return nil }
        let bar = barValue as! AXUIElement
        for group in children(bar) {
            for item in [group] + children(group) {
                guard attribute(item, "AXIdentifier") as? String == "com.apple.menuextra.clock",
                      let frame = accessibilityFrame(of: item), frame.contains(point) else { continue }
                return ClockTarget(pid: app.processIdentifier, frame: frame)
            }
        }
        return nil
    }

    private static func accessibilityFrame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?, sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue else { return nil }
        var position = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }

    private static func postClockClick(at point: CGPoint, to pid: pid_t) {
        guard let source = CGEventSource(stateID: .privateState) else { return }
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            guard let event = CGEvent(mouseEventSource: source, mouseType: type,
                                      mouseCursorPosition: point, mouseButton: .left) else { return }
            event.flags = []
            event.setIntegerValueField(.mouseEventClickState, value: 1)
            event.postToPid(pid)
        }
    }

    private func activate(
        allowing bundleIDs: [String],
        generation: Int,
        completion: @escaping (Bool) -> Void
    ) {
        let allowed = (ownBundleID.map { [$0] } ?? []) + bundleIDs
        HBNativeVisibilityActivate(systemItems, allowed) { [weak self] rawAssertion, error in
            guard let self else {
                if let rawAssertion { HBNativeVisibilityInvalidate(rawAssertion) }
                completion(false)
                return
            }
            guard generation == self.clockInteractionGeneration else {
                if let rawAssertion { HBNativeVisibilityInvalidate(rawAssertion) }
                completion(false)
                return
            }
            guard let rawAssertion, error == nil else {
                self.expand() // Fail open if the private API rejects this build or OS.
                NSLog("Vorssaint: could not hide menu bar items: %@", error?.localizedDescription ?? "unknown error")
                completion(false)
                return
            }
            // Objective-C `id` imports as `Any`; the private API returns an
            // Objective-C assertion object, which we retain strongly here.
            let newAssertion = rawAssertion as AnyObject
            let old = self.assertion
            self.assertion = newAssertion
            self.activeAllowedBundleIDs = bundleIDs
            if let old { HBNativeVisibilityInvalidate(old) }
            completion(true)
        }
    }

    private func requestAccessibility() {
        guard !hasPromptedForAccessibility else { return }
        hasPromptedForAccessibility = true
        Permissions.shared.requestAccessibility()
    }

    private func snapshot(completion: @escaping ([NativeMenuBarItem]) -> Void) {
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && $0.bundleURL?.pathExtension == "app"
        }.map { (pid: $0.processIdentifier, bundleID: $0.bundleIdentifier) }
        DispatchQueue.global(qos: .userInitiated).async {
            var items: [NativeMenuBarItem] = []
            for app in apps {
                let element = AXUIElementCreateApplication(app.pid)
                AXUIElementSetMessagingTimeout(element, 0.1)
                var barValue: CFTypeRef?
                guard AXUIElementCopyAttributeValue(element, "AXExtrasMenuBar" as CFString, &barValue) == .success,
                      let bar = barValue else { continue }
                var childrenValue: CFTypeRef?
                guard AXUIElementCopyAttributeValue(bar as! AXUIElement, kAXChildrenAttribute as CFString, &childrenValue) == .success,
                      let children = childrenValue as? [AXUIElement], let bundleID = app.bundleID else { continue }
                for child in children {
                    var positionValue: CFTypeRef?, sizeValue: CFTypeRef?
                    guard AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &positionValue) == .success,
                          AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &sizeValue) == .success,
                          let positionValue, let sizeValue else { continue }
                    var position = CGPoint.zero, size = CGSize.zero
                    guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
                          AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { continue }
                    items.append(NativeMenuBarItem(bundleID: bundleID, frame: CGRect(origin: position, size: size)))
                }
            }
            DispatchQueue.main.async { completion(items) }
        }
    }
}
