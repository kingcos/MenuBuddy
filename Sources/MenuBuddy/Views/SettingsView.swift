import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var store: CompanionStore
    @State private var launchAtLogin: Bool = false
    @State private var llmEnabled: Bool = LLMService.shared.config.enabled
    @State private var llmEndpoint: String = LLMService.shared.config.apiEndpoint
    @State private var llmApiKey: String = LLMService.shared.config.apiKey
    @State private var llmModel: String = LLMService.shared.config.model
    @State private var llmMaxTokens: String = "\(LLMService.shared.config.maxTokens)"
    @State private var llmTestResult: String?
    @State private var llmTesting = false
    @State private var selectedLanguage: String = {
        if let langs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String] {
            if langs.first?.hasPrefix("zh-Hans") == true { return "zh-Hans" }
            if langs.first?.hasPrefix("en") == true { return "en" }
        }
        return "system"
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Companion header card
            companionCard
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            // Tab-free scrollable settings
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    generalSection
                    menuBarSection
                    triggerSection
                    llmSection
                    advancedSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 400, height: 560)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
    }

    // MARK: - Companion Card (replaces About dialog)

    private var companionCard: some View {
        HStack(spacing: 14) {
            // Mini sprite
            let lines = renderFace(bones: store.companion.bones, blink: false, eyeOverride: nil)
            Text(lines)
                .font(.system(size: 18, design: .monospaced))
                .foregroundColor(store.companion.shiny ? Color(hex: "#f59e0b") : Color(hex: store.companion.rarity.color))
                .frame(width: 52, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(store.companion.name)
                        .font(.system(size: 14, weight: .semibold))
                    if store.companion.shiny {
                        Text("✨").font(.system(size: 11))
                    }
                }
                Text("\(store.companion.species.localizedName) · \(store.companion.rarity.localizedName) \(store.companion.rarity.stars)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                let hatchDate = Date(timeIntervalSince1970: store.companion.soul.hatchedAt)
                Text(Strings.aboutHatched(DateFormatter.localizedString(from: hatchDate, dateStyle: .medium, timeStyle: .none)))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("v1.0")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                Text("kingcos")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: store.companion.rarity.color).opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: store.companion.rarity.color).opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(Strings.settingsSectionGeneral)
            card {
                row {
                    Toggle(Strings.settingsLaunchAtLogin, isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, on in toggleLaunchAtLogin(on) }
                }
                divider
                row {
                    Toggle(Strings.settingsMute, isOn: $store.muted)
                }
                divider
                row {
                    HStack {
                        Text(Strings.settingsSectionLanguage)
                        Spacer()
                        Picker("", selection: $selectedLanguage) {
                            Text(Strings.settingsLanguageSystem).tag("system")
                            Text("EN").tag("en")
                            Text("中文").tag("zh-Hans")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                        .onChange(of: selectedLanguage) { _, lang in changeLanguage(lang) }
                    }
                }
            }
        }
    }

    // MARK: - Menu Bar

    private var menuBarSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(Strings.settingsSectionMenuBar)
            card {
                row {
                    Toggle(isOn: $store.menuBarQuips) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Strings.settingsMenuBarQuips)
                            Text(Strings.settingsMenuBarQuipsDesc)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                divider
                row {
                    Toggle(isOn: $store.dndEnabled) {
                        Text(Strings.settingsDNDEnable)
                    }
                }
                if store.dndEnabled {
                    divider
                    row {
                        HStack(spacing: 10) {
                            Text(Strings.settingsDNDFrom).foregroundColor(.secondary)
                            Picker("", selection: $store.dndFrom) {
                                ForEach(0..<24, id: \.self) { h in
                                    Text(String(format: "%02d:00", h)).tag(h)
                                }
                            }.frame(width: 85)
                            Text(Strings.settingsDNDTo).foregroundColor(.secondary)
                            Picker("", selection: $store.dndTo) {
                                ForEach(0..<24, id: \.self) { h in
                                    Text(String(format: "%02d:00", h)).tag(h)
                                }
                            }.frame(width: 85)
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Trigger Sources

    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(Strings.triggerSectionTitle)
            card {
                ForEach(Array(store.triggerManager.sources.enumerated()), id: \.offset) { idx, source in
                    if idx > 0 { divider }
                    row {
                        Toggle(isOn: Binding(
                            get: { source.isEnabled },
                            set: { store.triggerManager.setEnabled($0, for: source.id) }
                        )) {
                            Text(source.displayName)
                        }
                    }
                }
                divider
                row {
                    Toggle(isOn: $store.repeatTriggers) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Strings.settingsRepeatTriggers)
                            Text(Strings.settingsRepeatTriggersDesc)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                divider
                row {
                    HStack(spacing: 16) {
                        actionButton("folder", Strings.triggerScriptsOpen) {
                            let dir = ScriptTriggerSource.triggersDirectory
                            if !FileManager.default.fileExists(atPath: dir) {
                                try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                            }
                            NSWorkspace.shared.open(URL(fileURLWithPath: dir))
                        }
                        actionButton("arrow.clockwise", Strings.triggerScriptsRescan) {
                            store.triggerManager.rescanScripts()
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - LLM / AI Reactions

    private var llmSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(Strings.settingsSectionLLM)
            card {
                row {
                    Toggle(isOn: $llmEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Strings.settingsLLMEnable)
                            Text(Strings.settingsLLMEnableDesc)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: llmEnabled) { _, v in
                        var cfg = LLMService.shared.config
                        cfg.enabled = v
                        LLMService.shared.config = cfg
                    }
                }
                if llmEnabled {
                    divider
                    row {
                        VStack(alignment: .leading, spacing: 8) {
                            llmField(Strings.settingsLLMEndpoint, text: $llmEndpoint)
                            llmField(Strings.settingsLLMApiKey, text: $llmApiKey, secure: true)
                            HStack(spacing: 12) {
                                llmField(Strings.settingsLLMModel, text: $llmModel)
                                llmField(Strings.settingsLLMMaxTokens, text: $llmMaxTokens)
                                    .frame(width: 60)
                            }
                        }
                        .onChange(of: llmEndpoint) { _, _ in saveLLMConfig() }
                        .onChange(of: llmApiKey) { _, _ in saveLLMConfig() }
                        .onChange(of: llmModel) { _, _ in saveLLMConfig() }
                        .onChange(of: llmMaxTokens) { _, _ in saveLLMConfig() }
                    }
                    divider
                    row {
                        HStack {
                            // Test button
                            Button(action: testLLM) {
                                Text(llmTesting ? Strings.settingsLLMTesting : Strings.settingsLLMTest)
                                    .font(.system(size: 12))
                            }
                            .disabled(llmTesting || llmApiKey.isEmpty)

                            if let result = llmTestResult {
                                Text(result)
                                    .font(.system(size: 11))
                                    .foregroundColor(result.hasPrefix("OK") || result.hasPrefix("成功") ? .green : .red)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            Spacer()
                        }
                    }
                    divider
                    row {
                        HStack {
                            let u = LLMService.shared.usage
                            Text(Strings.settingsLLMUsage(u.totalRequests, u.totalTokens))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            actionButton("arrow.counterclockwise", Strings.settingsLLMUsageReset) {
                                LLMService.shared.resetUsage()
                            }
                        }
                    }
                }
            }
        }
    }

    private func llmField(_ label: String, text: Binding<String>, secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            if secure {
                SecureField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            } else {
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }
        }
    }

    private func saveLLMConfig() {
        var cfg = LLMService.shared.config
        cfg.apiEndpoint = llmEndpoint
        cfg.apiKey = llmApiKey
        cfg.model = llmModel
        cfg.maxTokens = Int(llmMaxTokens) ?? 60
        LLMService.shared.config = cfg
    }

    private func testLLM() {
        llmTesting = true
        llmTestResult = nil
        LLMService.shared.generateReaction(
            companion: store.companion,
            context: "The user just opened settings to test the AI connection."
        ) { [self] reaction in
            llmTesting = false
            if let reaction {
                llmTestResult = Strings.settingsLLMTestOK(reaction)
            } else {
                llmTestResult = Strings.settingsLLMTestFail("No response")
            }
        }
    }

    // MARK: - Advanced

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            card {
                row {
                    Toggle(isOn: $store.loggingEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Strings.settingsLogsEnable)
                            Text(Strings.settingsLogsEnableDesc)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                if store.loggingEnabled {
                    divider
                    row {
                        actionButton("doc.text.magnifyingglass", Strings.settingsLogsOpen) {
                            NSWorkspace.shared.open(URL(fileURLWithPath: BuddyLogger.shared.logsDirectory))
                        }
                        Spacer()
                    }
                }
                divider
                row {
                    Button(action: confirmReset) {
                        HStack {
                            Text(Strings.settingsReset)
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Reusable Components

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.leading, 2)
    }

    private func card<C: View>(@ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
    }

    private func row<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .font(.system(size: 13))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Divider().padding(.leading, 14)
    }

    private func actionButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 12))
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(.accentColor)
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
