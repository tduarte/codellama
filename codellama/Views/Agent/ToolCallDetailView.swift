//
//  ToolCallDetailView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI

/// Detailed view showing a single tool call's arguments and result.
///
/// Arguments are rendered as pretty-printed JSON in a monospaced font.
struct ToolCallDetailView: View {

    let toolCall: ToolCall
    let result: ToolResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // MARK: Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(toolCall.toolName)
                        .font(.title2)
                        .bold()

                    Text("Server: \(toolCall.serverName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("ID: \(toolCall.id)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Divider()

                // MARK: Arguments
                VStack(alignment: .leading, spacing: 6) {
                    Text("Arguments")
                        .font(.headline)

                    if toolCall.arguments.isEmpty {
                        Text("(no arguments)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(prettyPrintedArguments)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color(.textBackgroundColor).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                // MARK: Result
                if let result {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Result")
                                .font(.headline)
                            if result.isError {
                                Label("Error", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }

                        Text(result.content.isEmpty ? "(empty response)" : result.content)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(result.isError ? .red : .primary)
                            .padding(8)
                            .background(Color(.textBackgroundColor).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private var prettyPrintedArguments: String {
        guard !toolCall.arguments.isEmpty else { return "" }
        // Convert JSONValue dict to a basic pretty-printed representation
        let pairs = toolCall.arguments.sorted(by: { $0.key < $1.key }).map { key, value in
            "  \"\(key)\": \(formatJSONValue(value))"
        }
        return "{\n" + pairs.joined(separator: ",\n") + "\n}"
    }

    private func formatJSONValue(_ value: JSONValue) -> String {
        switch value {
        case .string(let s):    return "\"\(s)\""
        case .number(let n):    return n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
        case .bool(let b):      return b ? "true" : "false"
        case .null:             return "null"
        case .array(let arr):   return "[\(arr.map { formatJSONValue($0) }.joined(separator: ", "))]"
        case .object(let obj):
            let pairs = obj.sorted(by: { $0.key < $1.key }).map { "\"\($0.key)\": \(formatJSONValue($0.value))" }
            return "{ \(pairs.joined(separator: ", ")) }"
        }
    }
}
