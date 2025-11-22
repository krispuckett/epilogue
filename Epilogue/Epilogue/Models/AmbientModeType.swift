import Foundation
import SwiftData

/// Represents the type of ambient conversation mode
enum AmbientModeType: Codable, Hashable {
    /// Generic reading companion (no specific book context)
    case generic

    /// Book-specific discussion (with book context)
    case bookSpecific(bookID: PersistentIdentifier)

    var isGeneric: Bool {
        if case .generic = self {
            return true
        }
        return false
    }

    var bookID: PersistentIdentifier? {
        switch self {
        case .bookSpecific(let id):
            return id
        default:
            return nil
        }
    }

    /// Thread identifier for conversation memory
    var threadID: String {
        switch self {
        case .generic:
            return "generic-ambient"
        case .bookSpecific(let bookID):
            return "book-\(bookID.hashValue)"
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type, bookID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "generic":
            self = .generic
        case "bookSpecific":
            let bookID = try container.decode(PersistentIdentifier.self, forKey: .bookID)
            self = .bookSpecific(bookID: bookID)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown ambient mode type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .generic:
            try container.encode("generic", forKey: .type)
        case .bookSpecific(let bookID):
            try container.encode("bookSpecific", forKey: .type)
            try container.encode(bookID, forKey: .bookID)
        }
    }
}
