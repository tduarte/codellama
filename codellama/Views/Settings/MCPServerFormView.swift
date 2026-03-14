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

    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
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
                    Button("Filesystem Server") {
                        name = "filesystem"
                        command = "npx"
                        arguments = "@modelcontextprotocol/server-filesystem /tmp"
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)

                    Button("GitHub Server") {
                        name = "github"
                        command = "npx"
                        arguments = "@modelcontextprotocol/server-github"
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel", role: .cancel, action: onCancel)

                Spacer()

                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || command.isEmpty)
            }
            .padding()
        }
    }
}
