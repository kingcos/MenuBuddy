import AppKit
import SwiftUI
import Combine
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var store: CompanionStore!
    private var eventMonitor: Any?
    private var storeObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = CompanionStore.shared

        setupStatusItem()
        setupPopover()
        setupEventMonitor()

        // Keep status bar button in sync when companion changes (name, etc.)
        storeObserver = store.$companion
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusButton() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }
        updateStatusButton()
        button.action = #selector(statusButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
    }

    private func updateStatusButton() {
        guard let button = statusItem.button else { return }
        let face = renderFace(bones: store.companion.bones)
        let shinyPrefix = store.companion.shiny ? "✨" : ""
        button.title = "\(shinyPrefix)\(face)"
        button.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        button.toolTip = "\(store.companion.name) the \(store.companion.species.rawValue)"
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let contentView = PopoverView(store: store)
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController
    }

    @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            guard let button = statusItem.button else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Context Menu

    private func showContextMenu() {
        // Close popover first if open
        if popover.isShown { popover.performClose(nil) }

        let menu = NSMenu()

        let name = store.companion.name
        let species = store.companion.species.rawValue.capitalized

        // Companion identity header
        let headerItem = NSMenuItem(
            title: "\(store.companion.rarity.stars) \(name) the \(species)",
            action: nil,
            keyEquivalent: ""
        )
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(.separator())

        // Pet
        let petItem = NSMenuItem(
            title: "Pet \(name)",
            action: #selector(openAndPet),
            keyEquivalent: ""
        )
        petItem.target = self
        menu.addItem(petItem)

        // Rename
        let renameItem = NSMenuItem(
            title: "Rename \(name)…",
            action: #selector(renameCompanion),
            keyEquivalent: ""
        )
        renameItem.target = self
        menu.addItem(renameItem)

        menu.addItem(.separator())

        // Mute toggle
        let muteItem = NSMenuItem(
            title: store.muted ? "Unmute Buddy" : "Mute Buddy",
            action: #selector(toggleMute),
            keyEquivalent: ""
        )
        muteItem.target = self
        menu.addItem(muteItem)

        // Launch at Login toggle
        let launchAtLogin = SMAppService.mainApp.status == .enabled
        let loginItem = NSMenuItem(
            title: launchAtLogin ? "✓ Launch at Login" : "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        menu.addItem(loginItem)

        // About
        let aboutItem = NSMenuItem(
            title: "About MenuBuddy",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit MenuBuddy",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openAndPet() {
        togglePopover()
        // Small delay so the view has time to appear before pet fires
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NotificationCenter.default.post(name: .triggerPet, object: nil)
        }
    }

    @objc private func renameCompanion() {
        togglePopover()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .openRename, object: nil)
        }
    }

    @objc private func toggleMute() {
        store.muted.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            // Show error if registration fails (e.g. sandboxing restrictions)
            let alert = NSAlert()
            alert.messageText = "Launch at Login"
            alert.informativeText = "Could not change login item: \(error.localizedDescription)"
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc private func showAbout() {
        let hatchDate: String = {
            let date = Date(timeIntervalSince1970: store.companion.soul.hatchedAt)
            let f = DateFormatter()
            f.dateStyle = .medium
            return f.string(from: date)
        }()

        let alert = NSAlert()
        alert.messageText = "MenuBuddy"
        alert.informativeText = """
        Your companion: \(store.companion.name)
        Species: \(store.companion.species.rawValue.capitalized)
        Rarity: \(store.companion.rarity.rawValue.capitalized) \(store.companion.rarity.stars)\(store.companion.shiny ? " ✨" : "")
        Hatched: \(hatchDate)
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Event Monitor

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard self?.popover.isShown == true else { return }
            self?.popover.performClose(nil)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let triggerPet = Notification.Name("MenuBuddy.triggerPet")
    static let openRename = Notification.Name("MenuBuddy.openRename")
}
