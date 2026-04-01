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
    private var sysIndicatorObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = CompanionStore.shared

        setupStatusItem()
        setupPopover()
        setupEventMonitor()

        // Keep status bar button in sync when companion or system state changes
        storeObserver = store.$companion
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusButton() }
        sysIndicatorObserver = store.$systemIndicator
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
        let sysPrefix = store.systemIndicator.isEmpty ? "" : "\(store.systemIndicator) "
        button.title = "\(sysPrefix)\(shinyPrefix)\(face)"
        button.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        button.toolTip = Strings.tooltip(store.companion.name, store.companion.species.localizedName)
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
        let speciesName = store.companion.species.localizedName

        // Companion identity header (not localized — rarity stars + name)
        let headerItem = NSMenuItem(
            title: "\(store.companion.rarity.stars) \(name)（\(speciesName)）",
            action: nil,
            keyEquivalent: ""
        )
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(.separator())

        let petItem = NSMenuItem(title: Strings.menuPet(name), action: #selector(openAndPet), keyEquivalent: "")
        petItem.target = self
        menu.addItem(petItem)

        let renameItem = NSMenuItem(title: Strings.menuRename(name), action: #selector(renameCompanion), keyEquivalent: "")
        renameItem.target = self
        menu.addItem(renameItem)

        menu.addItem(.separator())

        let muteItem = NSMenuItem(
            title: store.muted ? Strings.menuUnmute : Strings.menuMute,
            action: #selector(toggleMute),
            keyEquivalent: ""
        )
        muteItem.target = self
        menu.addItem(muteItem)

        let launchAtLogin = SMAppService.mainApp.status == .enabled
        let loginItem = NSMenuItem(
            title: (launchAtLogin ? "✓ " : "") + Strings.menuLaunchAtLogin,
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        menu.addItem(loginItem)

        let aboutItem = NSMenuItem(title: Strings.menuAbout, action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: Strings.menuQuit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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

        let shiny = store.companion.shiny ? " ✨" : ""
        let alert = NSAlert()
        alert.messageText = Strings.aboutTitle
        alert.informativeText = [
            Strings.aboutCompanion(store.companion.name),
            Strings.aboutSpecies(store.companion.species.localizedName),
            Strings.aboutRarity(store.companion.rarity.localizedName, store.companion.rarity.stars + shiny),
            Strings.aboutHatched(hatchDate),
        ].joined(separator: "\n")
        alert.addButton(withTitle: Strings.aboutOK)
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
