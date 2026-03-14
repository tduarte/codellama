//
//  MessageBubble.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                roleLabel

                if message.isStreaming && message.content.isEmpty {
                    typingIndicator
                } else {
                    StreamingTextView(
                        text: message.content,
                        isStreaming: message.isStreaming
                    )
                }
            }
            .padding(12)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if message.role != "user" {
                Spacer(minLength: 60)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var roleLabel: some View {
        switch message.role {
        case "user":
            EmptyView()
        case "assistant":
            Label("Assistant", systemImage: "cpu")
                .font(.caption)
                .foregroundStyle(.secondary)
        case "system":
            Label("System", systemImage: "gear")
                .font(.caption)
                .foregroundStyle(.secondary)
        default:
            Label(message.role.capitalized, systemImage: "wrench")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var bubbleBackground: some ShapeStyle {
        switch message.role {
        case "user":
            return AnyShapeStyle(.tint.opacity(0.15))
        case "system":
            return AnyShapeStyle(.yellow.opacity(0.1))
        default:
            return AnyShapeStyle(.secondary.opacity(0.1))
        }
    }

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(0.4)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: message.isStreaming
                    )
            }
        }
        .padding(.vertical, 4)
    }
}
