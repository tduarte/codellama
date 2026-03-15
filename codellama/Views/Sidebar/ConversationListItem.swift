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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Conversation.self, ChatMessage.self, configurations: config)

    let conv1 = Conversation(title: "Build a REST API in Swift", model: "llama3.1:8b")
    let conv2 = Conversation(title: "Explain async/await patterns", model: "codellama:7b")
    let msg = ChatMessage(role: "assistant", content: "Here is how you can use async/await in Swift with structured concurrency…")

    container.mainContext.insert(conv1)
    container.mainContext.insert(conv2)
    container.mainContext.insert(msg)
    msg.conversation = conv2

    return List {
        ConversationListItem(conversation: conv1)
        ConversationListItem(conversation: conv2, isSearchResult: true)
    }
    .frame(width: 280, height: 160)
    .modelContainer(container)
}
