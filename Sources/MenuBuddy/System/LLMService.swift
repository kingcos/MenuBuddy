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
        let stats = companion.stats.map { "\($0.key.rawValue): \($0.value)" }.joined(separator: ", ")
        return """
        You are \(companion.name), a small \(companion.species.rawValue) companion pet living in a macOS menu bar.

        Your personality stats: \(stats)
        Your rarity: \(companion.rarity.rawValue)
        \(companion.shiny ? "You are a rare shiny variant!" : "")

        Rules:
        - Respond in ONE short sentence (under 40 characters ideally, max 60).
        - Stay in character as a tiny \(companion.species.rawValue).
        - Be cute, witty, or snarky depending on your SNARK stat.
        - If CHAOS is high, be more random. If WISDOM is high, be more thoughtful.
        - If PATIENCE is low, be more impatient. If DEBUGGING is high, make tech references.
        - React to the context naturally. Don't explain yourself.
        - Use the same language as the context.
        - No quotes, no emojis, no punctuation at end unless it's "?" or "!".
        - You can use *actions* like *yawns* or *wiggles*.
        """
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
