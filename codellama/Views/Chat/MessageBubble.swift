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

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        if isUser {
            HStack {
                Spacer(minLength: 0)
                userBubble
            }
        } else {
            HStack {
                nonUserContent
                Spacer(minLength: 0)
            }
        }
    }

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            imageAttachmentSummary
            imageAttachmentPreviews

            StreamingTextView(
                text: message.content,
                isStreaming: message.isStreaming
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.tint.quaternary)
        )
        .containerRelativeFrame(.horizontal, alignment: .trailing) { length, _ in
            min(length * 0.7, length - 60)
        }
    }

    private var nonUserContent: some View {
        VStack(alignment: .leading, spacing: 4) {
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
        .padding(message.role == "system" ? 12 : 0)
        .background {
            if message.role == "system" {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.fill.tertiary)
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
            Label("Assistant", systemImage: "sparkle")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
        case "system":
            Label("System", systemImage: "info.circle")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
        default:
            Label(message.role.capitalized, systemImage: "wrench")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
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
                                    .fill(.fill.quaternary)
                            )
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var typingIndicator: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .phaseAnimator([0.3, 1.0, 0.3]) { view, phase in
                        view.opacity(phase)
                    } animation: { _ in
                        .easeInOut(duration: 0.6).delay(Double(index) * 0.2)
                    }
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
