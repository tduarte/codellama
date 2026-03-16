//
//  MCPServerFormView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI

struct MCPEnvironmentEntry: Identifiable, Hashable {
    let id: UUID
    var key: String
    var value: String

    init(id: UUID = UUID(), key: String = "", value: String = "") {
        self.id = id
        self.key = key
        self.value = value
    }
}

/// Form for adding or editing a single MCP server configuration.
///
/// Arguments are entered one-per-line and environment variables use explicit key/value rows.
struct MCPServerFormView: View {

    @Binding var name: String
    @Binding var command: String
    @Binding var argumentsText: String
    @Binding var environmentEntries: [MCPEnvironmentEntry]
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Arguments")
                        .font(.subheadline.weight(.semibold))

                    TextEditor(text: $argumentsText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 110)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.background)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.quaternary, lineWidth: 1)
                        )

                    Text("Enter one argument per line to preserve spaces and quoting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Environment") {
                ForEach($environmentEntries) { $entry in
                    HStack {
                        TextField("KEY", text: $entry.key)
                            .textFieldStyle(.roundedBorder)
                        TextField("Value", text: $entry.value)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            removeEnvironmentEntry(entry.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    environmentEntries.append(MCPEnvironmentEntry())
                } label: {
                    Label("Add Variable", systemImage: "plus.circle")
                }

                Text("Environment variables are passed directly to the server process.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Presets") {
                Button("Use Filesystem Preset") {
                    name = "filesystem"
                    command = "npx"
                    argumentsText = "@modelcontextprotocol/server-filesystem\n/tmp"
                }

                Button("Use GitHub Preset") {
                    name = "github"
                    command = "npx"
                    argumentsText = "@modelcontextprotocol/server-github"
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

    private func removeEnvironmentEntry(_ id: UUID) {
        environmentEntries.removeAll { $0.id == id }
        if environmentEntries.isEmpty {
            environmentEntries.append(MCPEnvironmentEntry())
        }
    }
}
