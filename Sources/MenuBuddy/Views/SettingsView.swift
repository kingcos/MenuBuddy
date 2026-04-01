import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var store: CompanionStore
    @State private var launchAtLogin: Bool = false
    @State private var selectedLanguage: String = {
        if let langs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String] {
            if langs.first?.hasPrefix("zh-Hans") == true { return "zh-Hans" }
            if langs.first?.hasPrefix("en") == true { return "en" }
        }
        return "system"
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: - General
                settingsCard {
                    settingsRow {
                        Toggle(isOn: $launchAtLogin) {
                            Text(Strings.settingsLaunchAtLogin)
                        }
                        .onChange(of: launchAtLogin) { _, on in toggleLaunchAtLogin(on) }
                    }
                    cardDivider
                    settingsRow {
                        Toggle(isOn: $store.muted) {
                            Text(Strings.settingsMute)
                        }
                    }
                }

                // MARK: - Language
                sectionLabel(Strings.settingsSectionLanguage)
                settingsCard {
                    settingsRow {
                        Picker(Strings.settingsSectionLanguage, selection: $selectedLanguage) {
                            Text(Strings.settingsLanguageSystem).tag("system")
                            Text(Strings.settingsLanguageEN).tag("en")
                            Text(Strings.settingsLanguageZHHans).tag("zh-Hans")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedLanguage) { _, lang in changeLanguage(lang) }
                    }
                }

                // MARK: - Menu Bar
                sectionLabel(Strings.settingsSectionMenuBar)
                settingsCard {
                    settingsRow {
                        Toggle(isOn: $store.menuBarQuips) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Strings.settingsMenuBarQuips)
                                Text(Strings.settingsMenuBarQuipsDesc)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    cardDivider
                    settingsRow {
                        Toggle(isOn: $store.dndEnabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Strings.settingsDNDEnable)
                                Text(Strings.settingsDNDDesc)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    if store.dndEnabled {
                        cardDivider
                        settingsRow {
                            HStack(spacing: 12) {
                                Text(Strings.settingsDNDFrom)
                                    .foregroundColor(.secondary)
                                Picker("", selection: $store.dndFrom) {
                                    ForEach(0..<24, id: \.self) { h in
                                        Text(String(format: "%02d:00", h)).tag(h)
                                    }
                                }
                                .frame(width: 90)
                                Text(Strings.settingsDNDTo)
                                    .foregroundColor(.secondary)
                                Picker("", selection: $store.dndTo) {
                                    ForEach(0..<24, id: \.self) { h in
                                        Text(String(format: "%02d:00", h)).tag(h)
                                    }
                                }
                                .frame(width: 90)
                                Spacer()
                            }
                        }
                    }
                }

                // MARK: - Trigger Sources
                sectionLabel(Strings.triggerSectionTitle)
                settingsCard {
                    ForEach(Array(store.triggerManager.sources.enumerated()), id: \.offset) { idx, source in
                        if idx > 0 { cardDivider }
                        settingsRow {
                            Toggle(isOn: Binding(
                                get: { source.isEnabled },
                                set: { store.triggerManager.setEnabled($0, for: source.id) }
                            )) {
                                Text(source.displayName)
                            }
                        }
                    }
                    cardDivider
                    settingsRow {
                        Toggle(isOn: $store.repeatTriggers) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Strings.settingsRepeatTriggers)
                                Text(Strings.settingsRepeatTriggersDesc)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                settingsCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Strings.triggerScriptsHint)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 16) {
                            Button(action: {
                                let dir = ScriptTriggerSource.triggersDirectory
                                let fm = FileManager.default
                                if !fm.fileExists(atPath: dir) {
                                    try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
                                }
                                NSWorkspace.shared.open(URL(fileURLWithPath: dir))
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 11))
                                    Text(Strings.triggerScriptsOpen)
                                        .font(.system(size: 12))
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)

                            Button(action: {
                                store.triggerManager.rescanScripts()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 11))
                                    Text(Strings.triggerScriptsRescan)
                                        .font(.system(size: 12))
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                // MARK: - Help
                sectionLabel(Strings.settingsSectionHelp)
                settingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        helpItem("cursorarrow.click.2", Strings.settingsHelpPet)
                        helpItem("pencil", Strings.settingsHelpRename)
                        helpItem("sparkles", Strings.settingsHelpShiny)
                        helpItem("chart.bar.fill", Strings.settingsHelpStats)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 16)
                }

                // MARK: - Danger Zone
                settingsCard {
                    settingsRow {
                        Button(action: confirmReset) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundColor(.red)
                                Text(Strings.settingsReset)
                                    .foregroundColor(.red)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer().frame(height: 4)
            }
            .padding(20)
        }
        .frame(width: 380, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
    }

    // MARK: - Components

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.leading, 4)
            .padding(.bottom, -14)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.system(size: 13))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardDivider: some View {
        Divider().padding(.leading, 16)
    }

    private func helpItem(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
                .frame(width: 16, alignment: .center)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

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

    private func toggleLaunchAtLogin(_ enable: Bool) {
        let service = SMAppService.mainApp
        try? enable ? service.register() : service.unregister()
    }

    private func changeLanguage(_ lang: String) {
        if lang == "system" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([lang], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()

        let alert = NSAlert()
        alert.messageText = Strings.settingsLanguageRestart
        alert.addButton(withTitle: Strings.settingsLanguageRestartOK)
        alert.addButton(withTitle: Strings.settingsLanguageRestartLater)
        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }
}
