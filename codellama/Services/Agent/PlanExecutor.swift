//
//  PlanExecutor.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation

/// Phase 3 of the agent loop: executes `AgentStep`s while preserving plan
/// order, batching independent read-only steps across different MCP servers.
struct PlanExecutor {

    let mcpHost: MCPHost

    // MARK: - Execution

    /// Execute all pending steps in a plan, calling `onStepUpdate` after each
    /// sequential step or parallel batch completes.
    ///
    /// Steps are executed in index order. If a step fails, it is marked
    /// `.failed` and subsequent steps are still attempted.
    func execute(
        plan: inout ExecutionPlan,
        onStepUpdate: @MainActor (ExecutionPlan) -> Void
    ) async {
        plan.status = .executing

        var index = 0
        while index < plan.steps.count {
            if Task.isCancelled {
                cancelRemainingSteps(in: &plan, from: index)
                let cancelledPlan = plan
                await onStepUpdate(cancelledPlan)
                return
            }

            let batchIndices = parallelBatchIndices(in: plan, startingAt: index)
            markRunning(batchIndices, in: &plan)

            let runningPlan = plan
            await onStepUpdate(runningPlan)

            if batchIndices.count == 1, let stepIndex = batchIndices.first {
                await executeSequentialStep(at: stepIndex, in: &plan)
            } else {
                await executeParallelBatch(at: batchIndices, in: &plan)
            }

            let updatedPlan = plan
            await onStepUpdate(updatedPlan)
            index += batchIndices.count
        }

        // Determine final plan status
        let hasFailures = plan.steps.contains { $0.status == .failed }
        plan.status = hasFailures ? .failed : .completed

        let finalPlan = plan
        await onStepUpdate(finalPlan)
    }

    private func cancelRemainingSteps(in plan: inout ExecutionPlan, from index: Int) {
        for remainingIndex in index..<plan.steps.count where plan.steps[remainingIndex].status == .pending {
            plan.steps[remainingIndex].status = .skipped
            plan.steps[remainingIndex].completedAt = .now
        }
        plan.status = .cancelled
    }

    private func parallelBatchIndices(in plan: ExecutionPlan, startingAt startIndex: Int) -> [Int] {
        guard plan.steps.indices.contains(startIndex) else { return [] }

        let startingStep = plan.steps[startIndex]
        guard startingStep.status == .pending else { return [startIndex] }
        guard startingStep.toolCall.isLikelyReadOnly else { return [startIndex] }
        guard !startingStep.toolCall.serverName.isEmpty else { return [startIndex] }

        var seenServerNames: Set<String> = [startingStep.toolCall.serverName]
        var batchIndices = [startIndex]
        var currentIndex = startIndex + 1

        while plan.steps.indices.contains(currentIndex) {
            let step = plan.steps[currentIndex]
            guard step.status == .pending else { break }
            guard step.toolCall.isLikelyReadOnly else { break }
            guard !step.toolCall.serverName.isEmpty else { break }
            guard seenServerNames.insert(step.toolCall.serverName).inserted else { break }
            batchIndices.append(currentIndex)
            currentIndex += 1
        }

        return batchIndices
    }

    private func markRunning(_ indices: [Int], in plan: inout ExecutionPlan) {
        for index in indices {
            plan.steps[index].status = .running
            plan.steps[index].startedAt = .now
        }
    }

    private func executeSequentialStep(at index: Int, in plan: inout ExecutionPlan) async {
        let step = plan.steps[index]

        do {
            let result = try await mcpHost.callTool(step.toolCall)
            apply(result: result, to: index, in: &plan)
        } catch {
            apply(errorMessage: error.localizedDescription, step: step, to: index, in: &plan)
        }
    }

    private func executeParallelBatch(at indices: [Int], in plan: inout ExecutionPlan) async {
        let toolCalls = indices.map { plan.steps[$0].toolCall }
        let results = await mcpHost.callToolsInParallel(toolCalls)
        let resultsByToolCallID = Dictionary(uniqueKeysWithValues: results.map { ($0.toolCallId, $0) })

        for index in indices {
            let step = plan.steps[index]
            if let result = resultsByToolCallID[step.toolCall.id] {
                apply(result: result, to: index, in: &plan)
            } else {
                apply(
                    errorMessage: "Parallel tool execution did not return a result.",
                    step: step,
                    to: index,
                    in: &plan
                )
            }
        }
    }

    private func apply(result: ToolResult, to index: Int, in plan: inout ExecutionPlan) {
        plan.steps[index].result = result
        plan.steps[index].status = result.isError ? .failed : .succeeded
        plan.steps[index].completedAt = .now
    }

    private func apply(errorMessage: String, step: AgentStep, to index: Int, in plan: inout ExecutionPlan) {
        plan.steps[index].status = .failed
        plan.steps[index].completedAt = .now
        plan.steps[index].result = ToolResult(
            id: UUID().uuidString,
            toolCallId: step.toolCall.id,
            content: errorMessage,
            isError: true
        )
    }
}
