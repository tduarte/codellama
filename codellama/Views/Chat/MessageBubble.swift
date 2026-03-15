//
//  MessageBubble.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI
import SwiftData
import ImageIO

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                roleLabel
                imageAttachmentSummary
                imageAttachmentPreviews

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

    @ViewBuilder
    private var imageAttachmentSummary: some View {
        if !message.imageAttachments.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "photo")
                Text("\(message.imageAttachments.count) image\(message.imageAttachments.count == 1 ? "" : "s") attached")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var imageAttachmentPreviews: some View {
        if !message.imageAttachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(message.imageAttachments) { attachment in
                        if let image = decodeImage(from: attachment.base64Data) {
                            VStack(alignment: .leading, spacing: 4) {
                                Image(decorative: image, scale: 1.0)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 140, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                Text(attachment.fileName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .frame(width: 140, alignment: .leading)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: "photo.slash")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text(attachment.fileName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .frame(width: 140, height: 100, alignment: .topLeading)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.secondary.opacity(0.08))
                            )
                        }
                    }
                }
                .padding(.vertical, 2)
            }
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

    private func decodeImage(from base64: String) -> CGImage? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ChatMessage.self, Conversation.self, configurations: config)

    let userMsg = ChatMessage(role: "user", content: "What is the time complexity of quicksort?")
    let assistantMsg = ChatMessage(
        role: "assistant",
        content: "Quicksort has **O(n log n)** average complexity.\n\n```swift\nfunc quicksort(_ arr: [Int]) -> [Int] {\n    guard arr.count > 1 else { return arr }\n    let pivot = arr[arr.count / 2]\n    return quicksort(arr.filter { $0 < pivot })\n        + arr.filter { $0 == pivot }\n        + quicksort(arr.filter { $0 > pivot })\n}\n```"
    )
    let streamingMsg = ChatMessage(role: "assistant", content: "Thinking…", isStreaming: true)
    let systemMsg = ChatMessage(role: "system", content: "You are a helpful assistant.")

    container.mainContext.insert(userMsg)
    container.mainContext.insert(assistantMsg)
    container.mainContext.insert(streamingMsg)
    container.mainContext.insert(systemMsg)

    return ScrollView {
        VStack(spacing: 12) {
            MessageBubble(message: systemMsg)
            MessageBubble(message: userMsg)
            MessageBubble(message: assistantMsg)
            MessageBubble(message: streamingMsg)
        }
        .padding()
    }
    .frame(width: 620, height: 520)
    .modelContainer(container)
}
