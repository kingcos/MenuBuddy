import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var store: CompanionStore
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

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

                    // MARK: System Monitor
                    sectionHeader(Strings.settingsSectionMonitor)

                    Text(Strings.settingsMonitorDesc)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)

                    if let snap = store.systemSnapshot {
                        SystemStatusView(snapshot: snap)
                            .padding(.horizontal, 4)
                    }

                    Divider()

                    // MARK: Help
                    sectionHeader(Strings.settingsSectionHelp)

                    VStack(alignment: .leading, spacing: 8) {
                        helpRow("🖱", Strings.settingsHelpPet)
                        helpRow("✏️", Strings.settingsHelpRename)
                        helpRow("✨", Strings.settingsHelpShiny)
                    }
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
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
                .padding(.vertical, 10)
                .padding(.trailing, 16)
            }
        }
        .frame(width: 340)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 20)
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
