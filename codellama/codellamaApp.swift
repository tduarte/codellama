//
//  codellamaApp.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI
import SwiftData

@main
struct codellamaApp: App {
    @State private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Conversation.self,
            ChatMessage.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView(chatViewModel: ChatViewModel(modelContext: sharedModelContainer.mainContext))
                .environment(appState)
                .task { await appState.startup() }
                .frame(minWidth: 700, minHeight: 500)
        }
        .modelContainer(sharedModelContainer)

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
