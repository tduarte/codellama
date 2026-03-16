//
//  ConversationEmptyStateView.swift
//  codellama
//
//  Created by Codex on 3/15/26.
//

import SwiftUI

struct ConversationEmptyStateView: View {
    let starters: [ConversationStarter]
    let onStarterSelected: (ConversationStarter) -> Void
    let onExploreMore: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer(minLength: max(AppSpacing.xl, geometry.size.height * 0.12))

                hero

                Spacer(minLength: max(AppSpacing.xl, geometry.size.height * 0.14))

                starterSection(width: geometry.size.width)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.lg)
        }
    }

    private var hero: some View {
        VStack(spacing: AppSpacing.md) {
            Text("How can I help?")
                .font(.largeTitle.weight(.semibold))
                .multilineTextAlignment(.center)

            Text("Start with a prompt below, or pick a suggestion to get going.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func starterSection(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Try one of these")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer(minLength: AppSpacing.lg)

                Button("Explore more", action: onExploreMore)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppSpacing.xs)

            if width >= 1100 {
                HStack(alignment: .top, spacing: AppSpacing.lg) {
                    ForEach(starters) { starter in
                        starterCard(starter)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: AppSpacing.lg) {
                        ForEach(starters) { starter in
                            starterCard(starter)
                                .frame(width: min(max(width * 0.42, 240), 340))
                        }
                    }
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.sm)
                }
                .scrollClipDisabled()
            }
        }
        .frame(maxWidth: 1100)
    }

    private func starterCard(_ starter: ConversationStarter) -> some View {
        Button {
            onStarterSelected(starter)
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
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
                    .lineLimit(2)
                    .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(AppSpacing.xl - 2)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .glassEffect(.regular, in: .rect(cornerRadius: AppRadius.card))
        }
        .buttonStyle(.plain)
    }
}
