import Foundation

struct AudioMessage: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let duration: TimeInterval
    let fileURL: URL
    let transcription: String?
    let isProcessing: Bool
    
    init(fileURL: URL, duration: TimeInterval) {
        self.timestamp = Date()
        self.duration = duration
        self.fileURL = fileURL
        self.transcription = nil
        self.isProcessing = true
    }
}

struct TravelQuery: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let query: String
    let response: String?
    let isProcessing: Bool
    
    init(query: String) {
        self.timestamp = Date()
        self.query = query
        self.response = nil
        self.isProcessing = true
    }
}
