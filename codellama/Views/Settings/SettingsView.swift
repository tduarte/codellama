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
            OllamaSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            MCPServerSettingsView()
                .tabItem {
                    Label("MCP Servers", systemImage: "server.rack")
                }

            SkillListView(skillViewModel: skillViewModel)
                .tabItem {
                    Label("Skills", systemImage: "wand.and.stars")
                }
        }
        .frame(width: 980, height: 680)
    }
}
