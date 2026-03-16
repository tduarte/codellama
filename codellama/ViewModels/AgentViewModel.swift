//
//  AgentViewModel.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI
import SwiftData

/// View model that bridges the `AgentLoop` to SwiftUI views.
///
/// Exposes reactive state for the current task and provides simple
/// action methods for the approve/cancel flow.
@MainActor
@Observable
final class AgentViewModel {

    // MARK: - Private

    let agentLoop: AgentLoop

    // MARK: - Computed State

    var currentTask: AgentTask? { agentLoop.currentTask }
    var isRunning: Bool { agentLoop.isRunning }

    /// `true` while there is an active task to review, execute, or dismiss.
    var showPlanTimeline: Bool { currentTask != nil }

    // MARK: - Init

    init(
        ollamaClient: OllamaClient,
        mcpHost: MCPHost,
        modelContext: ModelContext,
        contextIndexManager: ContextIndexManager
    ) {
        self.agentLoop = AgentLoop(
            ollamaClient: ollamaClient,
            mcpHost: mcpHost,
            modelContext: modelContext,
            contextIndexManager: contextIndexManager
        )
    }

    // MARK: - Actions

    /// Start the agentic loop for the given prompt.
    func runAgent(prompt: String, model: String, conversation: Conversation) async throws {
        try await agentLoop.run(prompt: prompt, model: model, conversation: conversation)
    }

    /// Approve the current plan and begin execution.
    func approve() async {
        await agentLoop.approvePlan()
    }

    /// Cancel and discard the current plan.
    func cancel() {
        agentLoop.cancelPlan()
    }

    func dismissTask() {
        agentLoop.dismissTask()
    }
}
