//
//  AgentLoop.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation
import SwiftUI
import SwiftData
import Defaults

/// Orchestrates the full agentic loop: context gathering → plan generation
/// → user approval → plan execution.
///
/// The loop pauses after Phase 2 (planning) to let the user review and
/// approve the generated plan before any tools are actually called.
@MainActor
@Observable
final class AgentLoop {

    // MARK: - Dependencies

    let ollamaClient: OllamaClient
    let mcpHost: MCPHost
    let modelContext: ModelContext
    let contextIndexManager: ContextIndexManager
    let skillLoader: InstalledSkillLoader

    // MARK: - State

    private(set) var currentTask: AgentTask?
    private(set) var isRunning: Bool = false
    private var executionTask: Task<Void, Never>?
    private var activeConversation: Conversation?

    // MARK: - Init

    init(
        ollamaClient: OllamaClient,
        mcpHost: MCPHost,
        modelContext: ModelContext,
        contextIndexManager: ContextIndexManager,
        skillLoader: InstalledSkillLoader = InstalledSkillLoader()
    ) {
        self.ollamaClient = ollamaClient
        self.mcpHost = mcpHost
        self.modelContext = modelContext
        self.contextIndexManager = contextIndexManager
        self.skillLoader = skillLoader
    }

    // MARK: - Run

    /// Begin the agentic loop for a user prompt.
    ///
    /// - Completes Phase 1 (context gathering) and Phase 2 (plan generation).
    /// - Sets `currentTask.phase` to `.awaitingApproval` so the UI can show
    ///   the plan for review.
    /// - Does NOT execute the plan — call `approvePlan()` for that.
    func run(prompt: String, model: String, conversation: Conversation) async throws {
        isRunning = true

        var task = AgentTask(prompt: prompt, model: model, phase: .architecting)
        currentTask = task
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        activeConversation = conversation

        persistMessage(
            ChatMessage(role: "user", content: prompt),
            in: conversation
        )

        do {
            let invokedSkill = try resolveInvokedSkill(from: trimmedPrompt)
            if let invokedSkill {
                task.timeline.append(TimelineEvent(
                    type: .contextGathered,
                    summary: "Loaded installed skill '\(invokedSkill.name)'",
                    detail: invokedSkill.descriptionText.isEmpty ? invokedSkill.sourceLabel : invokedSkill.descriptionText
                ))
            }

            let contextBuilder = ContextBuilder(
                mcpHost: mcpHost,
                embeddingService: EmbeddingService(ollamaClient: ollamaClient),
                vectorStore: contextIndexManager.vectorStore
            )
            let planPrompt = normalizedPrompt(prompt, using: invokedSkill)
            let contextMap = await contextBuilder.buildContextMap(
                for: planPrompt,
                embeddingModel: Defaults[.embeddingModel]
            )

            task.phase = .planning
            task.timeline.append(TimelineEvent(
                type: .contextGathered,
                summary: "Context gathered",
                detail: contextMap.summary
            ))
            currentTask = task

            let generator = PlanGenerator(ollamaClient: ollamaClient, mcpHost: mcpHost)
            let plan = try await generator.generatePlan(
                prompt: planPrompt,
                context: contextMap,
                invokedSkill: invokedSkill,
                model: model
            )

            task.plan = plan
            task.timeline.append(TimelineEvent(
                type: .planGenerated,
                summary: "Plan generated with \(plan.steps.count) step(s)"
            ))
            persistPlanningMessage(for: plan, invokedSkill: invokedSkill, in: conversation)

            task.phase = .awaitingApproval
            currentTask = task
            isRunning = false
        } catch {
            task.phase = .failed
            task.completedAt = .now
            task.timeline.append(TimelineEvent(type: .error, summary: "Planning failed", detail: error.localizedDescription))
            currentTask = task
            persistMessage(ChatMessage(role: "assistant", content: "Agent planning failed: \(error.localizedDescription)"), in: conversation)
            isRunning = false
            throw error
        }
    }

    // MARK: - Approval

    /// Execute the current plan after user approval.
    func approvePlan() async {
        guard var task = currentTask,
              let plan = task.plan,
              task.phase == .awaitingApproval else { return }

        isRunning = true
        task.phase = .executing
        currentTask = task

        executionTask?.cancel()
        executionTask = Task { [weak self] in
            await self?.executeApprovedPlan(task: task, plan: plan)
        }
    }

    // MARK: - Cancellation

    /// Discard the current plan without executing it.
    func cancelPlan() {
        executionTask?.cancel()
        executionTask = nil

        currentTask?.plan?.status = .cancelled
        currentTask?.phase = .cancelled
        currentTask?.completedAt = .now
        currentTask?.timeline.append(TimelineEvent(
            type: .cancelled,
            summary: "Task cancelled"
        ))
        if let conversation = activeConversation {
            persistMessage(
                ChatMessage(role: "assistant", content: "Agent task cancelled."),
                in: conversation
            )
        }
        isRunning = false
    }

    func dismissTask() {
        guard !isRunning else { return }
        currentTask = nil
        activeConversation = nil
    }

