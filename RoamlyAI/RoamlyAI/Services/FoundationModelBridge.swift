import Foundation
import FoundationModels

/// Abstraction over "a real generative model that takes system instructions + a prompt and
/// returns text," with no availability annotation of its own — this lets `GemmaModelManager`
/// hold a reference to it as a plain stored property on iOS 15+, while the concrete
/// `FoundationModelBridge` implementation (iOS 26+ only) is instantiated behind an
/// `if #available` check at the single call site that creates it.
protocol GroundedLLMBridge {
    func respond(system: String, prompt: String) async throws -> String
}

@available(iOS 26.0, *)
final class FoundationModelBridge: GroundedLLMBridge {
    /// Whether Apple Intelligence's on-device model is currently usable. Checked fresh on every
    /// call site that needs it (not cached) since availability can change mid-session — e.g. the
    /// user toggles Apple Intelligence off in Settings, or the model is still installing on first
    /// boot after enabling it.
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// Creates a fresh session per call rather than reusing one across queries. This matches
    /// Apple's own guidance ("for single-turn interactions, create a new session each time") and
    /// fits this app's usage: each query is grounded with different nearby facts, so there's no
    /// meaningful multi-turn context to preserve between unrelated location questions.
    func respond(system: String, prompt: String) async throws -> String {
        let session = LanguageModelSession(instructions: system)
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
