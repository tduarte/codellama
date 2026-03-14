//
//  AgentViewModel.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import SwiftUI

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

    /// `true` when the plan has been generated and is awaiting user approval.
    var showPlanTimeline: Bool { currentTask?.phase == .awaitingApproval }

    // MARK: - Init

    init(ollamaClient: OllamaClient, mcpHost: MCPHost) {
        self.agentLoop = AgentLoop(ollamaClient: ollamaClient, mcpHost: mcpHost)
    }

    // MARK: - Actions

    /// Start the agentic loop for the given prompt.
    func runAgent(prompt: String, model: String) async throws {
        try await agentLoop.run(prompt: prompt, model: model)
    }

    /// Approve the current plan and begin execution.
    func approve() async {
        await agentLoop.approvePlan()
    }

    /// Cancel and discard the current plan.
    func cancel() {
        agentLoop.cancelPlan()
    }
}
