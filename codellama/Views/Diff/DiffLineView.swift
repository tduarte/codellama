//
//  DiffLineView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI

// MARK: - DiffLine Model

/// A single line from a unified diff, classified by its kind.
struct DiffLine: Identifiable {
    enum Kind {
        case added
        case removed
        case context
    }

    let id = UUID()
    let kind: Kind
    let lineNumber: Int?
    let content: String
}

// MARK: - DiffLineView

/// Renders a single `DiffLine` with a colored background and line number gutter.
struct DiffLineView: View {

    let line: DiffLine

    var body: some View {
        HStack(spacing: 0) {
            // Line number gutter
            Text(line.lineNumber.map { "\($0)" } ?? "")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)

            // Diff prefix character
            Text(prefixCharacter)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(prefixColor)
                .frame(width: 12)

            // Line content
            Text(line.content)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
        .background(backgroundColor)
    }

    // MARK: - Helpers

    private var prefixCharacter: String {
        switch line.kind {
        case .added:   return "+"
        case .removed: return "-"
        case .context: return " "
        }
    }

    private var prefixColor: Color {
        switch line.kind {
        case .added:   return .green
        case .removed: return .red
        case .context: return .secondary
        }
    }

    private var backgroundColor: Color {
        switch line.kind {
        case .added:   return Color.green.opacity(0.12)
        case .removed: return Color.red.opacity(0.12)
        case .context: return Color.clear
        }
    }
}
