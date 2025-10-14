//
//  Color+Hex.swift
//  Shared color utilities
//

import SwiftUI

extension Color {
    func toHexString() -> String {
        guard let components = UIColor(self).cgColor.components else {
            return "#000000"
        }

        let r: Int
        let g: Int
        let b: Int

        // Handle different color spaces
        switch components.count {
        case 1:
            // Grayscale without alpha
            let white = Int(components[0] * 255.0)
            r = white
            g = white
            b = white
        case 2:
            // Grayscale with alpha
            let white = Int(components[0] * 255.0)
            r = white
            g = white
            b = white
        case 3, 4:
            // RGB or RGBA
            r = Int(components[0] * 255.0)
            g = Int(components[1] * 255.0)
            b = Int(components[2] * 255.0)
        default:
            // Fallback
            return "#000000"
        }

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
