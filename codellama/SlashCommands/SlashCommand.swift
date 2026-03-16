//
//  SlashCommand.swift
//  codellama
//

import Foundation

struct SlashCommand: Identifiable {
    enum Action {
        case setSystemPrompt(text: String?)
        case listTools
        case listMCPServers
        case showHelp
        case stopGeneration
    }

    let id: String           // keyword without "/", e.g. "system"
    let argumentHint: String // e.g. "[prompt]" or "—"
    let description: String
    let systemImage: String
    let action: Action
}

enum SlashCommandRegistry {

    static let all: [SlashCommand] = [
        SlashCommand(
            id: "skill",
            argumentHint: "<name>",
            description: "Invoke an installed skill",
            systemImage: "sparkles",
            action: .showHelp  // placeholder; /skill execution is not intercepted
        ),
        SlashCommand(
            id: "system",
            argumentHint: "[prompt]",
            description: "Set system prompt; shows current if no argument",
            systemImage: "person.text.rectangle",
            action: .setSystemPrompt(text: nil)
        ),
        SlashCommand(
            id: "tools",
            argumentHint: "—",
            description: "List available MCP tools",
            systemImage: "wrench.and.screwdriver",
            action: .listTools
        ),
        SlashCommand(
            id: "mcp",
            argumentHint: "—",
            description: "List connected MCP servers",
            systemImage: "network",
            action: .listMCPServers
        ),
        SlashCommand(
            id: "stop",
            argumentHint: "—",
            description: "Stop current generation",
            systemImage: "stop.circle",
            action: .stopGeneration
        ),
        SlashCommand(
            id: "help",
            argumentHint: "—",
            description: "Show all available commands",
            systemImage: "questionmark.circle",
            action: .showHelp
        ),
    ]

    /// Returns commands whose id starts with `prefix` (case-insensitive).
    static func matching(prefix: String) -> [SlashCommand] {
        let lower = prefix.lowercased()
        if lower.isEmpty { return all }
        return all.filter { $0.id.hasPrefix(lower) }
    }

    /// Parses a raw input string (e.g. "/system hello") into a command + optional argument.
    ///
    /// Returns `nil` when:
    /// - The input doesn't start with "/"
    /// - The command keyword is not in the registry
    /// - The command is `/skill` (handled by AgentLoop, not intercepted here)
    static func parse(input: String) -> (SlashCommand, String?)? {
        guard input.hasPrefix("/") else { return nil }
        let withoutSlash = String(input.dropFirst())
        let components = withoutSlash.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        let commandName = components.first.map(String.init)?.lowercased() ?? ""
        let rawArg = components.count > 1 ? String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines) : nil
        let arg = rawArg?.isEmpty == false ? rawArg : nil

        guard let command = all.first(where: { $0.id == commandName }),
              command.id != "skill" else {
            return nil
        }

        // Bake the parsed argument into the action for relevant commands
        let resolvedAction: SlashCommand.Action
        switch command.action {
        case .setSystemPrompt:
            resolvedAction = .setSystemPrompt(text: arg)
        default:
            resolvedAction = command.action
        }

        let resolved = SlashCommand(
            id: command.id,
            argumentHint: command.argumentHint,
            description: command.description,
            systemImage: command.systemImage,
            action: resolvedAction
        )
        return (resolved, arg)
    }

    static func helpMarkdown() -> String {
        var lines = [
            "## Available Slash Commands",
            "",
            "| Command | Arguments | Description |",
            "| --- | --- | --- |",
        ]
        for cmd in all {
            lines.append("| `/\(cmd.id)` | \(cmd.argumentHint) | \(cmd.description) |")
        }
        lines.append("")
        lines.append("> **Tip:** In agent mode, type `/skill <name>` to invoke an installed skill.")
        return lines.joined(separator: "\n")
    }
}
