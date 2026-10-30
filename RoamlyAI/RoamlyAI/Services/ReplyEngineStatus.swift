import Foundation

protocol ReplyPathOutcome {
    var foundationProducedReply: Bool { get }
    var templateProducedReply: Bool { get }
}

struct CompletedReplyAttempt: ReplyPathOutcome {
    let foundationProducedReply: Bool
    let templateProducedReply: Bool
}

enum ReplyEnginePhase: Equatable {
    case loading
    case unavailable
    case onDeviceReady
    case templateReady
}

enum ReplyEngineStatus {
    static let unavailableMessage = "Couldn't produce a reply"

    static func resolve(
        isLoading: Bool,
        loadFinished: Bool,
        foundationModelsAvailable: Bool,
        attempt: ReplyPathOutcome?
    ) -> ReplyEnginePhase {
        if isLoading || !loadFinished {
            return .loading
        }
        if let attempt, !attempt.foundationProducedReply, !attempt.templateProducedReply {
            return .unavailable
        }
        if foundationModelsAvailable {
            return .onDeviceReady
        }
        return .templateReady
    }
}
