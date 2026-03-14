//
//  AgentTask.swift
//  codellama
//
//  Created by Thiago Duarte on 3/14/26.
//

import Foundation

/// An ephemeral task managed by the agentic execution engine.
///
/// Tracks the full lifecycle from initial prompt through planning, approval,
/// execution, and completion. The `timeline` provides an ordered log of
/// every significant event during the task's lifetime.
struct AgentTask: Codable, Identifiable, Sendable {
    let id: UUID
    let prompt: String
    var phase: AgentPhase
    var plan: ExecutionPlan?
    var timeline: [TimelineEvent]
    var startedAt: Date = .now
    var completedAt: Date?

    /// The high-level phase of an agent task's lifecycle.
    enum AgentPhase: String, Codable, Sendable {
        case architecting
        case planning
        case awaitingApproval
        case executing
        case completed
        case failed
    }

    init(
        id: UUID = UUID(),
        prompt: String,
        phase: AgentPhase = .architecting,
        plan: ExecutionPlan? = nil,
        timeline: [TimelineEvent] = []
    ) {
        self.id = id
        self.prompt = prompt
        self.phase = phase
        self.plan = plan
        self.timeline = timeline
    }
}

// MARK: - TimelineEvent

/// A discrete event recorded during the execution of an `AgentTask`.
struct TimelineEvent: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let type: EventType
    let summary: String
    let detail: String?

    /// The category of a timeline event.
    enum EventType: String, Codable, Sendable {
        case contextGathered
        case planGenerated
        case toolCalled
        case toolResult
        case error
        case completed
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        type: EventType,
        summary: String,
        detail: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.summary = summary
        self.detail = detail
    }
}
