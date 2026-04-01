import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var store: CompanionStore
    @State private var launchAtLogin: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar area
            HStack {
                Text(Strings.settingsTitle)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: General
                    sectionHeader(Strings.settingsSectionGeneral)

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $launchAtLogin) {
                            Text(Strings.settingsLaunchAtLogin)
                                .font(.system(size: 12))
                        }
                        .onChange(of: launchAtLogin) { _, on in
                            toggleLaunchAtLogin(on)
                        }

                        Toggle(isOn: $store.muted) {
                            Text(Strings.settingsMute)
                                .font(.system(size: 12))
                        }
                    }
                    .padding(.horizontal, 20)

                    Divider()

                    // MARK: Menu Bar
                    sectionHeader(Strings.settingsSectionMenuBar)

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $store.menuBarQuips) {
                            Text(Strings.settingsMenuBarQuips)
                                .font(.system(size: 12))
                        }
                        Text(Strings.settingsMenuBarQuipsDesc)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)

                    Divider()

                    // MARK: Do Not Disturb
                    sectionHeader(Strings.settingsSectionDND)

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $store.dndEnabled) {
                            Text(Strings.settingsDNDEnable)
                                .font(.system(size: 12))
                        }
                        if store.dndEnabled {
                            HStack(spacing: 8) {
                                Text(Strings.settingsDNDFrom)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Picker("", selection: $store.dndFrom) {
                                    ForEach(0..<24, id: \.self) { h in
                                        Text(String(format: "%02d:00", h)).tag(h)
                                    }
                                }
                                .frame(width: 80)
                                Text(Strings.settingsDNDTo)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Picker("", selection: $store.dndTo) {
                                    ForEach(0..<24, id: \.self) { h in
                                        Text(String(format: "%02d:00", h)).tag(h)
                                    }
                                }
                                .frame(width: 80)
                            }
                        }
                        Text(Strings.settingsDNDDesc)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)

                    Divider()

                    // MARK: System Monitor
                    sectionHeader(Strings.settingsSectionMonitor)

                    Text(Strings.settingsMonitorDesc)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)

                    if let snap = store.systemSnapshot {
                        SystemStatusView(snapshot: snap, prev: store.prevSystemSnapshot, cpuHistory: store.cpuHistory)
                            .padding(.horizontal, 4)
                    }

                    Divider()

                    // MARK: Help
                    sectionHeader(Strings.settingsSectionHelp)

                    VStack(alignment: .leading, spacing: 8) {
                        helpRow("🖱", Strings.settingsHelpPet)
                        helpRow("✏️", Strings.settingsHelpRename)
                        helpRow("✨", Strings.settingsHelpShiny)
                        helpRow("📊", Strings.settingsHelpStats)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                    Divider()

                    // Reset
                    Button(action: confirmReset) {
                        Text(Strings.settingsReset)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .padding(.top, 16)
            }

            Divider()

            // Done button
            HStack {
                Spacer()
                Button(Strings.settingsDone) {
                    NotificationCenter.default.post(name: .closeSettings, object: nil)
                }
                .keyboardShortcut(.defaultAction)
                .padding(.vertical, 10)
                .padding(.trailing, 16)
            }
        }
        .frame(width: 340)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 20)
    }

    private func confirmReset() {
        let alert = NSAlert()
        alert.messageText = Strings.resetConfirmTitle
        alert.informativeText = Strings.resetConfirmBody
        alert.addButton(withTitle: Strings.resetConfirmOK)
        alert.addButton(withTitle: Strings.resetConfirmCancel(store.companion.name))
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            store.resetCompanion()
        }
    }

    private func helpRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(icon)
                .font(.system(size: 12))
                .frame(width: 18)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func toggleLaunchAtLogin(_ enable: Bool) {
        let service = SMAppService.mainApp
        try? enable ? service.register() : service.unregister()
    }
}
