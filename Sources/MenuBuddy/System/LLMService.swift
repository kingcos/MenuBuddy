import Foundation

// MARK: - LLM Service

/// Calls an OpenAI-compatible chat API to generate companion reactions.
/// Supports any provider: OpenAI, Anthropic (via proxy), Ollama, etc.
final class LLMService {
    struct Config {
        var enabled: Bool
        var apiEndpoint: String   // e.g. "https://api.openai.com/v1/chat/completions"
        var apiKey: String
        var model: String         // e.g. "gpt-4o-mini", "claude-3-haiku-20240307"
        var maxTokens: Int

        static let `default` = Config(
            enabled: false,
            apiEndpoint: "https://api.deepseek.com/chat/completions",
            apiKey: "",
            model: "deepseek-chat",
            maxTokens: 60
        )
    }

    struct Usage {
        var totalRequests: Int = 0
        var totalPromptTokens: Int = 0
        var totalCompletionTokens: Int = 0

        var totalTokens: Int { totalPromptTokens + totalCompletionTokens }
    }

    static let shared = LLMService()

    private(set) var usage = Usage()
    private let queue = DispatchQueue(label: "com.menubuddy.llm", qos: .utility)

    var config: Config {
        get {
            Config(
                enabled: UserDefaults.standard.bool(forKey: "llm.enabled"),
                apiEndpoint: UserDefaults.standard.string(forKey: "llm.endpoint") ?? Config.default.apiEndpoint,
                apiKey: UserDefaults.standard.string(forKey: "llm.apiKey") ?? "",
                model: UserDefaults.standard.string(forKey: "llm.model") ?? Config.default.model,
                maxTokens: UserDefaults.standard.object(forKey: "llm.maxTokens") as? Int ?? Config.default.maxTokens
            )
        }
        set {
            UserDefaults.standard.set(newValue.enabled, forKey: "llm.enabled")
            UserDefaults.standard.set(newValue.apiEndpoint, forKey: "llm.endpoint")
            UserDefaults.standard.set(newValue.apiKey, forKey: "llm.apiKey")
            UserDefaults.standard.set(newValue.model, forKey: "llm.model")
            UserDefaults.standard.set(newValue.maxTokens, forKey: "llm.maxTokens")
        }
    }

    private init() {
        // Restore usage counters
        usage.totalRequests = UserDefaults.standard.integer(forKey: "llm.usage.requests")
        usage.totalPromptTokens = UserDefaults.standard.integer(forKey: "llm.usage.promptTokens")
        usage.totalCompletionTokens = UserDefaults.standard.integer(forKey: "llm.usage.completionTokens")
    }

    /// Generate a companion reaction given context.
    /// Calls back on main thread with the reaction text, or nil on failure.
    func generateReaction(
        companion: Companion,
        context: String,
        completion: @escaping (String?) -> Void
    ) {
        let cfg = config
        guard cfg.enabled, !cfg.apiKey.isEmpty else {
            completion(nil)
            return
        }

        let systemPrompt = buildSystemPrompt(companion: companion)
        let userPrompt = context

        logger.debug("LLM request: model=\(cfg.model) context=\"\(context.prefix(80))\"", source: "llm")

        queue.async { [weak self] in
            self?.callAPI(
                endpoint: cfg.apiEndpoint,
                apiKey: cfg.apiKey,
                model: cfg.model,
                maxTokens: cfg.maxTokens,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            ) { result, promptTokens, completionTokens in
                DispatchQueue.main.async {
                    if let pt = promptTokens, let ct = completionTokens {
                        self?.recordUsage(promptTokens: pt, completionTokens: ct)
                    }
                    completion(result)
                }
            }
        }
    }

