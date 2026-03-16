//
//  CommandPaletteView.swift
//  codellama
//
//  Created by Codex on 3/14/26.
//

import SwiftUI

struct CommandPaletteItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let category: String
    let keywords: [String]
    let action: () -> Void

    func matches(query: String) -> Bool {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        guard !normalizedQuery.isEmpty else { return true }

        let haystack = ([title, subtitle, category] + keywords)
            .joined(separator: "\n")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        return haystack.contains(normalizedQuery)
    }
}

struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    let items: [CommandPaletteItem]

    @FocusState private var isQueryFocused: Bool
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    private let maxRowSubtitleCharacters = 160

    private var filteredItems: [CommandPaletteItem] {
        items.filter { $0.matches(query: query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search commands, conversations, skills, or servers", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isQueryFocused)
                .padding(16)
                .onSubmit {
                    if selectedIndex < filteredItems.count {
                        run(filteredItems[selectedIndex])
                    } else if let first = filteredItems.first {
                        run(first)
                    }
                }
                .onKeyPress(.upArrow) {
                    selectedIndex = max(0, selectedIndex - 1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    selectedIndex = min(filteredItems.count - 1, selectedIndex + 1)
                    return .handled
                }
                .onChange(of: query) {
                    selectedIndex = 0
                }

            Divider()

            if filteredItems.isEmpty {
                ContentUnavailableView(
                    "No Matches",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            Button {
                                run(item)
                            } label: {
                                row(for: item, isSelected: index == selectedIndex)
                            }
                            .buttonStyle(.plain)

                            if index < filteredItems.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 360)
            }

            Divider()

            HStack {
                Label("Return runs the top match", systemImage: "return")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Close") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(
            minWidth: 640,
            idealWidth: 700,
            maxWidth: 760,
            minHeight: 440,
            idealHeight: 520,
            maxHeight: 560
        )
        .onAppear {
            query = ""
            isQueryFocused = true
            selectedIndex = 0
        }
    }

    @ViewBuilder
    private func row(for item: CommandPaletteItem, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(sanitizedSingleLine(item.title))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if isSelected {
                        Text("Top Match")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.tint.opacity(0.12), in: Capsule())
                    }
                }

                Text(sanitizedSubtitle(item.subtitle))
                    .font(.subheadline.weight(.regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 16)

            Text(sanitizedSingleLine(item.category))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.35), in: Capsule())
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 64, maxHeight: 78)
        .background(isSelected ? Color.accentColor.opacity(0.06) : Color.clear)
    }

    private func sanitizedSubtitle(_ raw: String) -> String {
        let collapsed = sanitizedSingleLine(raw)
        guard collapsed.count > maxRowSubtitleCharacters else { return collapsed }
        return String(collapsed.prefix(maxRowSubtitleCharacters)) + "..."
    }

    private func sanitizedSingleLine(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func run(_ item: CommandPaletteItem) {
        isPresented = false
        item.action()
    }
}
