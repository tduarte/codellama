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
                    if let first = filteredItems.first {
                        run(first)
                    }
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
                                row(for: item, isSuggested: index == 0)
                            }
                            .buttonStyle(.plain)

                            if index < filteredItems.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
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
        .frame(minWidth: 640, minHeight: 440)
        .onAppear {
            query = ""
            isQueryFocused = true
        }
    }

    @ViewBuilder
    private func row(for item: CommandPaletteItem, isSuggested: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if isSuggested {
                        Text("Top Match")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.tint.opacity(0.12), in: Capsule())
                    }
                }

                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 16)

            Text(item.category)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.quaternary.opacity(0.5), in: Capsule())
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSuggested ? Color.accentColor.opacity(0.06) : Color.clear)
    }

    private func run(_ item: CommandPaletteItem) {
        isPresented = false
        item.action()
    }
}
