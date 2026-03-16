//
//  SlashCommandPopupView.swift
//  codellama
//

import SwiftUI

// MARK: - Command Popup

struct SlashCommandPopupView: View {
    let suggestions: [SlashCommand]
    let selectedIndex: Int
    let onSelect: (SlashCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, command in
                CommandSuggestionRow(
                    command: command,
                    isSelected: index == selectedIndex,
                    onSelect: { onSelect(command) }
                )
                if index < suggestions.count - 1 {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.separator, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

private struct CommandSuggestionRow: View {
    let command: SlashCommand
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: command.systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 20)

                HStack(spacing: 6) {
                    Text("/\(command.id)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    if command.argumentHint != "—" {
                        Text(command.argumentHint)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(command.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 36)
            .background {
                if isSelected {
                    Color.accentColor.opacity(0.12)
                } else if isHovered {
                    Color.primary.opacity(0.04)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Skill Suggestions Popup

struct SlashSkillPopupView: View {
    let suggestions: [String]
    let selectedIndex: Int
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element) { index, skillName in
                SkillSuggestionRow(
                    name: skillName,
                    isSelected: index == selectedIndex,
                    onSelect: { onSelect(skillName) }
                )
                if index < suggestions.count - 1 {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.separator, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

private struct SkillSuggestionRow: View {
    let name: String
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 20)

                Text(name)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 36)
            .background {
                if isSelected {
                    Color.accentColor.opacity(0.12)
                } else if isHovered {
                    Color.primary.opacity(0.04)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
