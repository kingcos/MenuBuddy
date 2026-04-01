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
    private var menuBarQuipObserver: AnyCancellable?
    private var barTimer: Timer?
    private var barTickIndex = 0
    private var settingsWindow: NSWindow?
    private var sleepStartTime: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = CompanionStore.shared

        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        setupSleepWakeObservers()
        NotificationCenter.default.addObserver(self, selector: #selector(closeSettingsWindow),
                                               name: .closeSettings, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showSettings),
                                               name: .openSettings, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showAbout),
                                               name: .openAbout, object: nil)

        // Keep status bar button in sync when companion or system state changes
        storeObserver = store.$companion
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusButton() }
        sysIndicatorObserver = store.$systemIndicator
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusButton() }
        menuBarQuipObserver = store.$menuBarQuip
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusButton() }

        // Animate the status bar face at 500ms tick
        barTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.barTickIndex += 1
            self.updateStatusButton()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        barTimer?.invalidate()
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
        let seqIdx = barTickIndex % idleSequence.count
        let isBlink = idleSequence[seqIdx] < 0

        // Derive a stress eye from the active system indicator
        let stressEye: String? = {
            switch store.systemIndicator {
            case "🔥": return "x"   // CPU hot — X eyes
            case "🧠": return "~"   // Memory full — squiggly eyes
            case "🪫": return "."   // Battery dead — tiny dots
            case "🐌": return "_"   // Net slow — flat lines
            case "💾": return "o"   // Disk busy — wide eyes
            default:   return nil
            }
        }()

        let face = renderFace(bones: store.companion.bones, blink: isBlink, eyeOverride: stressEye)
        let shinyPrefix = store.companion.shiny ? "✨" : ""
        let sysPrefix = store.systemIndicator.isEmpty ? "" : "\(store.systemIndicator) "
        let quipSuffix = store.menuBarQuip.map { " \($0)" } ?? ""
        button.title = "\(sysPrefix)\(shinyPrefix)\(face)\(quipSuffix)"
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

        let settingsItem = NSMenuItem(title: Strings.menuSettings, action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

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
            let alert = NSAlert()
            alert.messageText = Strings.errorLaunchAtLoginTitle
            alert.informativeText = Strings.errorLaunchAtLoginBody(error.localizedDescription)
            alert.addButton(withTitle: Strings.errorOK)
            alert.runModal()
        }
    }

    @objc private func closeSettingsWindow() {
        settingsWindow?.close()
    }

    @objc func showSettings() {
        if popover.isShown { popover.performClose(nil) }

        if settingsWindow == nil {
            let view = SettingsView(store: store)
            let hosting = NSHostingController(rootView: view)
            hosting.sizingOptions = .preferredContentSize
            let win = NSWindow(contentViewController: hosting)
            win.title = Strings.settingsTitle
            win.styleMask = [.titled, .closable]
            win.isReleasedWhenClosed = false
            settingsWindow = win
        }
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showAbout() {
        if popover.isShown { popover.performClose(nil) }
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

    // MARK: - Sleep / Wake

    private func setupSleepWakeObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private func systemWillSleep() {
        sleepStartTime = Date()
    }

    @objc private func systemDidWake() {
        guard let start = sleepStartTime else { return }
        let duration = Date().timeIntervalSince(start)
        sleepStartTime = nil
        store.setWakeQuip(Strings.wakeQuip(sleepSeconds: duration))
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
    static let triggerPet    = Notification.Name("MenuBuddy.triggerPet")
    static let openRename    = Notification.Name("MenuBuddy.openRename")
    static let companionWoke = Notification.Name("MenuBuddy.companionWoke")
    static let closeSettings = Notification.Name("MenuBuddy.closeSettings")
    static let openSettings  = Notification.Name("MenuBuddy.openSettings")
    static let openAbout     = Notification.Name("MenuBuddy.openAbout")
}
