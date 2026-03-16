//
//  ConversationEmptyStateView.swift
//  codellama
//
//  Created by Codex on 3/15/26.
//

import SwiftUI

struct ConversationEmptyStateView: View {
    let selectedModel: String
    let availableModels: [OllamaModel]
    let isCurrentModelAvailable: Bool
    let modelSelection: Binding<String>
    let starters: [ConversationStarter]
    let onStarterSelected: (ConversationStarter) -> Void
    let onExploreMore: () -> Void

    @State private var starterCardHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer(minLength: max(48, geometry.size.height * 0.12))

                hero

                Spacer(minLength: max(48, geometry.size.height * 0.14))

                starterSection(width: geometry.size.width)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 20)
            .background(alignment: .top) {
                backgroundGlow
            }
        }
    }

    private var backgroundGlow: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.08))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: -160, y: -100)

            Circle()
                .fill(Color.primary.opacity(0.04))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: 180, y: 20)
        }
        .allowsHitTesting(false)
    }

    private var hero: some View {
        VStack(spacing: 18) {
            Text("How can I help?")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)

            modelMenu

            Text("Choose a model, start with a prompt, or pick a suggestion to get moving.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 540)
        }
        .frame(maxWidth: .infinity)
    }

    private var modelMenu: some View {
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
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .capsule)
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private func starterSection(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Try one of these")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 16)

                Button("Explore more", action: onExploreMore)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            if width >= 1100 {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(starters) { starter in
                        starterCard(starter)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(starters) { starter in
                            starterCard(starter)
                                .frame(width: min(max(width * 0.42, 240), 340))
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 10)
                }
                .scrollClipDisabled()
            }
        }
        .frame(maxWidth: 1100)
        .onPreferenceChange(StarterCardHeightPreferenceKey.self) { height in
            guard height > 0 else { return }
            starterCardHeight = height
        }
    }

    private func starterCard(_ starter: ConversationStarter) -> some View {
        Button {
            onStarterSelected(starter)
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: starter.systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 28, height: 28, alignment: .topLeading)

                Text(starter.category)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                Text(starter.title)
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(22)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: StarterCardHeightPreferenceKey.self, value: proxy.size.height)
                }
            )
            .frame(height: starterCardHeight == 0 ? nil : starterCardHeight, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
        }
        .buttonStyle(.plain)
    }

    private var selectedModelDisplayName: String {
        availableModels.first(where: { $0.name == selectedModel })?.displayName ?? selectedModel
    }
}

private struct StarterCardHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
