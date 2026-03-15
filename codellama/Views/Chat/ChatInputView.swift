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
    var selectedModel: String
    var availableModels: [OllamaModel]
    var isCurrentModelAvailable: Bool
    var modelSelection: Binding<String>
    var onSend: () -> Void
    var onStop: () -> Void
    var onRemoveAttachment: (PendingChatAttachment) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            attachmentTray

            VStack(spacing: 8) {
                textField

                HStack(spacing: 8) {
                    Spacer()
                    modelPickerButton
                    actionButton
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.separator, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Text Field

    private var textField: some View {
        TextField("Send a message or drop files...", text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(1...10)
            .focused($isFocused)
            .disabled(isGenerating)
            .onAppear {
                isFocused = true
            }
            .onKeyPress(keys: [.return], phases: .down) { keyPress in
                if keyPress.modifiers.contains(.shift) {
                    return .ignored
                }
                if canSend && !isGenerating {
                    onSend()
                }
                return .handled
            }
    }

    // MARK: - Model Picker

    private var modelPickerButton: some View {
        Menu {
            if !isCurrentModelAvailable {
                Text("\(selectedModel) (Unavailable)")
            }

            ForEach(availableModels) { model in
                Button {
                    modelSelection.wrappedValue = model.name
                } label: {
                    Text(model.name)
                    if model.name == selectedModel {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Text(selectedModel)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(isGenerating)
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button(action: isGenerating ? onStop : onSend) {
            Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                .font(.title2)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.borderless)
        .disabled(!isGenerating && !canSend)
        .help(isGenerating ? "Stop generating" : "Send message")
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
                                        .fill(.fill.quaternary)
                                )
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.fill.quaternary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isDropTargeted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.separator), style: StrokeStyle(lineWidth: isDropTargeted ? 1 : 0.5, dash: isDropTargeted ? [6] : []))
            )
        }
    }
}

#Preview("Empty") {
    @Previewable @State var text = ""
    @Previewable @State var model = "llama3.1:8b"
    ChatInputView(
        text: $text,
        attachments: [],
        canSend: false,
        isGenerating: false,
        isProcessingDrop: false,
        isDropTargeted: false,
        selectedModel: "llama3.1:8b",
        availableModels: [],
        isCurrentModelAvailable: true,
        modelSelection: $model,
        onSend: {},
        onStop: {},
        onRemoveAttachment: { _ in }
    )
    .padding()
    .frame(width: 500)
}

#Preview("With Text") {
    @Previewable @State var text = "How do I reverse a linked list in Swift?"
    @Previewable @State var model = "llama3.1:8b"
    ChatInputView(
        text: $text,
        attachments: [],
        canSend: true,
        isGenerating: false,
        isProcessingDrop: false,
        isDropTargeted: false,
        selectedModel: "llama3.1:8b",
        availableModels: [],
        isCurrentModelAvailable: true,
        modelSelection: $model,
        onSend: {},
        onStop: {},
        onRemoveAttachment: { _ in }
    )
    .padding()
    .frame(width: 500)
}

#Preview("Generating") {
    @Previewable @State var text = ""
    @Previewable @State var model = "llama3.1:8b"
    ChatInputView(
        text: $text,
        attachments: [],
        canSend: false,
        isGenerating: true,
        isProcessingDrop: false,
        isDropTargeted: false,
        selectedModel: "llama3.1:8b",
        availableModels: [],
        isCurrentModelAvailable: true,
        modelSelection: $model,
        onSend: {},
        onStop: {},
        onRemoveAttachment: { _ in }
    )
    .padding()
    .frame(width: 500)
}

#Preview("Drop Target") {
    @Previewable @State var text = ""
    @Previewable @State var model = "llama3.1:8b"
    ChatInputView(
        text: $text,
        attachments: [],
        canSend: false,
        isGenerating: false,
        isProcessingDrop: false,
        isDropTargeted: true,
        selectedModel: "llama3.1:8b",
        availableModels: [],
        isCurrentModelAvailable: true,
        modelSelection: $model,
        onSend: {},
        onStop: {},
        onRemoveAttachment: { _ in }
    )
    .padding()
    .frame(width: 500)
}
