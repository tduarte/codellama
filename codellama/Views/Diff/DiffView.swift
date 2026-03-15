//
//  DiffView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI

/// Renders a unified diff string as a syntax-highlighted, scrollable view.
///
/// Parses the raw unified diff into `DiffLine` values and displays each
/// with colored backgrounds (green for added, red for removed).
struct DiffView: View {

    let filename: String
    let unifiedDiff: String

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                Text(filename)
                    .font(.system(.subheadline, design: .monospaced))
                    .bold()
                Spacer()
            }
            .padding(8)
            .background(Color(.windowBackgroundColor))

            Divider()

            // Diff content
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(parsedLines) { line in
                        DiffLineView(line: line)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Parsing

    private var parsedLines: [DiffLine] {
        var lines: [DiffLine] = []
        var lineNumber = 1

        for rawLine in unifiedDiff.components(separatedBy: "\n") {
            // Skip unified diff headers (---, +++, @@, diff --git, index ...)
            if rawLine.hasPrefix("---") || rawLine.hasPrefix("+++") ||
               rawLine.hasPrefix("@@") || rawLine.hasPrefix("diff ") ||
               rawLine.hasPrefix("index ") {
                continue
            }

            if rawLine.hasPrefix("+") {
                let content = String(rawLine.dropFirst())
                lines.append(DiffLine(kind: .added, lineNumber: lineNumber, content: content))
                lineNumber += 1
            } else if rawLine.hasPrefix("-") {
                let content = String(rawLine.dropFirst())
                lines.append(DiffLine(kind: .removed, lineNumber: nil, content: content))
            } else {
                let content = rawLine.hasPrefix(" ") ? String(rawLine.dropFirst()) : rawLine
                lines.append(DiffLine(kind: .context, lineNumber: lineNumber, content: content))
                lineNumber += 1
            }
        }

        return lines
    }
}

#Preview {
    DiffView(
        filename: "ContentView.swift",
        unifiedDiff: """
        --- a/ContentView.swift
        +++ b/ContentView.swift
        @@ -1,7 +1,7 @@
         import SwiftUI
        -struct ContentView: View {
        +struct HomeView: View {
             var body: some View {
        -        Text("Hello, world!")
        +        Text("Welcome!")
             }
         }
        """
    )
    .frame(width: 500, height: 300)
}
