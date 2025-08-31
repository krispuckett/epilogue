import SwiftUI
import UIKit

class ShareQuoteService {
    static func shareQuote(_ quote: Note, from viewController: UIViewController? = nil) {
        guard quote.type == .quote else { return }
        
        // Format the quote beautifully
        var formattedText = "\"\(quote.content)\""
        
        // Add attribution if available
        if let author = quote.author {
            formattedText += "\n\n— \(author)"
            
            if let bookTitle = quote.bookTitle {
                formattedText += ", \(bookTitle)"
            }
            
            if let pageNumber = quote.pageNumber {
                formattedText += ", p. \(pageNumber)"
            }
        }
        
        // Add app attribution
        formattedText += "\n\n• Shared from Epilogue"
        
        // Create activity items
        let activityItems: [Any] = [formattedText]
        
        // Create activity controller
        let activityController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Exclude some activity types if desired
        activityController.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks
        ]
        
        // Present from the appropriate view controller
        if let viewController = viewController {
            // iPad popover configuration
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            viewController.present(activityController, animated: true) {
                SensoryFeedback.success()
            }
        } else {
            // Fallback: present from key window
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                
                if let popover = activityController.popoverPresentationController {
                    popover.sourceView = rootViewController.view
                    popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                
                rootViewController.present(activityController, animated: true) {
                    SensoryFeedback.success()
                }
            }
        }
    }
    
    static func shareFormattedQuote(text: String, author: String? = nil, bookTitle: String? = nil, from viewController: UIViewController? = nil) {
        var formattedText = "\"\(text)\""
        
        if let author = author {
            formattedText += "\n\n— \(author)"
            
            if let bookTitle = bookTitle {
                formattedText += ", \(bookTitle)"
            }
        }
        
        formattedText += "\n\n• Shared from Epilogue"
        
        let activityItems: [Any] = [formattedText]
        let activityController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        if let viewController = viewController {
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            viewController.present(activityController, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController {
            
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityController, animated: true)
        }
    }
}