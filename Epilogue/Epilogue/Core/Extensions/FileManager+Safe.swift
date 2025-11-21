import Foundation

enum FileSystemError: LocalizedError {
    case directoryUnavailable(FileManager.SearchPathDirectory)
    case fileOperationFailed(String)

    var errorDescription: String? {
        switch self {
        case .directoryUnavailable(let directory):
            return "Unable to access \(directory) directory. Please check storage availability."
        case .fileOperationFailed(let operation):
            return "File operation failed: \(operation)"
        }
    }
}

extension FileManager {
    /// Safely get URL for directory without force unwrapping
    func safeURL(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask = .userDomainMask) throws -> URL {
        guard let url = urls(for: directory, in: domain).first else {
            throw FileSystemError.directoryUnavailable(directory)
        }
        return url
    }
}
