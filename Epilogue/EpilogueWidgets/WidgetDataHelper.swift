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
        #if DEBUG
        print("🔵 WidgetDataHelper.saveCurrentBook called")
        #endif
        #if DEBUG
        print("   App Group ID: \(appGroupID)")
        #endif

        guard let containerURL = sharedContainerURL else {
            #if DEBUG
            print("❌ WidgetDataHelper: Failed to get App Group container URL")
            #endif
            #if DEBUG
            print("   This means App Groups aren't configured!")
            #endif
            return
        }

        #if DEBUG
        print("✅ Got App Group container: \(containerURL.path)")
        #endif

        guard let fileURL = bookDataFileURL else {
            #if DEBUG
            print("❌ Failed to create file URL")
            #endif
            return
        }

        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)

            #if DEBUG
            print("✅ WidgetDataHelper: Saved book data to file:")
            #endif
            #if DEBUG
            print("   File: \(fileURL.path)")
            #endif
            #if DEBUG
            print("   Title: \(data.title)")
            #endif
            #if DEBUG
            print("   Author: \(data.author)")
            #endif
            #if DEBUG
            print("   Cover URL: \(data.coverURL ?? "none")")
            #endif
            #if DEBUG
            print("   Colors: \(data.gradientColors?.count ?? 0) colors")
            #endif
            #if DEBUG
            print("   Pages: \(data.currentPage)/\(data.totalPages)")
            #endif
            #if DEBUG
            print("   Size: \(encoded.count) bytes")
            #endif

            // Verify it was written
            if FileManager.default.fileExists(atPath: fileURL.path) {
                #if DEBUG
                print("✅ Verified: File exists!")
                #endif
            } else {
                #if DEBUG
                print("❌ ERROR: File was NOT written!")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ WidgetDataHelper: Failed to save book data: \(error)")
            #endif
        }
    }

    // MARK: - Read (from widget)
    func getCurrentBook() -> WidgetBookData? {
        #if DEBUG
        print("🔵 WidgetDataHelper.getCurrentBook called (from widget)")
        #endif
        #if DEBUG
        print("   App Group ID: \(appGroupID)")
        #endif

        guard let containerURL = sharedContainerURL else {
            #if DEBUG
            print("❌ Widget: Failed to get App Group container URL")
            #endif
            return nil
        }

        #if DEBUG
        print("✅ Widget: Got App Group container: \(containerURL.path)")
        #endif

        guard let fileURL = bookDataFileURL else {
            #if DEBUG
            print("❌ Widget: Failed to create file URL")
            #endif
            return nil
        }

        #if DEBUG
        print("   Looking for file: \(fileURL.path)")
        #endif

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            #if DEBUG
            print("❌ Widget: File does not exist")
            #endif

            // List files in the container
            if let files = try? FileManager.default.contentsOfDirectory(atPath: containerURL.path) {
                #if DEBUG
                print("   Files in App Group container: \(files)")
                #endif
            }
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            #if DEBUG
            print("✅ Widget: Read file (\(data.count) bytes)")
            #endif

            let decoded = try JSONDecoder().decode(WidgetBookData.self, from: data)
            #if DEBUG
            print("✅ Widget: Loaded book data:")
            #endif
            #if DEBUG
            print("   Title: \(decoded.title)")
            #endif
            #if DEBUG
            print("   Cover: \(decoded.coverURL ?? "none")")
            #endif
            return decoded
        } catch {
            #if DEBUG
            print("❌ Widget: Failed to read/decode book data: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Clear
    func clearCurrentBook() {
        guard let fileURL = bookDataFileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
        #if DEBUG
        print("🗑️ Cleared current book data")
        #endif
    }
}