    private func resolveInvokedSkill(from prompt: String) throws -> InstalledSkill? {
        guard prompt.lowercased().hasPrefix("/skill ") else { return nil }

        let requestedName = prompt
            .dropFirst("/skill ".count)
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !requestedName.isEmpty else { return nil }

        return try skillLoader.resolveSkill(named: requestedName)
    }

    private func executeApprovedPlan(task: AgentTask, plan: ExecutionPlan) async {
        var task = task
        var plan = plan

        let executor = PlanExecutor(mcpHost: mcpHost)
        await executor.execute(plan: &plan) { [weak self] updatedPlan in
            guard let self else { return }
            self.currentTask?.plan = updatedPlan
        }

        for step in plan.steps where step.status != .pending {
            let eventType: TimelineEvent.EventType
            switch step.status {
            case .failed:
                eventType = .error
            case .skipped:
                eventType = .cancelled
            case .pending, .running, .succeeded:
                eventType = .toolResult
            }

            let detail = step.result?.content ?? (step.status == .skipped ? "Skipped after cancellation." : nil)
            task.timeline.append(TimelineEvent(
                type: eventType,
                summary: "\(step.toolCall.toolName): \(step.status.rawValue)",
                detail: detail
            ))

            if let conversation = activeConversation,
               let result = step.result {
                persistMessage(
                    ChatMessage(
                        role: "tool",
                        content: result.content,
                        toolCallId: step.toolCall.id
                    ),
                    in: conversation
                )
            }
        }

        task.plan = plan
        task.completedAt = .now

        switch plan.status {
        case .completed:
            task.phase = .completed
            task.timeline.append(TimelineEvent(
                type: .completed,
                summary: "Plan completed successfully"
            ))
        case .cancelled:
            task.phase = .cancelled
            task.timeline.append(TimelineEvent(
                type: .cancelled,
                summary: "Plan cancelled"
            ))
        case .failed:
            task.phase = .failed
            task.timeline.append(TimelineEvent(
                type: .completed,
                summary: "Plan completed with errors"
            ))
        case .draft, .awaitingApproval, .executing:
            task.phase = .failed
        }

        if let conversation = activeConversation {
            let summary = await makeExecutionSummary(for: task, plan: plan)
            persistMessage(ChatMessage(role: "assistant", content: summary), in: conversation)
        }

        currentTask = task
        isRunning = false
        executionTask = nil
        activeConversation = nil
    }

    private func normalizedPrompt(_ prompt: String, using invokedSkill: InstalledSkill?) -> String {
        guard invokedSkill != nil else { return prompt }

        let body = prompt
            .dropFirst("/skill ".count)
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard body.count > 1 else {
            return "Follow the installed skill instructions."
        }

        let residual = String(body[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        return residual.isEmpty ? "Follow the installed skill instructions." : residual
    }

    private func persistPlanningMessage(for plan: ExecutionPlan, invokedSkill: InstalledSkill?, in conversation: Conversation) {
        let headline = invokedSkill.map { "Installed skill: \($0.name)\n\n" } ?? ""
        let body = plan.steps.isEmpty
            ? "The model did not propose any tool calls for this request."
            : plan.steps.map { step in
                "- \(step.description)"
            }.joined(separator: "\n")

        let message = ChatMessage(role: "assistant", content: headline + body)
        message.toolCalls = plan.steps.map(\.toolCall)
        persistMessage(message, in: conversation)
    }

    private func persistMessage(_ message: ChatMessage, in conversation: Conversation) {
        message.conversation = conversation
        conversation.messages.append(message)
        conversation.modifiedAt = .now
        modelContext.insert(message)
        try? modelContext.save()
    }

    private func makeExecutionSummary(for task: AgentTask, plan: ExecutionPlan) async -> String {
        let resultsSummary = plan.steps.map { step in
            let content = step.result?.content ?? "No output."
            return """
            [\(step.toolCall.serverName)__\(step.toolCall.toolName)] \(step.status.rawValue)
            \(content)
            """
        }.joined(separator: "\n\n")

        let request = OllamaChatRequest(
            model: task.model,
            messages: [
                OllamaChatMessage(
                    role: .system,
                    content: "Summarize executed tool results for the user. Mention failures plainly and avoid inventing details."
                ),
                OllamaChatMessage(role: .user, content: task.prompt),
                OllamaChatMessage(role: .user, content: resultsSummary)
            ],
            stream: false
        )

        do {
            let chunk = try await ollamaClient.chat(request: request)
            let summary = chunk.message?.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !summary.isEmpty {
                return summary
            }
        } catch {
            // Fall back to a local summary below.
        }

        switch plan.status {
        case .completed:
            return "Completed \(plan.steps.count) tool step(s). Review the tool results above for details."
        case .failed:
            return "Finished with errors after \(plan.steps.count) tool step(s). Review the tool results above for details."
        case .cancelled:
            return "Execution was cancelled."
        case .draft, .awaitingApproval, .executing:
            return "Execution stopped before a final summary was available."
        }
    }
}
