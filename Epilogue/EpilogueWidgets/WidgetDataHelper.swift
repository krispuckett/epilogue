//
//  WidgetDataHelper.swift
//  Shared between app and widgets
//

import Foundation

struct WidgetBookData: Codable {
    let title: String
    let author: String
    let currentPage: Int
    let totalPages: Int
    let coverURL: String?
    let gradientColors: [String]? // Hex colors
    let lastUpdated: Date
}

class WidgetDataHelper {
    static let shared = WidgetDataHelper()

    private let appGroupID = "group.com.epilogue.app"
    private let currentBookKey = "currentReadingBook.json"

    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private var bookDataFileURL: URL? {
        sharedContainerURL?.appendingPathComponent(currentBookKey)
    }

    // MARK: - Write (from main app)
    func saveCurrentBook(_ data: WidgetBookData) {
        print("🔵 WidgetDataHelper.saveCurrentBook called")
        print("   App Group ID: \(appGroupID)")

        guard let containerURL = sharedContainerURL else {
            print("❌ WidgetDataHelper: Failed to get App Group container URL")
            print("   This means App Groups aren't configured!")
            return
        }

        print("✅ Got App Group container: \(containerURL.path)")

        guard let fileURL = bookDataFileURL else {
            print("❌ Failed to create file URL")
            return
        }

        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)

            print("✅ WidgetDataHelper: Saved book data to file:")
            print("   File: \(fileURL.path)")
            print("   Title: \(data.title)")
            print("   Author: \(data.author)")
            print("   Cover URL: \(data.coverURL ?? "none")")
            print("   Colors: \(data.gradientColors?.count ?? 0) colors")
            print("   Pages: \(data.currentPage)/\(data.totalPages)")
            print("   Size: \(encoded.count) bytes")

            // Verify it was written
            if FileManager.default.fileExists(atPath: fileURL.path) {
                print("✅ Verified: File exists!")
            } else {
                print("❌ ERROR: File was NOT written!")
            }
        } catch {
            print("❌ WidgetDataHelper: Failed to save book data: \(error)")
        }
    }

    // MARK: - Read (from widget)
    func getCurrentBook() -> WidgetBookData? {
        print("🔵 WidgetDataHelper.getCurrentBook called (from widget)")
        print("   App Group ID: \(appGroupID)")

        guard let containerURL = sharedContainerURL else {
            print("❌ Widget: Failed to get App Group container URL")
            return nil
        }

        print("✅ Widget: Got App Group container: \(containerURL.path)")

        guard let fileURL = bookDataFileURL else {
            print("❌ Widget: Failed to create file URL")
            return nil
        }

        print("   Looking for file: \(fileURL.path)")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ Widget: File does not exist")

            // List files in the container
            if let files = try? FileManager.default.contentsOfDirectory(atPath: containerURL.path) {
                print("   Files in App Group container: \(files)")
            }
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            print("✅ Widget: Read file (\(data.count) bytes)")

            let decoded = try JSONDecoder().decode(WidgetBookData.self, from: data)
            print("✅ Widget: Loaded book data:")
            print("   Title: \(decoded.title)")
            print("   Cover: \(decoded.coverURL ?? "none")")
            return decoded
        } catch {
            print("❌ Widget: Failed to read/decode book data: \(error)")
            return nil
        }
    }

    // MARK: - Clear
    func clearCurrentBook() {
        guard let fileURL = bookDataFileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
        print("🗑️ Cleared current book data")
    }
}
