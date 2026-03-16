//
//  ChatInputView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    var composerMode: Binding<ComposerMode>
    let attachments: [PendingChatAttachment]
    var canSend: Bool
    var isGenerating: Bool
    var isAgentBusy: Bool
    var isProcessingDrop: Bool
    var isDropTargeted: Bool
    var selectedModel: String
    var availableModels: [OllamaModel]
    var isCurrentModelAvailable: Bool
    var modelSelection: Binding<String>
    var onSendChat: () -> Void
    var onSendAgent: () -> Void
    var onStop: () -> Void
    var onRemoveAttachment: (PendingChatAttachment) -> Void

    @FocusState private var isFocused: Bool
    @State private var editorHeight: CGFloat = 60

    private let minEditorHeight: CGFloat = 40
    private let maxEditorHeight: CGFloat = 300
    private var isBusy: Bool { isGenerating || isAgentBusy }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            attachmentTray

            VStack(spacing: 0) {
                resizeHandle

                textField

                HStack(spacing: 8) {
                    modePicker
                    Spacer()
                    modelPickerButton
                    actionButton
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .padding(.top, 4)
            }
            .glassEffect(.regular, in: .rect(
                corners: .concentric(minimum: 16),
                isUniform: false
            ))
        }
    }

    // MARK: - Resize Handle

    private var resizeHandle: some View {
        Rectangle()
            .fill(.clear)
            .frame(height: 8)
            .overlay {
                Capsule()
                    .fill(.separator)
                    .frame(width: 36, height: 4)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Dragging up (negative translation) increases height
                        let newHeight = editorHeight - value.translation.height
                        editorHeight = min(max(newHeight, minEditorHeight), maxEditorHeight)
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    NSCursor.resizeUpDown.push()
                case .ended:
                    NSCursor.pop()
                }
            }
    }

    // MARK: - Text Field

    private var textField: some View {
        TextEditor(text: $text)
            .font(.body)
            .scrollContentBackground(.hidden)
            .focused($isFocused)
            .disabled(isBusy)
            .frame(height: editorHeight)
            .padding(.horizontal, 8)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(composerMode.wrappedValue == .chat ? "Send a message or drop files..." : "Describe the agent task or invoke /skill <name>...")
                        .foregroundStyle(.placeholder)
                        .padding(.leading, 13)
                        .padding(.top, 1)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                isFocused = true
            }
            .onKeyPress(keys: [.return], phases: .down) { keyPress in
                if keyPress.modifiers.contains(.shift) {
                    return .ignored
                }
                if canSend && !isBusy {
                    sendCurrentMode()
                }
                return .handled
            }
    }

    // MARK: - Model Picker

    private var modePicker: some View {
        Picker("Mode", selection: composerMode) {
            ForEach(ComposerMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 150)
        .disabled(isBusy)
    }

    private var selectedModelDisplayName: String {
        availableModels.first(where: { $0.name == selectedModel })?.displayName ?? selectedModel
    }

    private var modelPickerButton: some View {
        Menu {
            if !isCurrentModelAvailable {
                Text("\(selectedModel) (Unavailable)")
            }

            ForEach(availableModels) { model in
                Button {
                    modelSelection.wrappedValue = model.name
                } label: {
                    Text(model.displayName)
                    Text(model.name)
                    if model.name == selectedModel {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Text(selectedModelDisplayName)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(isBusy)
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button(action: isGenerating ? onStop : sendCurrentMode) {
            Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                .font(.title)
                .foregroundStyle(isGenerating ? AnyShapeStyle(.red) : AnyShapeStyle(.tint))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.borderless)
        .disabled(!isGenerating && (!canSend || isAgentBusy))
        .help(isGenerating ? "Stop generating" : composerMode.wrappedValue == .chat ? "Send chat message" : "Send agent request")
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
                } else if composerMode.wrappedValue == .agent, !attachments.isEmpty {
                    Label("Attachments stay in chat mode only.", systemImage: "exclamationmark.triangle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
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

    private func sendCurrentMode() {
        switch composerMode.wrappedValue {
        case .chat:
            onSendChat()
        case .agent:
            onSendAgent()
        }
    }
}
