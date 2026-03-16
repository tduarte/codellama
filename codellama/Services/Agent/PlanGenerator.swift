//
//  PlanGenerator.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation

/// Phase 2 of the agent loop: sends the prompt + context + tools to Ollama
/// and extracts a structured execution plan from the response.
struct PlanGenerator {

    let ollamaClient: OllamaClient
    let mcpHost: MCPHost

    // MARK: - Plan Generation

    /// Generate an `ExecutionPlan` from a user prompt and gathered context.
    ///
    /// Sends a non-streaming request to Ollama with all MCP tool definitions
    /// attached. Extracts `tool_calls` from the final message and maps each
    /// one to an `AgentStep`.
    func generatePlan(
        prompt: String,
        context: ContextBuilder.ContextMap,
        invokedSkill: InstalledSkill?,
        model: String
    ) async throws -> ExecutionPlan {
        let skillSection: String
        if let invokedSkill {
            var lines = [
                "Installed skill context:",
                "- Name: \(invokedSkill.name)",
                invokedSkill.descriptionText.isEmpty ? nil : "- Description: \(invokedSkill.descriptionText)",
                "- Source: \(invokedSkill.sourceLabel)",
                "",
                "Instructions:",
                invokedSkill.body
            ]
                .compactMap { $0 }

            if !invokedSkill.relatedContextFiles.isEmpty {
                lines.append("")
                lines.append("Referenced files:")
                lines.append(contentsOf: invokedSkill.relatedContextFiles.map { file in
                    """
                    [\(file.relativePath)]
                    \(file.content)
                    """
                })
            }

            skillSection = lines.joined(separator: "\n")
        } else {
            skillSection = "Installed skill context:\nNone"
        }

        let systemMessage = OllamaChatMessage(
            role: .system,
            content: """
            You are a planning agent. Your job is to analyze the user's request and create \
            a step-by-step plan using the available tools.

            For each step, call the appropriate tool with the correct arguments. \
            Do not execute the tools — only describe the plan as a sequence of tool calls.

            Context:
            \(context.summary)

            \(skillSection)
            """
        )

        let userMessage = OllamaChatMessage(
            role: .user,
            content: prompt
        )

        let tools = await mcpHost.ollamaTools()

        let request = OllamaChatRequest(
            model: model,
            messages: [systemMessage, userMessage],
            stream: false,
            tools: tools.isEmpty ? nil : tools
        )

        let chunk = try await ollamaClient.chat(request: request)

        guard let message = chunk.message else {
            return ExecutionPlan(
                intent: prompt,
                contextSummary: context.summary,
                steps: [],
                status: .draft
            )
        }

        // Map each Ollama tool call to an AgentStep
        let toolCalls = message.toolCalls ?? []
        let steps: [AgentStep] = toolCalls.enumerated().map { index, ollamaToolCall in
            let functionName = ollamaToolCall.function.name
            let arguments = ollamaToolCall.function.arguments

            // Tool names are encoded as "serverName__toolName"
            let parts = functionName.split(separator: "__", maxSplits: 1).map(String.init)
            let serverName = parts.count == 2 ? parts[0] : ""
            let toolName = parts.count == 2 ? parts[1] : functionName

            let toolCall = ToolCall(
                id: UUID().uuidString,
                serverName: serverName,
                toolName: toolName,
                arguments: arguments
            )

            return AgentStep(
                index: index,
                description: "Call \(toolName) on \(serverName)",
                toolCall: toolCall,
                status: .pending
            )
        }

        return ExecutionPlan(
            intent: prompt,
            contextSummary: context.summary,
            steps: steps,
            status: .awaitingApproval
        )
    }
}
