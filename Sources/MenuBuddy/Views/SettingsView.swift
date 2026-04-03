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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                generalSection
                progressionSection
                menuBarSection
                triggerSection
                llmSection
                advancedSection
                footerView
            }
            .padding(20)
        }
        .frame(width: 400, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
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
                    Toggle(isOn: $store.muted) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Strings.settingsMute)
                            Text(Strings.settingsMuteDesc)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
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

    // MARK: - Progression

    private var progressionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(Strings.settingsSectionProgression)
            card {
                row {
                    Toggle(isOn: $store.progressionEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Strings.settingsProgressionEnable)
                            Text(Strings.settingsProgressionEnableDesc)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                if store.progressionEnabled {
                divider
                row {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Lv.\(store.level)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: store.companion.rarity.color))
                                Text("\(store.totalXP) XP")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(hex: store.companion.rarity.color).opacity(0.8))
                                        .frame(width: geo.size.width * CGFloat(store.levelProgress), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                        Spacer()
                        if store.availablePoints > 0 {
                            VStack(spacing: 2) {
                                Text("+\(store.availablePoints)")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(hex: store.companion.rarity.color))
                                Text(Strings.settingsProgressionPoints)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                divider
                row {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Strings.settingsProgressionSlots)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            ForEach(CosmeticSlot.allCases, id: \.self) { slot in
                                let unlocked = store.progression.isSlotUnlocked(slot)
                                HStack(spacing: 3) {
                                    Image(systemName: unlocked ? "checkmark.circle.fill" : "lock.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(unlocked ? .green : .secondary)
                                    Text(Strings.slotName(slot))
                                        .font(.system(size: 9))
                                        .foregroundColor(unlocked ? .primary : .secondary)
                                }
                            }
                        }
                    }
                }
                } // end if progressionEnabled
            }
        }
    }

    // MARK: - Menu Bar

    private var menuBarSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(Strings.settingsSectionMenuBar)
            card {
                row {
                    Toggle(isOn: $store.menuBarTwoLine) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Strings.settingsMenuBarTwoLine)
                            Text(Strings.settingsMenuBarTwoLineDesc)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                divider
                row {
                    Toggle(isOn: $store.chattyMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Strings.settingsChattyMode)
                            Text(Strings.settingsChattyModeDesc)
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
                SecureField(text: text, prompt: Text(label).foregroundColor(.secondary.opacity(0.5))) { }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            } else {
                TextField(text: text, prompt: Text(label).foregroundColor(.secondary.opacity(0.5))) { }
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
            }
            card {
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

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 4) {
            Text("MenuBuddy v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Button(action: {
                if let url = URL(string: "https://github.com/kingcos/MenuBuddy") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text("github.com/kingcos/MenuBuddy")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
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
