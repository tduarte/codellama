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
        .frame(minWidth: 760, idealWidth: 860, minHeight: 620, idealHeight: 680)
    }
}
