//
//  ConversationListItem.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI
import SwiftData

struct ConversationListItem: View {
    let conversation: Conversation
    var isSearchResult: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(conversation.title)
                .font(.body)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(conversation.model)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("·")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Text(conversation.modifiedAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if isSearchResult, let preview = latestPreview {
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private var latestPreview: String? {
        conversation.messages
            .sorted { $0.createdAt > $1.createdAt }
            .first(where: { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?
            .content
    }
}
