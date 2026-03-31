import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var store: CompanionStore!
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = CompanionStore.shared

        setupStatusItem()
        setupPopover()
        setupEventMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateStatusButton()
            button.action = #selector(statusButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }

        // Update the face whenever store changes
        // (simple approach: update on each popover open)
    }

    private func updateStatusButton() {
        guard let button = statusItem.button else { return }
        let face = renderFace(bones: store.companion.bones)
        button.title = face
        button.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        button.toolTip = store.companion.name
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 320)
        popover.behavior = .transient
        popover.animates = true

        let contentView = PopoverView(store: store)
        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!

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
            updateStatusButton()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Context Menu

    private func showContextMenu() {
        let menu = NSMenu()

        // Pet action
        let petItem = NSMenuItem(
            title: "Pet \(store.companion.name)",
            action: #selector(petCompanion),
            keyEquivalent: "p"
        )
        petItem.target = self
        menu.addItem(petItem)

        menu.addItem(.separator())

        // Companion info
        let infoItem = NSMenuItem(
            title: "\(store.companion.rarity.stars) \(store.companion.species.rawValue.capitalized)",
            action: nil,
            keyEquivalent: ""
        )
        infoItem.isEnabled = false
        menu.addItem(infoItem)

        menu.addItem(.separator())

        // Mute toggle
        let muteItem = NSMenuItem(
            title: store.muted ? "Unmute Buddy" : "Mute Buddy",
            action: #selector(toggleMute),
            keyEquivalent: "m"
        )
        muteItem.target = self
        menu.addItem(muteItem)

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

    @objc private func petCompanion() {
        // Open popover and show pet animation — handled by CompanionView
        togglePopover()
    }

    @objc private func toggleMute() {
        store.muted.toggle()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "MenuBuddy"
        alert.informativeText = "A tiny companion for your menu bar.\n\nYour buddy: \(store.companion.name) the \(store.companion.species.rawValue)\nRarity: \(store.companion.rarity.rawValue) \(store.companion.rarity.stars)"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Event Monitor (close popover on outside click)

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover.isShown == true {
                self?.popover.performClose(nil)
            }
        }
    }
}
