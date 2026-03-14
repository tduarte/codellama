//
//  AgentLoop.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation
import SwiftUI

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

    // MARK: - State

    private(set) var currentTask: AgentTask?
    private(set) var isRunning: Bool = false

    // MARK: - Init

    init(ollamaClient: OllamaClient, mcpHost: MCPHost) {
        self.ollamaClient = ollamaClient
        self.mcpHost = mcpHost
    }

    // MARK: - Run

    /// Begin the agentic loop for a user prompt.
    ///
    /// - Completes Phase 1 (context gathering) and Phase 2 (plan generation).
    /// - Sets `currentTask.phase` to `.awaitingApproval` so the UI can show
    ///   the plan for review.
    /// - Does NOT execute the plan — call `approvePlan()` for that.
    func run(prompt: String, model: String) async throws {
        isRunning = true

        var task = AgentTask(prompt: prompt, phase: .architecting)
        currentTask = task

        // Phase 1: Gather context from MCP resources
        let contextBuilder = ContextBuilder(mcpHost: mcpHost)
        let contextMap = await contextBuilder.buildContextMap(for: prompt)

        task.phase = .planning
        task.timeline.append(TimelineEvent(
            type: .contextGathered,
            summary: "Context gathered",
            detail: contextMap.summary
        ))
        currentTask = task

        // Phase 2: Generate the execution plan
        let generator = PlanGenerator(ollamaClient: ollamaClient, mcpHost: mcpHost)
        let plan = try await generator.generatePlan(
            prompt: prompt,
            context: contextMap,
            model: model
        )

        task.plan = plan
        task.timeline.append(TimelineEvent(
            type: .planGenerated,
            summary: "Plan generated with \(plan.steps.count) step(s)"
        ))

        task.phase = .awaitingApproval
        currentTask = task
        isRunning = false
    }

    // MARK: - Approval

    /// Execute the current plan after user approval.
    func approvePlan() async {
        guard var task = currentTask,
              var plan = task.plan,
              task.phase == .awaitingApproval else { return }

        isRunning = true
        task.phase = .executing
        currentTask = task

        // Phase 3: Execute the plan step by step
        let executor = PlanExecutor(mcpHost: mcpHost)
        await executor.execute(plan: &plan) { [weak self] updatedPlan in
            guard let self else { return }
            self.currentTask?.plan = updatedPlan
        }

        // Record step results in the task timeline
        for step in plan.steps {
            let event = TimelineEvent(
                type: step.status == .failed ? .error : .toolResult,
                summary: "\(step.toolCall.toolName): \(step.status.rawValue)",
                detail: step.result?.content
            )
            task.timeline.append(event)
        }

        task.plan = plan
        task.phase = plan.status == .completed ? .completed : .failed
        task.completedAt = .now

        let completedEvent = TimelineEvent(
            type: .completed,
            summary: plan.status == .completed ? "Plan completed successfully" : "Plan completed with errors"
        )
        task.timeline.append(completedEvent)

        currentTask = task
        isRunning = false
    }

    // MARK: - Cancellation

    /// Discard the current plan without executing it.
    func cancelPlan() {
        currentTask?.phase = .failed
        currentTask?.completedAt = .now
        isRunning = false
    }
}
