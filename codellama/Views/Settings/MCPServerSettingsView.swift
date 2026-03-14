//
//  MCPServerSettingsView.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI
import SwiftData

/// Settings view for managing MCP server configurations.
///
/// Lists all configured servers with their connection status,
/// and allows adding, editing, toggling, and deleting them.
struct MCPServerSettingsView: View {

    @Query(sort: \MCPServerConfig.createdAt) var servers: [MCPServerConfig]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var showingAddSheet = false
    @State private var editingServer: MCPServerConfig?

    // Form state for add/edit
    @State private var formName = ""
    @State private var formCommand = ""
    @State private var formArguments = ""
    @State private var formEnabled = true

    var body: some View {
        VStack(spacing: 0) {
            if servers.isEmpty {
                ContentUnavailableView {
                    Label("No MCP Servers", systemImage: "server.rack")
                } description: {
                    Text("Add an MCP server to give the agent access to tools.")
                } actions: {
                    Button("Add Server") {
                        prepareForAdd()
                        showingAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(servers) { server in
                        serverRow(server)
                    }
                    .onDelete(perform: deleteServers)
                }
                .listStyle(.inset)
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    prepareForAdd()
                    showingAddSheet = true
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            MCPServerFormView(
                name: $formName,
                command: $formCommand,
                arguments: $formArguments,
                isEnabled: $formEnabled,
                onSave: {
                    saveNewServer()
                    showingAddSheet = false
                },
                onCancel: {
                    showingAddSheet = false
                }
            )
            .frame(width: 480, height: 400)
        }
        .sheet(item: $editingServer) { server in
            MCPServerFormView(
                name: $formName,
                command: $formCommand,
                arguments: $formArguments,
                isEnabled: $formEnabled,
                onSave: {
                    applyEdits(to: server)
                    editingServer = nil
                },
                onCancel: {
                    editingServer = nil
                }
            )
            .frame(width: 480, height: 400)
        }
    }

    // MARK: - Server Row

    @ViewBuilder
    private func serverRow(_ server: MCPServerConfig) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.body)
                    .bold()

                Text("\(server.command) \(server.arguments.joined(separator: " "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Connection status indicator
            connectionIndicator(serverName: server.name)

            Toggle("", isOn: Binding(
                get: { server.isEnabled },
                set: { server.isEnabled = $0 }
            ))
            .labelsHidden()

            Button {
                prepareForEdit(server)
                editingServer = server
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func connectionIndicator(serverName: String) -> some View {
        let isConnected = appState.mcpHost.connections[serverName]?.isConnected ?? false
        Circle()
            .fill(isConnected ? Color.green : Color.secondary.opacity(0.4))
            .frame(width: 8, height: 8)
    }

    // MARK: - Actions

    private func prepareForAdd() {
        formName = ""
        formCommand = ""
        formArguments = ""
        formEnabled = true
    }

    private func prepareForEdit(_ server: MCPServerConfig) {
        formName = server.name
        formCommand = server.command
        formArguments = server.arguments.joined(separator: " ")
        formEnabled = server.isEnabled
    }

    private func saveNewServer() {
        let args = formArguments
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)

        let config = MCPServerConfig(
            name: formName,
            command: formCommand,
            arguments: args
        )
        config.isEnabled = formEnabled
        modelContext.insert(config)
        try? modelContext.save()
    }

    private func applyEdits(to server: MCPServerConfig) {
        let args = formArguments
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)

        server.name = formName
        server.command = formCommand
        server.arguments = args
        server.isEnabled = formEnabled
        try? modelContext.save()
    }

    private func deleteServers(at offsets: IndexSet) {
        for index in offsets {
            let server = servers[index]
            // Disconnect if currently connected
            if appState.mcpHost.connections[server.name] != nil {
                Task { await appState.mcpHost.disconnect(serverName: server.name) }
            }
            modelContext.delete(server)
        }
        try? modelContext.save()
    }
}
