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
    @State private var formArgumentsText = ""
    @State private var formEnvironmentEntries: [MCPEnvironmentEntry] = [MCPEnvironmentEntry()]
    @State private var formEnabled = true

    var body: some View {
        VStack(spacing: 0) {
            if servers.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    ContentUnavailableView {
                        Label("No MCP Servers", systemImage: "server.rack")
                            .labelStyle(.titleAndIcon)
                    } description: {
                        Text("Connect your first MCP server to give the agent safe, tool-based access to local and remote capabilities.")
                    } actions: {
                        HStack(spacing: 10) {
                            Button("Add Server") {
                                prepareForAdd()
                                showingAddSheet = true
                            }
                            .buttonStyle(.borderedProminent)

                            Link("MCP Quickstart", destination: URL(string: "https://modelcontextprotocol.io/quickstart")!)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Getting started")
                            .font(.subheadline.weight(.semibold))

                        Label("Choose a server package (filesystem, GitHub, database, etc.).", systemImage: "1.circle")
                            .foregroundStyle(.secondary)
                        Label("Set the launch command and arguments.", systemImage: "2.circle")
                            .foregroundStyle(.secondary)
                        Label("Enable the server and verify it shows as connected.", systemImage: "3.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(24)
                .frame(maxWidth: 520, maxHeight: .infinity)
            } else {
                List {
                    ForEach(servers) { server in
                        serverRow(server)
                    }
                    .onDelete(perform: deleteServers)
                }
                .listStyle(.inset)
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        prepareForAdd()
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .frame(width: 28, height: 28)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                }
            }
        }
        .controlSize(.small)
        .environment(\.defaultMinListRowHeight, 30)
        .onAppear {
            registerServers()
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                MCPServerFormView(
                    name: $formName,
                    command: $formCommand,
                    argumentsText: $formArgumentsText,
                    environmentEntries: $formEnvironmentEntries,
                    isEnabled: $formEnabled,
                    title: "Add MCP Server",
                    onSave: {
                        saveNewServer()
                        showingAddSheet = false
                    },
                    onCancel: {
                        showingAddSheet = false
                    }
                )
                .frame(minWidth: 500, minHeight: 380)
            }
            .frame(width: 520, height: 420)
        }
        .sheet(item: $editingServer) { server in
            NavigationStack {
                MCPServerFormView(
                    name: $formName,
                    command: $formCommand,
                    argumentsText: $formArgumentsText,
                    environmentEntries: $formEnvironmentEntries,
                    isEnabled: $formEnabled,
                    title: "Edit MCP Server",
                    onSave: {
                        applyEdits(to: server)
                        editingServer = nil
                    },
                    onCancel: {
                        editingServer = nil
                    }
                )
                .frame(minWidth: 500, minHeight: 380)
            }
            .frame(width: 520, height: 420)
        }
    }

    private func registerServers() {
        appState.mcpHost.register(configs: servers)
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
            connectionIndicator(for: server)

            Toggle("", isOn: Binding(
                get: { server.isEnabled },
                set: { newValue in
                    server.isEnabled = newValue
                    try? modelContext.save()
                    registerServers()
                    Task { await appState.mcpHost.setEnabled(newValue, for: server) }
                }
            ))
            .labelsHidden()

            Button {
                Task { await appState.mcpHost.restart(serverName: server.name) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(!server.isEnabled)

            Button {
                prepareForEdit(server)
                editingServer = server
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 1)
    }

    @ViewBuilder
    private func connectionIndicator(for server: MCPServerConfig) -> some View {
        let state = appState.mcpHost.serverStates[server.name]

        HStack(spacing: 6) {
            Circle()
                .fill(connectionColor(for: state?.lifecycle ?? .disconnected))
                .frame(width: 8, height: 8)

            Text(state?.statusSummary ?? "Disconnected")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 120, alignment: .leading)
        }
    }

    // MARK: - Actions

    private func prepareForAdd() {
        formName = ""
        formCommand = ""
        formArgumentsText = ""
        formEnvironmentEntries = [MCPEnvironmentEntry()]
        formEnabled = true
    }

    private func prepareForEdit(_ server: MCPServerConfig) {
        formName = server.name
        formCommand = server.command
        formArgumentsText = server.arguments.joined(separator: "\n")
        formEnvironmentEntries = (server.environment ?? [:])
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { MCPEnvironmentEntry(key: $0.key, value: $0.value) }
        if formEnvironmentEntries.isEmpty {
            formEnvironmentEntries = [MCPEnvironmentEntry()]
        }
        formEnabled = server.isEnabled
    }

    private func saveNewServer() {
        let config = MCPServerConfig(
            name: formName,
            command: formCommand,
            arguments: parsedArguments(),
            environment: parsedEnvironment()
        )
        config.isEnabled = formEnabled
        modelContext.insert(config)
        try? modelContext.save()
        registerServers()

        if config.isEnabled {
            Task { try? await appState.mcpHost.connect(config: config) }
        }
    }

    private func applyEdits(to server: MCPServerConfig) {
        let previousName = server.name

        server.name = formName
        server.command = formCommand
        server.arguments = parsedArguments()
        server.environment = parsedEnvironment()
        server.isEnabled = formEnabled
        try? modelContext.save()

        Task {
            if previousName != server.name {
                await appState.mcpHost.removeServer(named: previousName)
            } else if !server.isEnabled {
                await appState.mcpHost.disconnect(serverName: server.name)
            }

            registerServers()

            if server.isEnabled {
                await appState.mcpHost.restart(serverName: server.name)
            }
        }
    }

    private func deleteServers(at offsets: IndexSet) {
        for index in offsets {
            let server = servers[index]
            Task { await appState.mcpHost.removeServer(named: server.name) }
            modelContext.delete(server)
        }
        try? modelContext.save()
        registerServers()
    }

    private func parsedArguments() -> [String] {
        formArgumentsText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func parsedEnvironment() -> [String: String]? {
        let pairs = formEnvironmentEntries.reduce(into: [String: String]()) { partialResult, entry in
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return }
            partialResult[key] = entry.value
        }
        return pairs.isEmpty ? nil : pairs
    }

    private func connectionColor(for lifecycle: MCPServerRuntimeState.Lifecycle) -> Color {
        switch lifecycle {
        case .connected:
            return .green
        case .connecting, .restarting:
            return .orange
        case .failed:
            return .red
        case .disabled, .disconnected:
            return Color.secondary.opacity(0.4)
        }
    }
}
