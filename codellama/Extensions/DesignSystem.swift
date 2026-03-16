//
//  DesignSystem.swift
//  codellama
//

import CoreFoundation
import SwiftUI

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

enum AppRadius {
    static let message: CGFloat = 16
    static let card: CGFloat = 28
    static let chip: CGFloat = 12
    static let panel: CGFloat = 10
}

extension Font {
    static var codeBody: Font { .system(.body, design: .monospaced) }
    static var codeCaption: Font { .system(.caption, design: .monospaced) }
}
