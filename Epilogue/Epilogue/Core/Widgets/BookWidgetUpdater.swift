//
//  BookWidgetUpdater.swift
//  Updates widget data when books change
//

import Foundation
import WidgetKit
import UIKit

class BookWidgetUpdater {
    static let shared = BookWidgetUpdater()

    /// Call this whenever the currently reading book changes or is updated
    func updateCurrentBook(from book: BookModel) {
        Task {
            // Cache cover image to App Group container for widget
            var coverImagePath: String? = nil
            if let coverURL = book.coverImageURL {
                coverImagePath = await cacheBookCoverForWidget(from: coverURL, bookID: book.localId)
            }

            let widgetData = WidgetBookData(
                title: book.title,
                author: book.author,
                currentPage: book.currentPage,
                totalPages: book.pageCount ?? 0,
                coverURL: coverImagePath, // Use local file path instead of URL
                gradientColors: book.extractedColors,
                lastUpdated: Date()
            )

            // Save to UserDefaults for widgets to read
            WidgetDataHelper.shared.saveCurrentBook(widgetData)

            // Tell widgets to refresh
            WidgetCenter.shared.reloadAllTimelines()

            #if DEBUG
            print("📱 BookWidgetUpdater: Updated widget with \(book.title)")
            #endif
        }
    }

    private func cacheBookCoverForWidget(from urlString: String, bookID: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }

        // Get App Group container
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.epilogue.app") else {
            #if DEBUG
            print("❌ Could not get App Group container for widget cover")
            #endif
            return nil
        }

        let coverFileName = "\(bookID)_cover.jpg"
        let coverFileURL = containerURL.appendingPathComponent(coverFileName)

        // Check if already cached AND the file is a real image (not 0 bytes / truncated)
        if FileManager.default.fileExists(atPath: coverFileURL.path) {
            let attrs = try? FileManager.default.attributesOfItem(atPath: coverFileURL.path)
            let size = (attrs?[.size] as? NSNumber)?.intValue ?? 0
            if size > 1024 {
                #if DEBUG
                print("✅ Widget cover already cached: \(coverFileURL.path) (\(size) bytes)")
                #endif
                return coverFileURL.path
            } else {
                #if DEBUG
                print("⚠️ Cached widget cover is too small (\(size) bytes) — re-downloading")
                #endif
                try? FileManager.default.removeItem(at: coverFileURL)
            }
        }

        // Download and cache
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data),
               let jpegData = image.jpegData(compressionQuality: 0.8) {
                try jpegData.write(to: coverFileURL)
                #if DEBUG
                print("✅ Cached widget cover to: \(coverFileURL.path)")
                #endif
                return coverFileURL.path
            }
        } catch {
            #if DEBUG
            print("❌ Failed to cache widget cover: \(error)")
            #endif
        }

        return nil
    }

    /// Call this when there's no currently reading book
    func clearCurrentBook() {
        WidgetDataHelper.shared.clearCurrentBook()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
