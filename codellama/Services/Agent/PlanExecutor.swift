//
//  PlanExecutor.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation

/// Phase 3 of the agent loop: executes `AgentStep`s sequentially,
/// reporting progress via a callback after each step completes.
struct PlanExecutor {

    let mcpHost: MCPHost

    // MARK: - Execution

    /// Execute all pending steps in a plan, calling `onStepUpdate` after each.
    ///
    /// Steps are executed in index order. If a step fails, it is marked
    /// `.failed` and subsequent steps are still attempted.
    func execute(
        plan: inout ExecutionPlan,
        onStepUpdate: @MainActor (ExecutionPlan) -> Void
    ) async {
        plan.status = .executing

        for index in plan.steps.indices {
            // Mark step as running
            plan.steps[index].status = .running
            plan.steps[index].startedAt = .now
            let runningPlan = plan
            await onStepUpdate(runningPlan)

            let step = plan.steps[index]

            do {
                let result = try await mcpHost.callTool(step.toolCall)
                plan.steps[index].result = result
                plan.steps[index].status = result.isError ? .failed : .succeeded
                plan.steps[index].completedAt = .now

            } catch {
                plan.steps[index].status = .failed
                plan.steps[index].completedAt = .now
                plan.steps[index].result = ToolResult(
                    id: UUID().uuidString,
                    toolCallId: step.toolCall.id,
                    content: error.localizedDescription,
                    isError: true
                )
            }

            let updatedPlan = plan
            await onStepUpdate(updatedPlan)
        }

        // Determine final plan status
        let hasFailures = plan.steps.contains { $0.status == .failed }
        plan.status = hasFailures ? .failed : .completed

        let finalPlan = plan
        await onStepUpdate(finalPlan)
    }
}
