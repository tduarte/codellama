//
//  MCPServerFormView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI

/// Form for adding or editing a single MCP server configuration.
///
/// Arguments are entered as a space-separated string and split on save.
struct MCPServerFormView: View {

    @Binding var name: String
    @Binding var command: String
    @Binding var arguments: String  // Space-separated; split on save
    @Binding var isEnabled: Bool

    var title: String = "MCP Server"
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        Form {
            Section("Server Identity") {
                TextField("Name", text: $name, prompt: Text("e.g. filesystem"))
                Toggle("Enabled", isOn: $isEnabled)
            }

            Section("Process") {
                TextField("Command", text: $command, prompt: Text("e.g. npx"))
                TextField(
                    "Arguments",
                    text: $arguments,
                    prompt: Text("e.g. @modelcontextprotocol/server-filesystem /tmp")
                )
                Text("Space-separated arguments passed to the command.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Presets") {
                Button("Use Filesystem Preset") {
                    name = "filesystem"
                    command = "npx"
                    arguments = "@modelcontextprotocol/server-filesystem /tmp"
                }

                Button("Use GitHub Preset") {
                    name = "github"
                    command = "npx"
                    arguments = "@modelcontextprotocol/server-github"
                }
            }
        }
        .formStyle(.grouped)
        .controlSize(.small)
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel, action: onCancel)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || command.isEmpty)
            }
        }
    }
}

#Preview("Empty Form") {
    @Previewable @State var name = ""
    @Previewable @State var command = ""
    @Previewable @State var arguments = ""
    @Previewable @State var isEnabled = true
    NavigationStack {
        MCPServerFormView(
            name: $name,
            command: $command,
            arguments: $arguments,
            isEnabled: $isEnabled,
            title: "Add MCP Server",
            onSave: {},
            onCancel: {}
        )
    }
    .frame(width: 520, height: 420)
}

#Preview("Prefilled") {
    @Previewable @State var name = "filesystem"
    @Previewable @State var command = "npx"
    @Previewable @State var arguments = "@modelcontextprotocol/server-filesystem /tmp"
    @Previewable @State var isEnabled = true
    NavigationStack {
        MCPServerFormView(
            name: $name,
            command: $command,
            arguments: $arguments,
            isEnabled: $isEnabled,
            title: "Edit MCP Server",
            onSave: {},
            onCancel: {}
        )
    }
    .frame(width: 520, height: 420)
}
