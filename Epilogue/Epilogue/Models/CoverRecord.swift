import Foundation
import SwiftData

@Model
final class CoverRecord {
    var id: UUID = UUID()
    var isbn10: String?
    var isbn13: String?
    var googleVolumeId: String?
    var bookLocalId: String? // Link to BookModel.localId
    var sourceProvider: String = "googleBooks" // "googleBooks", "openLibrary", "iTunes", "userUpload", "cameraCapture"
    @Attribute(.externalStorage) var imageData: Data?
    var thumbnailData: Data?
    var width: Int = 0
    var height: Int = 0
    var dominantColors: [String] = [] // hex values extracted at cache time
    var confidenceScore: Double = 0.5 // 0-1
    var isUserOverride: Bool = false
    var lastVerified: Date = Date()
    var fetchedAt: Date = Date()
    var imageHash: String? // for dedup

    init(bookLocalId: String, sourceProvider: String) {
        self.bookLocalId = bookLocalId
        self.sourceProvider = sourceProvider
    }
}
