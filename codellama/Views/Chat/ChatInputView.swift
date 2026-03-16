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
    var installedSkillNames: [String] = []

    @FocusState private var isFocused: Bool
    @State private var editorHeight: CGFloat = 60
    @State private var slashSuggestions: [SlashCommand] = []
    @State private var skillSuggestions: [String] = []
    @State private var slashSelectedIndex: Int = 0
    @State private var showSlashPopup: Bool = false
    @State private var showSkillPopup: Bool = false

    private let minEditorHeight: CGFloat = 40
    private let maxEditorHeight: CGFloat = 300
    private var isBusy: Bool { isGenerating || isAgentBusy }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            attachmentTray

            if showSlashPopup && !slashSuggestions.isEmpty {
                SlashCommandPopupView(
                    suggestions: slashSuggestions,
                    selectedIndex: slashSelectedIndex,
                    onSelect: { applyCompletion($0) }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if showSkillPopup && !skillSuggestions.isEmpty {
                SlashSkillPopupView(
                    suggestions: skillSuggestions,
                    selectedIndex: slashSelectedIndex,
                    onSelect: { applySkillCompletion($0) }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

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
        .animation(.spring(duration: 0.2, bounce: 0.1), value: showSlashPopup)
        .animation(.spring(duration: 0.2, bounce: 0.1), value: showSkillPopup)
    }

    // MARK: - Resize Handle

    private var resizeHandle: some View {
        Rectangle()
            .fill(.clear)
            .frame(height: 8)
            .overlay {
                Capsule()
                    .fill(.secondary.opacity(0.3))
                    .frame(width: 36, height: 5)
            }
            .contentShape(Rectangle())
            .accessibilityLabel("Resize input area")
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Dragging up (negative translation) increases height
                        let newHeight = editorHeight - value.translation.height
                        withAnimation(.linear(duration: 0.05)) {
                            editorHeight = min(max(newHeight, minEditorHeight), maxEditorHeight)
                        }
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
            .onChange(of: text) {
                updateSlashState()
            }
            .onKeyPress(phases: .down) { press in
                guard showSlashPopup || showSkillPopup else { return .ignored }
                let count = showSlashPopup ? slashSuggestions.count : skillSuggestions.count
                switch press.key {
                case .upArrow:
                    slashSelectedIndex = max(0, slashSelectedIndex - 1)
                    return .handled
                case .downArrow:
                    slashSelectedIndex = min(count - 1, slashSelectedIndex + 1)
                    return .handled
                case KeyEquivalent("\t"):
                    if showSlashPopup && !slashSuggestions.isEmpty {
                        applyCompletion(slashSuggestions[slashSelectedIndex])
                    } else if showSkillPopup && !skillSuggestions.isEmpty {
                        applySkillCompletion(skillSuggestions[slashSelectedIndex])
                    }
                    return .handled
                case .escape:
                    showSlashPopup = false
                    showSkillPopup = false
                    return .handled
                default:
                    return .ignored
                }
            }
            .onKeyPress(keys: [.return], phases: .down) { keyPress in
                if keyPress.modifiers.contains(.shift) {
                    return .ignored
                }
                // Popup selection takes priority over send
                if showSlashPopup && !slashSuggestions.isEmpty {
                    applyCompletion(slashSuggestions[slashSelectedIndex])
                    return .handled
                }
                if showSkillPopup && !skillSuggestions.isEmpty {
                    applySkillCompletion(skillSuggestions[slashSelectedIndex])
                    return .handled
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

    // MARK: - Slash Command Helpers

    private func updateSlashState() {
        guard text.hasPrefix("/"), !text.contains("\n") else {
            showSlashPopup = false
            showSkillPopup = false
            return
        }

        let withoutSlash = String(text.dropFirst())
        let components = withoutSlash.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        let commandToken = components.first.map(String.init) ?? ""
        let hasSpace = withoutSlash.contains(" ")

        if !hasSpace {
            // Phase 1: show matching commands
            let matches = SlashCommandRegistry.matching(prefix: commandToken)
            slashSuggestions = matches
            showSlashPopup = !matches.isEmpty
            showSkillPopup = false
            slashSelectedIndex = 0
        } else if commandToken.lowercased() == "skill" {
            // Phase 2: show matching skill names
            let arg = components.count > 1 ? String(components[1]).lowercased() : ""
            skillSuggestions = installedSkillNames.filter {
                arg.isEmpty || $0.lowercased().hasPrefix(arg) || $0.lowercased().contains(arg)
            }
            showSkillPopup = !skillSuggestions.isEmpty
            showSlashPopup = false
            slashSelectedIndex = 0
        } else {
            showSlashPopup = false
            showSkillPopup = false
        }
    }

    private func applyCompletion(_ command: SlashCommand) {
        text = "/\(command.id) "
        showSlashPopup = false
        slashSelectedIndex = 0
        // If /skill was chosen, immediately show skill suggestions
        if command.id == "skill" {
            updateSlashState()
        }
    }

    private func applySkillCompletion(_ skillName: String) {
        text = "/skill \(skillName)"
        showSkillPopup = false
        slashSelectedIndex = 0
    }
}
