//
//  SettingsView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Bindable var skillViewModel: SkillViewModel

    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                OllamaSettingsView()
            }

            Tab("MCP Servers", systemImage: "server.rack") {
                MCPServerSettingsView()
            }

            Tab("Skills", systemImage: "wand.and.stars") {
                SkillListView(skillViewModel: skillViewModel, isSettingsContext: true)
            }
        }
        .scenePadding()
        .frame(minWidth: 700, idealWidth: 780, minHeight: 480, idealHeight: 560)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Skill.self, MCPServerConfig.self, configurations: config)
    let skillViewModel = SkillViewModel(modelContext: container.mainContext)
    SettingsView(skillViewModel: skillViewModel)
        .environment(AppState.preview)
        .modelContainer(container)
}
