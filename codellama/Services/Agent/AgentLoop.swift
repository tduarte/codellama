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
    let embeddingService: EmbeddingService
    let vectorStore: VectorStore

    // MARK: - State

    private(set) var currentTask: AgentTask?
    private(set) var isRunning: Bool = false

    // MARK: - Init

    init(ollamaClient: OllamaClient, mcpHost: MCPHost, modelContext: ModelContext) {
        self.ollamaClient = ollamaClient
        self.mcpHost = mcpHost
        self.modelContext = modelContext
        self.embeddingService = EmbeddingService(ollamaClient: ollamaClient)
        self.vectorStore = VectorStore()
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

        let skills = fetchSkills()
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        if let invokedSkill = resolveInvokedSkill(from: trimmedPrompt, skills: skills) {
            let plan = makePlan(for: invokedSkill, prompt: prompt)
            task.plan = plan
            task.timeline.append(TimelineEvent(
                type: .planGenerated,
                summary: "Loaded saved skill '\(invokedSkill.name)'",
                detail: invokedSkill.descriptionText
            ))
            task.phase = .awaitingApproval
            currentTask = task
            isRunning = false
            return
        }

        // Phase 1: Gather context from MCP resources
        let contextBuilder = ContextBuilder(
            mcpHost: mcpHost,
            embeddingService: embeddingService,
            vectorStore: vectorStore
        )
        let contextMap = await contextBuilder.buildContextMap(
            for: prompt,
            embeddingModel: Defaults[.embeddingModel]
        )

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
            skillSummaries: skills.map(skillSummary(for:)),
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

    private func fetchSkills() -> [Skill] {
        let descriptor = FetchDescriptor<Skill>(sortBy: [
            SortDescriptor(\Skill.updatedAt, order: .reverse),
            SortDescriptor(\Skill.createdAt, order: .reverse)
        ])

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func resolveInvokedSkill(from prompt: String, skills: [Skill]) -> Skill? {
        guard prompt.lowercased().hasPrefix("/skill ") else { return nil }

        let requestedName = prompt.dropFirst("/skill ".count).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestedName.isEmpty else { return nil }

        return skills.first { $0.name.compare(requestedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    private func makePlan(for skill: Skill, prompt: String) -> ExecutionPlan {
        let steps = skill.toolSequence.enumerated().map { index, toolCall in
            AgentStep(
                index: index,
                description: "Run skill step \(index + 1): \(toolCall.toolName)",
                toolCall: toolCall,
                status: .pending
            )
        }

        let contextSummary = [
            "Invoked saved skill: \(skill.name)",
            skill.descriptionText.isEmpty ? nil : skill.descriptionText,
            "Invoke saved skills with `/skill <name>`."
        ]
            .compactMap { $0 }
            .joined(separator: "\n")

        return ExecutionPlan(
            intent: prompt,
            contextSummary: contextSummary,
            steps: steps,
            status: .awaitingApproval
        )
    }

    private func skillSummary(for skill: Skill) -> String {
        let firstTools = skill.toolSequence.prefix(3).map { "\($0.serverName)__\($0.toolName)" }
        let toolPreview = firstTools.isEmpty ? "no tools yet" : firstTools.joined(separator: ", ")
        let suffix = skill.toolSequence.count > 3 ? ", …" : ""
        let description = skill.descriptionText.isEmpty ? "No description." : skill.descriptionText
        return "- \(skill.name): \(description) Tools: \(toolPreview)\(suffix)"
    }
}
