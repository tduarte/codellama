//
//  ChatInputView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    let attachments: [PendingChatAttachment]
    var canSend: Bool
    var isGenerating: Bool
    var isProcessingDrop: Bool
    var isDropTargeted: Bool
    var onSend: () -> Void
    var onStop: () -> Void
    var onRemoveAttachment: (PendingChatAttachment) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            attachmentTray

            HStack(alignment: .bottom, spacing: 8) {
                textEditor
                actionButton
            }
        }
    }

    // MARK: - Text Editor

    private var textEditor: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text("Send a message or drop files...")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(.body)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(minHeight: 40, maxHeight: 120)
                .fixedSize(horizontal: false, vertical: true)
                .onKeyPress(keys: [.return], phases: .down) { keyPress in
                    if keyPress.modifiers.contains(.shift) {
                        return .ignored // Allow newline
                    }
                    // Send on plain Enter
                    if canSend && !isGenerating {
                        onSend()
                    }
                    return .handled
                }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .primary.opacity(0.1), radius: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 1)
        )
        .onAppear {
            isFocused = true
        }
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Group {
            if isGenerating {
                Button(action: onStop) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Stop generating")
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .help("Send message")
            }
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var attachmentTray: some View {
        if isDropTargeted || isProcessingDrop || !attachments.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                if isDropTargeted {
                    Label("Drop files to attach them to the next message", systemImage: "tray.and.arrow.down")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tint)
                } else if isProcessingDrop {
                    Label("Reading dropped files…", systemImage: "doc.badge.plus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                } else if !attachments.isEmpty {
                    Text("\(attachments.count) file\(attachments.count == 1 ? "" : "s") attached")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if !attachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(attachments) { attachment in
                                HStack(spacing: 8) {
                                    Image(systemName: attachment.kind.systemImage)
                                        .foregroundStyle(.tint)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(attachment.displayName)
                                            .font(.subheadline.weight(.medium))
                                            .lineLimit(1)

                                        Text(attachment.detailText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Button {
                                        onRemoveAttachment(attachment)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.secondary.opacity(0.08))
                                )
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isDropTargeted ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: isDropTargeted ? [6] : []))
            )
        }
    }
}