    /// Build the system prompt describing the companion's personality.
    private func buildSystemPrompt(companion: Companion) -> String {
        let personality = companion.stats.map { stat -> String in
            let name = stat.key.rawValue
            let v = stat.value
            let level: String
            if v >= 75 { level = "very high" }
            else if v >= 50 { level = "high" }
            else if v >= 25 { level = "moderate" }
            else { level = "low" }
            return "\(name) \(v)/100 (\(level))"
        }.joined(separator: ", ")

        var traits: [String] = []
        let s = companion.stats
        if (s[.snark] ?? 0) >= 50 { traits.append("snarky and sarcastic") }
        else { traits.append("gentle and sweet") }
        if (s[.chaos] ?? 0) >= 50 { traits.append("unpredictable and random") }
        if (s[.wisdom] ?? 0) >= 50 { traits.append("thoughtful and philosophical") }
        if (s[.patience] ?? 0) < 25 { traits.append("impatient and restless") }
        if (s[.debugging] ?? 0) >= 50 { traits.append("tech-savvy, loves coding references") }

        let isChinese = Locale.preferredLanguages.first?.hasPrefix("zh") == true

        if isChinese {
            return """
            你是 \(companion.name)，一只住在 macOS 菜单栏里的\(companion.species.localizedName)桌宠。
            稀有度：\(companion.rarity.rawValue)。\(companion.shiny ? "你是稀有的闪光变种！" : "")

            你的性格：\(personality)
            你的特点：\(traits.joined(separator: "；"))

            规则（严格遵守）：
            - 只回复一句话，20字以内最佳，30字上限。
            - 你是一只可爱的小\(companion.species.localizedName)，说话要萌、简短、有个性。
            - 必须用中文回复，不要用英文。
            - 可以用 *动作* 如 *打哈欠* *扭来扭去*。
            - 不要加引号，不要用 emoji。
            - 好的例子：「好热啊…」「*伸懒腰*」「在写代码吗」「呱。」
            - 坏的例子：「I'm chewing on something」「Let me think about that」
            """
        } else {
            return """
            You are \(companion.name), a tiny \(companion.species.rawValue) companion pet in a macOS menu bar.
            Rarity: \(companion.rarity.rawValue). \(companion.shiny ? "You are a rare shiny variant!" : "")

            Your personality: \(personality)
            Your traits: \(traits.joined(separator: "; "))

            Rules (follow strictly):
            - ONE short sentence only. Under 40 characters ideal, 60 max.
            - You are a cute little \(companion.species.rawValue). Talk cute, brief, and in character.
            - Reply in the SAME language as the user context.
            - You can use *actions* like *yawns* or *wiggles*.
            - No quotes around your response. No emojis.
            - Good examples: "so warm in here…", "*stretches*", "coding?", "quack."
            - Bad examples: "I'm currently processing that request", "Let me analyze the situation"
            """
        }
    }

    // MARK: - API Call (OpenAI-compatible)

    private func callAPI(
        endpoint: String,
        apiKey: String,
        model: String,
        maxTokens: Int,
        systemPrompt: String,
        userPrompt: String,
        completion: @escaping (String?, Int?, Int?) -> Void
    ) {
        guard let url = URL(string: endpoint) else {
            completion(nil, nil, nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                logger.warn("LLM API error: \(error?.localizedDescription ?? "unknown")", source: "llm")
                completion(nil, nil, nil)
                return
            }

            // Parse OpenAI-compatible response
            let choices = json["choices"] as? [[String: Any]]
            let message = choices?.first?["message"] as? [String: Any]
            let content = message?["content"] as? String

            // Parse usage
            let usageDict = json["usage"] as? [String: Any]
            let promptTokens = usageDict?["prompt_tokens"] as? Int
            let completionTokens = usageDict?["completion_tokens"] as? Int

            let reaction = content?.trimmingCharacters(in: .whitespacesAndNewlines)
            logger.info("LLM response: \(reaction ?? "nil") (prompt=\(promptTokens ?? 0), completion=\(completionTokens ?? 0))", source: "llm")
            completion(reaction, promptTokens, completionTokens)
        }.resume()
    }

    private func recordUsage(promptTokens: Int, completionTokens: Int) {
        usage.totalRequests += 1
        usage.totalPromptTokens += promptTokens
        usage.totalCompletionTokens += completionTokens

        UserDefaults.standard.set(usage.totalRequests, forKey: "llm.usage.requests")
        UserDefaults.standard.set(usage.totalPromptTokens, forKey: "llm.usage.promptTokens")
        UserDefaults.standard.set(usage.totalCompletionTokens, forKey: "llm.usage.completionTokens")
    }

    func resetUsage() {
        usage = Usage()
        UserDefaults.standard.removeObject(forKey: "llm.usage.requests")
        UserDefaults.standard.removeObject(forKey: "llm.usage.promptTokens")
        UserDefaults.standard.removeObject(forKey: "llm.usage.completionTokens")
    }
}
