//
//  SettingsView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI

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
