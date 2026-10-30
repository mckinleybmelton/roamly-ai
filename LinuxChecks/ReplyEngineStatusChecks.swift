import Foundation

private struct CheckAttempt: ReplyPathOutcome {
    let foundationProducedReply: Bool
    let templateProducedReply: Bool
}

private func expect(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL \(message)\n", stderr)
        exit(1)
    }
}

let loadingWhileBusy = ReplyEngineStatus.resolve(
    isLoading: true,
    loadFinished: true,
    foundationModelsAvailable: false,
    attempt: nil
)
expect(loadingWhileBusy == .loading, "isLoading returns loading")

let loadingBeforeFinish = ReplyEngineStatus.resolve(
    isLoading: false,
    loadFinished: false,
    foundationModelsAvailable: true,
    attempt: nil
)
expect(loadingBeforeFinish == .loading, "unfinished load returns loading")

let missingClassifier = ReplyEngineStatus.resolve(
    isLoading: false,
    loadFinished: true,
    foundationModelsAvailable: false,
    attempt: nil
)
expect(missingClassifier == .templateReady, "nil attempt without Foundation Models is template ready")

let onDeviceBeforeQuestion = ReplyEngineStatus.resolve(
    isLoading: false,
    loadFinished: true,
    foundationModelsAvailable: true,
    attempt: nil
)
expect(onDeviceBeforeQuestion == .onDeviceReady, "nil attempt with Foundation Models is on-device ready")

let foundationAfterEitherPath = ReplyEngineStatus.resolve(
    isLoading: false,
    loadFinished: true,
    foundationModelsAvailable: true,
    attempt: CheckAttempt(foundationProducedReply: false, templateProducedReply: true)
)
expect(foundationAfterEitherPath == .onDeviceReady, "a produced path with Foundation Models stays on-device ready")

let templateOnly = ReplyEngineStatus.resolve(
    isLoading: false,
    loadFinished: true,
    foundationModelsAvailable: false,
    attempt: CheckAttempt(foundationProducedReply: false, templateProducedReply: true)
)
expect(templateOnly == .templateReady, "template text without Foundation Models is template ready")

let bothFailed = ReplyEngineStatus.resolve(
    isLoading: false,
    loadFinished: true,
    foundationModelsAvailable: false,
    attempt: CheckAttempt(foundationProducedReply: false, templateProducedReply: false)
)
expect(bothFailed == .unavailable, "both paths false is unavailable")

let bothFailedEvenIfFoundationPresent = ReplyEngineStatus.resolve(
    isLoading: false,
    loadFinished: true,
    foundationModelsAvailable: true,
    attempt: CheckAttempt(foundationProducedReply: false, templateProducedReply: false)
)
expect(bothFailedEvenIfFoundationPresent == .unavailable, "both paths false wins over Foundation Models availability")

expect(
    ReplyEngineStatus.unavailableMessage == "Couldn't produce a reply",
    "unavailable message"
)

print("ok")
