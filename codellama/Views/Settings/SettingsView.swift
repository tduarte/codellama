//
//  SettingsView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI

struct SettingsView: View {
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
        }
        .frame(width: 500, height: 420)
    }
}
